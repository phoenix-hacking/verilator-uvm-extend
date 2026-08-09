// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
// DESCRIPTION: Verilator: Replace return/continue with jumps
//
// Code available from: https://verilator.org
//
//*************************************************************************
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2003-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//*************************************************************************
// V3LinkJump's Transformations:
//
// Each module:
//   Look for BEGINs
//      BEGIN(VAR...) -> VAR ... {renamed}
//   FOR -> WHILEs
//
//   Add JumpLabel which branches to after statements within JumpLabel
//      RETURN -> JUMPBLOCK(statements with RETURN changed to JUMPGO, ..., JUMPLABEL)
//      WHILE(... BREAK) -> JUMPBLOCK(WHILE(... statements with BREAK changed to JUMPGO),
//                                    ... JUMPLABEL)
//      WHILE(... CONTINUE) -> WHILE(JUMPBLOCK(... statements with CONTINUE changed to JUMPGO,
//                                    ... JUMPPABEL))
//
//*************************************************************************

#include "V3PchAstNoMT.h"  // VL_MT_DISABLED_CODE_UNIT

#include "V3LinkJump.h"

#include "V3AstUserAllocator.h"
#include "V3Error.h"
#include "V3UniqueNames.h"

#include <unordered_map>
#include <vector>

VL_DEFINE_DEBUG_FUNCTIONS;

//######################################################################

using ActivationOwnerModuleMap = std::unordered_map<const AstNode*, AstNodeModule*>;
using ActivationOwnerFTaskMap = std::unordered_map<const AstNode*, AstNodeFTask*>;

// LinkJump can resolve a disable before visiting its target declaration.  Capture stable lexical
// ownership before this pass starts mutating the tree; AstNode::backp() is not suitable for this
// because it can point to a previous sibling rather than the parent.
class ActivationOwnerVisitor final : public VNVisitor {
    ActivationOwnerModuleMap& m_ownerModules;
    ActivationOwnerFTaskMap& m_ownerFTasks;
    AstNodeModule* m_modp = nullptr;
    AstNodeFTask* m_ftaskp = nullptr;

    void visit(AstNodeModule* nodep) override {
        VL_RESTORER(m_modp);
        VL_RESTORER(m_ftaskp);
        m_modp = nodep;
        m_ftaskp = nullptr;
        iterateChildren(nodep);
    }
    void visit(AstNodeFTask* nodep) override {
        UASSERT_OBJ(m_modp, nodep, "Task/function has no containing module/class/package");
        m_ownerModules.emplace(nodep, m_modp);
        m_ownerFTasks.emplace(nodep, nodep);
        VL_RESTORER(m_ftaskp);
        m_ftaskp = nodep;
        iterateChildren(nodep);
    }
    void visit(AstBegin* nodep) override {
        UASSERT_OBJ(m_modp, nodep, "Begin block has no containing module/class/package");
        m_ownerModules.emplace(nodep, m_modp);
        if (m_ftaskp) m_ownerFTasks.emplace(nodep, m_ftaskp);
        iterateChildren(nodep);
    }
    void visit(AstNode* nodep) override { iterateChildren(nodep); }

public:
    ActivationOwnerVisitor(AstNetlist* nodep, ActivationOwnerModuleMap& ownerModules,
                           ActivationOwnerFTaskMap& ownerFTasks)
        : m_ownerModules{ownerModules}
        , m_ownerFTasks{ownerFTasks} {
        iterate(nodep);
    }
    ~ActivationOwnerVisitor() override = default;
};

//######################################################################

class LinkJumpVisitor final : public VNVisitor {
    // NODE STATE
    //  AstBegin/etc::user1()  -> AstJumpBlock*, for body of this loop
    //  AstFinish::user1()     -> bool, processed
    //  AstNode::user2()       -> AstJumpBlock*, for this block
    //  AstNodeBegin::user3()  -> bool, true if contains a fork
    const VNUser1InUse m_user1InUse;
    const VNUser2InUse m_user2InUse;
    const VNUser3InUse m_user3InUse;

    // STATE
    AstNodeModule* m_modp = nullptr;  // Current module
    AstNodeFTask* m_ftaskp = nullptr;  // Current function/task
    AstNode* m_loopp = nullptr;  // Current loop
    AstRandSequence* m_randsequencep = nullptr;  // Current randsequence
    bool m_loopInc = false;  // In loop increment
    bool m_inFork = false;  // Under fork
    int m_modRepeatNum = 0;  // Repeat counter
    VOptionBool m_unrollFull;  // Pragma full, disable, or default unrolling
    std::vector<AstNodeBlock*> m_blockStack;  // All begin blocks above current node
    V3UniqueNames m_queueNames{
        "__VprocessQueue"};  // Names for queues needed for 'disable' handling
    V3UniqueNames m_activationNames{"__VnamedActivation"};
    std::unordered_map<const AstNode*, AstVar*> m_activationRegistries;
    ActivationOwnerModuleMap m_activationOwnerModules;
    ActivationOwnerFTaskMap m_activationOwnerFTasks;
    AstCDType* m_activationRegistryDTypep = nullptr;

    // METHODS
    // Get (and create if necessary) the JumpBlock for this statement
    AstJumpBlock* getJumpBlock(AstNode* nodep, bool endOfIter) {
        // Wrap 'nodep' in JumpBlock. If loop, wrap the body instead if endOfIter is true
        UINFO(4, "Create JumpBlock for " << nodep);

        // Made it previously?  We always jump to the end, so this works out
        if (endOfIter) {
            if (nodep->user1p()) return VN_AS(nodep->user1p(), JumpBlock);
        } else {
            if (nodep->user2p()) return VN_AS(nodep->user2p(), JumpBlock);
        }

        AstNode* underp = nullptr;
        bool under_and_next = true;
        if (AstBegin* const blockp = VN_CAST(nodep, Begin)) {
            UASSERT_OBJ(!endOfIter, nodep, "No endOfIter for Begin");
            underp = blockp->stmtsp();
        } else if (AstNodeFTask* const fTaskp = VN_CAST(nodep, NodeFTask)) {
            UASSERT_OBJ(!endOfIter, nodep, "No endOfIter for FTask");
            underp = fTaskp->stmtsp();
        } else if (AstForeach* const foreachp = VN_CAST(nodep, Foreach)) {
            if (endOfIter) {
                underp = foreachp->bodyp();
                // Keep a LoopTest **at the front** outside the jump block
                if (VN_IS(underp, LoopTest)) underp = underp->nextp();
            } else {
                underp = nodep;
                under_and_next = false;  // IE we skip the entire foreach
            }
        } else if (AstLoop* const loopp = VN_CAST(nodep, Loop)) {
            if (endOfIter) {
                underp = loopp->stmtsp();
            } else {
                underp = nodep;
                under_and_next = false;  // IE we skip the entire loop
            }
        } else {
            nodep->v3fatalSrc("Unknown jump point for break/disable/continue");
            return nullptr;
        }
        // Skip over variables as we'll just move them in a moment
        // Also this would otherwise prevent us from using a label twice
        // see t_func_return test.
        while (underp && VN_IS(underp, Var)) underp = underp->nextp();
        UASSERT_OBJ(underp, nodep, "Break/disable/continue not under expected statement");
        UINFO(5, "  Underpoint is " << underp);

        // If already wrapped, we are done ...
        if (!underp->nextp() || !under_and_next) {
            if (AstJumpBlock* const blockp = VN_CAST(underp, JumpBlock)) return blockp;
        }

        // Move underp stuff to be under a new AstJumpBlock
        VNRelinker repHandle;
        if (under_and_next) {
            underp->unlinkFrBackWithNext(&repHandle);
        } else {
            underp->unlinkFrBack(&repHandle);
        }
        AstJumpBlock* const blockp = new AstJumpBlock{nodep->fileline(), underp};
        if (endOfIter) {
            nodep->user1p(blockp);
        } else {
            nodep->user2p(blockp);
        }
        repHandle.relink(blockp);

        // Keep any AstVars under the function not under the new JumpLabel
        for (AstNode *nextp, *varp = underp; varp; varp = nextp) {
            nextp = varp->nextp();
            if (VN_IS(varp, Var)) blockp->addHereThisAsNext(varp->unlinkFrBack());
        }
        return blockp;
    }
    void addPrefixToBlocksRecurse(const std::string& prefix, AstNode* const nodep) {
        // Add a prefix to blocks
        // Used to not have blocks with duplicated names
        if (AstBegin* const beginp = VN_CAST(nodep, Begin)) {
            if (beginp->name() != "") beginp->name(prefix + beginp->name());
        }

        if (AstNode* const refp = nodep->op1p()) addPrefixToBlocksRecurse(prefix, refp);
        if (AstNode* const refp = nodep->op2p()) addPrefixToBlocksRecurse(prefix, refp);
        if (AstNode* const refp = nodep->op3p()) addPrefixToBlocksRecurse(prefix, refp);
        if (AstNode* const refp = nodep->op4p()) addPrefixToBlocksRecurse(prefix, refp);
        if (AstNode* const refp = nodep->nextp()) addPrefixToBlocksRecurse(prefix, refp);
    }
    bool existsBlockAbove(const std::string& name) const {
        for (const AstNodeBlock* const stackp : vlstd::reverse_view(m_blockStack)) {
            if (stackp->name() == name) return true;
        }
        return false;
    }
    AstNodeModule* ownerModulep(const AstNode* const nodep) const {
        const auto it = m_activationOwnerModules.find(nodep);
        UASSERT_OBJ(it != m_activationOwnerModules.end(), nodep,
                    "Named activation has no containing module/class/package");
        return it->second;
    }
    AstNodeFTask* ownerFTaskp(const AstNode* const nodep) const {
        const auto it = m_activationOwnerFTasks.find(nodep);
        return it == m_activationOwnerFTasks.end() ? nullptr : it->second;
    }
    static AstClass* baseClassp(const AstClass* const classp) {
        for (const AstClassExtends* extendsp = classp->extendsp(); extendsp;
             extendsp = VN_AS(extendsp->nextp(), ClassExtends)) {
            if (extendsp->isImplements()) continue;
            // LinkJump runs before V3Param.  A parameterized extends still has the declaration
            // class linked through its ClassRefDType, even though classOrNullp() deliberately
            // reports it as unresolved until specialization.
            const AstNodeDType* const dtypep
                = extendsp->dtypep() ? extendsp->dtypep() : extendsp->childDTypep();
            if (const AstClassRefDType* const refp = VN_CAST(dtypep, ClassRefDType)) {
                if (refp->classp()) return refp->classp();
            }
        }
        return nullptr;
    }
    static AstTask* directTaskp(AstClass* const classp, const string& name) {
        AstTask* fallbackp = nullptr;
        for (AstNode* memberp = classp->membersp(); memberp; memberp = memberp->nextp()) {
            AstTask* const taskp = VN_CAST(memberp, Task);
            if (!taskp || taskp->name() != name) continue;
            if (!fallbackp) fallbackp = taskp;
            if (!taskp->prototype() && !taskp->isExternProto()) return taskp;
        }
        return fallbackp;
    }
    // Virtual overrides form one dynamically dispatched method family.  Use the oldest virtual
    // declaration as the registry owner so both base-typed and derived-typed receivers address the
    // same inherited member.
    AstTask* activationFamilyRootp(AstTask* const taskp) const {
        AstClass* classp = VN_CAST(ownerModulep(taskp), Class);
        if (!classp) return taskp;
        AstTask* rootp = taskp;
        bool virtualFamily = taskp->isVirtual();
        while ((classp = baseClassp(classp))) {
            AstTask* const baseTaskp = directTaskp(classp, taskp->name());
            if (baseTaskp && baseTaskp->isVirtual()) {
                rootp = baseTaskp;
                virtualFamily = true;
            }
        }
        return virtualFamily ? rootp : taskp;
    }
    static void markNeedsProcess(AstNode* nodep) {
        for (AstNode* itemp = nodep; itemp; itemp = itemp->backp()) {
            if (AstNodeFTask* const ftaskp = VN_CAST(itemp, NodeFTask)) {
                ftaskp->setNeedProcess();
                return;
            }
            if (AstNodeProcedure* const procedurep = VN_CAST(itemp, NodeProcedure)) {
                procedurep->setNeedProcess();
                return;
            }
        }
    }
    AstVar* getOrCreateActivationRegistryp(AstNode* const targetp) {
        const auto it = m_activationRegistries.find(targetp);
        if (it != m_activationRegistries.end()) return it->second;

        FileLine* const flp = targetp->fileline();
        AstNodeModule* const ownerp = ownerModulep(targetp);
        if (!m_activationRegistryDTypep) {
            m_activationRegistryDTypep = new AstCDType{flp, "VlNamedActivationRegistry"};
            v3Global.rootp()->typeTablep()->addTypesp(m_activationRegistryDTypep);
        }
        const VVarType varType = VN_IS(ownerp, Class) ? VVarType::MEMBER : VVarType::MODULETEMP;
        AstVar* const registryp = new AstVar{flp, varType, m_activationNames.get(targetp->name()),
                                             m_activationRegistryDTypep};
        // This pass runs after LinkParse assigned source-variable lifetimes. Module, interface,
        // program, and package registries are persistent storage; ordinary class registries are
        // per-object members unless the owning task is static.
        registryp->lifetime(VN_IS(ownerp, Class) ? VLifetime::AUTOMATIC_IMPLICIT
                                                 : VLifetime::STATIC_IMPLICIT);
        registryp->isInternal(true);
        registryp->noCReset(true);
        registryp->noReset(true);
        registryp->noSubst(true);
        registryp->setIgnoreSchedWrite();
        if (AstNodeFTask* const ftaskp = ownerFTaskp(targetp)) {
            if (VN_IS(ownerp, Class) && ftaskp->isStatic()) {
                registryp->isStatic(true);
                registryp->lifetime(VLifetime::STATIC_EXPLICIT);
            }
        }
        ownerp->addStmtsp(registryp);
        m_activationOwnerModules.emplace(registryp, ownerp);
        m_activationRegistries.emplace(targetp, registryp);
        return registryp;
    }
    AstNodeExpr* activationRefp(FileLine* const flp, AstVar* const registryp,
                                const string& dotted = "") const {
        AstNodeModule* const ownerp = ownerModulep(registryp);
        if (!dotted.empty() && !VN_IS(ownerp, Class)) {
            return new AstVarXRef{flp, registryp, dotted, VAccess::READWRITE};
        }
        if (VN_IS(ownerp, Class) || VN_IS(ownerp, Package)) {
            return new AstVarRef{flp, ownerp, registryp, VAccess::READWRITE};
        }
        return new AstVarRef{flp, registryp, VAccess::READWRITE};
    }
    AstJumpBlock* markActivationBoundary(AstNode* const targetp, AstVar* const registryp) {
        AstJumpBlock* const blockp = getJumpBlock(targetp, false);
        if (!blockp->namedActivationRegistryp()) {
            blockp->namedActivationRegistryp(activationRefp(targetp->fileline(), registryp));
            // Named activation cancellation requires process/token propagation even in a design
            // with no source timing controls (including under explicit --no-timing).
            v3Global.setUsesTiming();
            // The activation guard is emitter-hidden state, so invalidate any purity result that
            // may have been cached while this was still an ordinary JumpBlock.
            VIsCached::clearCacheTree();
        }
        markNeedsProcess(targetp);
        return blockp;
    }
    AstJumpBlock* markActivationFamily(AstTask* const targetp, AstTask* const rootp,
                                       AstVar* const registryp) {
        if (!rootp->isVirtual()) return markActivationBoundary(targetp, registryp);

        AstJumpBlock* targetBoundaryp = nullptr;
        std::vector<AstTask*> candidates;
        v3Global.rootp()->foreach(
            [&candidates](AstTask* const candidatep) { candidates.push_back(candidatep); });
        for (AstTask* const candidatep : candidates) {
            if (ownerModulep(candidatep)->dead() || candidatep->name() != rootp->name()
                || activationFamilyRootp(candidatep) != rootp || candidatep->pureVirtual()
                || candidatep->prototype() || candidatep->isExternProto()) {
                continue;
            }
            AstJumpBlock* const boundaryp = markActivationBoundary(candidatep, registryp);
            if (candidatep == targetp) targetBoundaryp = boundaryp;
        }
        return targetBoundaryp;
    }
    AstCStmt* activationDisableStmtp(AstDisable* const nodep, AstVar* const registryp) const {
        AstCStmt* const stmtp = new AstCStmt{nodep->fileline(), "", VCStmtType::NAMED_DISABLE};
        AstNodeExpr* registryRefp = nullptr;
        if (nodep->receiverp()) {
            AstNodeExpr* const receiverp = nodep->receiverp()->unlinkFrBack();
            AstMemberSel* const memberp
                = new AstMemberSel{nodep->fileline(), receiverp, registryp};
            memberp->access(VAccess::READWRITE);
            registryRefp = memberp;
        } else {
            registryRefp = activationRefp(nodep->fileline(), registryp, nodep->dotted());
        }
        stmtp->add(registryRefp);
        stmtp->add(".disableAll();");
        return stmtp;
    }
    static AstStmtExpr* getQueuePushProcessSelfp(AstVarRef* const queueRefp) {
        // Constructs queue.push_back(std::process::self()) statement
        FileLine* const flp = queueRefp->fileline();
        return new AstStmtExpr{
            flp,
            new AstMethodCall{flp, queueRefp, "push_back",
                              new AstArg{flp, "", v3Global.rootp()->stdPackageProcessSelfp(flp)}}};
    }
    static AstStmtExpr* getQueuePushProcessSelfp(FileLine* const fl, AstVar* const processQueuep) {
        AstPackage* const topPkgp = v3Global.rootp()->dollarUnitPkgAddp();
        AstVarRef* const queueWriteRefp
            = new AstVarRef{fl, topPkgp, processQueuep, VAccess::WRITE};
        return getQueuePushProcessSelfp(queueWriteRefp);
    }
    static AstStmtExpr* getQueueKillStmtp(FileLine* const fl, AstVar* const processQueuep) {
        AstPackage* const topPkgp = v3Global.rootp()->dollarUnitPkgAddp();
        AstVarRef* const queueRefp = new AstVarRef{fl, topPkgp, processQueuep, VAccess::READWRITE};
        AstTaskRef* killQueueCall = nullptr;
        for (AstNode* itemp = v3Global.rootp()->stdPackageProcessp()->stmtsp(); itemp;
             itemp = itemp->nextp()) {
            if (itemp->name() == "killQueue") {
                killQueueCall
                    = new AstTaskRef{fl, VN_AS(itemp, Task), new AstArg{fl, "", queueRefp}};
                break;
            }
        }
        UASSERT(killQueueCall, "Should be found");
        killQueueCall->classOrPackagep(v3Global.rootp()->stdPackageProcessp());
        return new AstStmtExpr{fl, killQueueCall};
    }
    static void prependStmtsp(AstNodeFTask* const nodep, AstNode* const stmtp) {
        if (AstNode* const origStmtsp = nodep->stmtsp()) {
            origStmtsp->unlinkFrBackWithNext();
            stmtp->addNext(origStmtsp);
        }
        nodep->addStmtsp(stmtp);
    }
    static void prependStmtsp(AstNodeBlock* const nodep, AstNode* const stmtp) {
        if (AstNode* const origStmtsp = nodep->stmtsp()) {
            origStmtsp->unlinkFrBackWithNext();
            stmtp->addNext(origStmtsp);
        }
        nodep->addStmtsp(stmtp);
    }
    static bool directlyUnderFork(const AstNode* const nodep) {
        if (nodep->backp()->nextp() == nodep) return directlyUnderFork(nodep->backp());
        return VN_IS(nodep->backp(), Fork);
    }
    AstVar* getProcessQueuep(AstNode* const nodep, FileLine* const fl) {
        AstPackage* const topPkgp = v3Global.rootp()->dollarUnitPkgAddp();
        AstVar* const processQueuep = new AstVar{
            fl, VVarType::VAR, m_queueNames.get(nodep->name()), VFlagChildDType{},
            new AstQueueDType{
                fl, VFlagChildDType{},
                new AstClassRefDType{fl, v3Global.rootp()->stdPackageProcessp(), nullptr},
                nullptr}};
        processQueuep->lifetime(VLifetime::STATIC_EXPLICIT);
        processQueuep->processQueue(true);
        processQueuep->setIgnoreSchedWrite();
        topPkgp->addStmtsp(processQueuep);
        return processQueuep;
    }
    void handleDisableOnFork(AstDisable* const nodep, const std::vector<AstBegin*>& forks) {
        // The support utilizes the process::kill()` method. For each `disable` a queue of
        // processes is declared. At the beginning of each fork that can be disabled, its process
        // handle is pushed to the queue. `disable` statement is replaced with calling `kill()`
        // method on each element of the queue.
        FileLine* const fl = nodep->fileline();
        AstNode* const targetp = nodep->targetp();
        if (m_ftaskp) {
            if (!m_ftaskp->exists(
                    [targetp](const AstNodeBlock* blockp) -> bool { return blockp == targetp; })) {
                // Disabling a fork, which is within the same task, is not a problem
                nodep->v3warn(E_UNSUPPORTED, "Unsupported: disabling fork from task / function");
            }
        }

        AstPackage* const topPkgp = v3Global.rootp()->dollarUnitPkgAddp();
        AstVar* const processQueuep = getProcessQueuep(targetp, fl);
        AstVarRef* const queueWriteRefp
            = new AstVarRef{fl, topPkgp, processQueuep, VAccess::WRITE};
        AstStmtExpr* pushCurrentProcessp = getQueuePushProcessSelfp(queueWriteRefp);

        for (AstBegin* const beginp : forks) {
            if (pushCurrentProcessp->backp()) {
                pushCurrentProcessp = pushCurrentProcessp->cloneTree(false);
            }
            prependStmtsp(beginp, pushCurrentProcessp);
        }
        AstStmtExpr* const killStmtp = getQueueKillStmtp(fl, processQueuep);
        nodep->addNextHere(killStmtp);

        // Killing the current process unwinds cooperatively after killQueue drains.  If the
        // disable statement executes under the target AstFork, also jump to the end of that fork
        // branch so no statements after the disable can run on paths without process unwinding.
        if (VN_IS(targetp, Fork)) {
            AstNodeBlock* forkBranchp = nullptr;
            for (AstNodeBlock* const blockp : vlstd::reverse_view(m_blockStack)) {
                if (blockp == targetp) {
                    AstJumpBlock* const jmpBlockp = getJumpBlock(VN_AS(forkBranchp, Begin), false);
                    killStmtp->addNextHere(new AstJumpGo{fl, jmpBlockp});
                    break;
                }
                forkBranchp = blockp;
            }
        }
    }
    // VISITORS
    void visit(AstNodeModule* nodep) override {
        if (nodep->dead()) return;
        VL_RESTORER(m_modp);
        VL_RESTORER(m_modRepeatNum);
        m_modp = nodep;
        m_modRepeatNum = 0;
        iterateChildren(nodep);
    }
    void visit(AstNodeFTask* nodep) override {
        VL_RESTORER(m_ftaskp);
        m_ftaskp = nodep;
        iterateChildren(nodep);
    }
    void visit(AstBegin* nodep) override {
        UINFO(8, "  " << nodep);
        VL_RESTORER(m_unrollFull);
        m_blockStack.push_back(nodep);
        iterateChildren(nodep);
        m_blockStack.pop_back();
    }
    void visit(AstFork* nodep) override {
        UINFO(8, "  " << nodep);
        VL_RESTORER(m_unrollFull);
        VL_RESTORER(m_inFork);
        m_inFork = true;
        // Mark all upper blocks, can stop once see one set to avoid O(n^2)
        for (AstNodeBlock* const blockp : vlstd::reverse_view(m_blockStack)) {
            if (blockp->user3SetOnce()) break;
        }
        m_blockStack.push_back(nodep);
        iterateChildren(nodep);
        m_blockStack.pop_back();
    }
    void visit(AstStmtPragma* nodep) override {
        if (nodep->pragp()->pragType() == VPragmaType::UNROLL_DISABLE) {
            m_unrollFull = VOptionBool::OPT_FALSE;
            VL_DO_DANGLING(pushDeletep(nodep->unlinkFrBack()), nodep);
        } else if (nodep->pragp()->pragType() == VPragmaType::UNROLL_FULL) {
            m_unrollFull = VOptionBool::OPT_TRUE;
            VL_DO_DANGLING(pushDeletep(nodep->unlinkFrBack()), nodep);
        } else {
            iterateChildren(nodep);
        }
    }
    void visit(AstRandSequence* nodep) override {
        VL_RESTORER(m_randsequencep);
        m_randsequencep = nodep;
        iterateChildren(nodep);
    }
    void visit(AstRepeat* nodep) override {
        // So later optimizations don't need to deal with them,
        //    REPEAT(count,body) -> loop=count,WHILE(loop>0) { body, loop-- }
        // Note var can be signed or unsigned based on original number.
        AstNodeExpr* const countp = nodep->countp()->unlinkFrBackWithNext();
        const string name = "__Vrepeat"s + cvtToStr(m_modRepeatNum++);
        AstBegin* const beginp = new AstBegin{nodep->fileline(), "", nullptr, true};
        // Spec says value is integral, if negative is ignored
        AstVar* const varp
            = new AstVar{nodep->fileline(), VVarType::BLOCKTEMP, name, nodep->findIntDType()};
        varp->lifetime(VLifetime::AUTOMATIC_EXPLICIT);
        varp->usedLoopIdx(true);
        beginp->addStmtsp(varp);
        AstNode* initsp = new AstAssign{
            nodep->fileline(), new AstVarRef{nodep->fileline(), varp, VAccess::WRITE}, countp};
        AstNode* const decp = new AstAssign{
            nodep->fileline(), new AstVarRef{nodep->fileline(), varp, VAccess::WRITE},
            new AstSub{nodep->fileline(), new AstVarRef{nodep->fileline(), varp, VAccess::READ},
                       new AstConst{nodep->fileline(), 1}}};
        AstNodeExpr* const zerosp = new AstConst{nodep->fileline(), AstConst::Signed32{}, 0};
        AstNodeExpr* const condp = new AstGtS{
            nodep->fileline(), new AstVarRef{nodep->fileline(), varp, VAccess::READ}, zerosp};
        AstNode* const bodysp = nodep->stmtsp();
        if (bodysp) bodysp->unlinkFrBackWithNext();
        FileLine* const flp = nodep->fileline();
        AstLoop* const loopp = new AstLoop{flp};
        loopp->addStmtsp(new AstLoopTest{flp, loopp, condp});
        loopp->addStmtsp(bodysp);
        loopp->addContsp(decp);
        if (!m_unrollFull.isDefault()) loopp->unroll(m_unrollFull);
        m_unrollFull = VOptionBool::OPT_DEFAULT_FALSE;
        beginp->addStmtsp(initsp);
        beginp->addStmtsp(loopp);
        // Replacement AstBegin will be iterated next
        nodep->replaceWith(beginp);
        VL_DO_DANGLING(nodep->deleteTree(), nodep);
    }
    void visit(AstLoop* nodep) override {
        if (!m_unrollFull.isDefault()) nodep->unroll(m_unrollFull);
        if (m_modp->hasParameterList() || m_modp->hasGParam()) {
            nodep->fileline()->modifyWarnOff(V3ErrorCode::UNUSEDLOOP, true);
        }
        m_unrollFull = VOptionBool::OPT_DEFAULT_FALSE;
        VL_RESTORER(m_loopp);
        VL_RESTORER(m_loopInc);
        m_loopp = nodep;
        m_loopInc = false;
        iterateAndNextNull(nodep->stmtsp());
        m_loopInc = true;
        iterateAndNextNull(nodep->contsp());
        // Move contsp into stmtsp, no longer needed to keep separately
        if (nodep->contsp()) nodep->addStmtsp(nodep->contsp()->unlinkFrBackWithNext());
    }
    void visit(AstNodeForeach* nodep) override {
        VL_RESTORER(m_loopp);
        m_loopp = nodep;
        iterateAndNextNull(nodep->bodyp());
    }
    void visit(AstReturn* nodep) override {
        iterateChildren(nodep);
        const AstFunc* const funcp = VN_CAST(m_ftaskp, Func);
        if (m_randsequencep) {
            nodep->replaceWith(new AstRSReturn{nodep->fileline()});
            VL_DO_DANGLING(pushDeletep(nodep), nodep);
            return;
        } else if (m_inFork) {
            nodep->v3error("Return isn't legal under fork (IEEE 1800-2023 9.2.3)");
            VL_DO_DANGLING(pushDeletep(nodep->unlinkFrBack()), nodep);
            return;
        } else if (!m_ftaskp) {
            nodep->v3error("Return isn't underneath a task or function");
        } else if (funcp && !nodep->lhsp() && !funcp->isConstructor()) {
            nodep->v3error("Return underneath a function should have return value");
        } else if (!funcp && nodep->lhsp()) {
            nodep->v3error("Return underneath a task shouldn't have return value");
        } else {
            if (funcp && nodep->lhsp()) {
                // Set output variable to return value
                nodep->addHereThisAsNext(new AstAssign{
                    nodep->fileline(),
                    new AstVarRef{nodep->fileline(), VN_AS(funcp->fvarp(), Var), VAccess::WRITE},
                    nodep->lhsp()->unlinkFrBackWithNext()});
            }
            // Jump to the end of the function call
            AstJumpBlock* const blockp = getJumpBlock(m_ftaskp, false);
            nodep->addHereThisAsNext(new AstJumpGo{nodep->fileline(), blockp});
        }
        nodep->unlinkFrBack();
        VL_DO_DANGLING(pushDeletep(nodep), nodep);
    }
    void visit(AstBreak* nodep) override {
        iterateChildren(nodep);
        if (!m_loopp && m_randsequencep) {
            nodep->replaceWith(new AstRSBreak{nodep->fileline()});
            VL_DO_DANGLING(pushDeletep(nodep), nodep);
            return;
        } else if (!m_loopp) {
            nodep->v3error("break isn't underneath a loop");
        } else {
            // Jump to the end of the loop
            AstJumpBlock* const blockp = getJumpBlock(m_loopp, false);
            nodep->addNextHere(new AstJumpGo{nodep->fileline(), blockp});
        }
        nodep->unlinkFrBack();
        VL_DO_DANGLING(pushDeletep(nodep), nodep);
    }
    void visit(AstContinue* nodep) override {
        iterateChildren(nodep);
        if (!m_loopp) {
            nodep->v3error("continue isn't underneath a loop");
        } else {
            // Jump to the end of this iteration
            // If a "for" loop then need to still do the post-loop increment
            AstJumpBlock* const blockp = getJumpBlock(m_loopp, true);
            nodep->addNextHere(new AstJumpGo{nodep->fileline(), blockp});
        }
        nodep->unlinkFrBack();
        VL_DO_DANGLING(pushDeletep(nodep), nodep);
    }
    void visit(AstDisable* nodep) override {
        UINFO(8, "   DISABLE " << nodep);
        AstNode* const targetp = nodep->targetp();
        if (!targetp) {
            // Linking errors on the disable target are already reported upstream.
            // Drop this node to avoid cascading into an internal assertion.
            VL_DO_DANGLING(pushDeletep(nodep->unlinkFrBack()), nodep);
            return;
        }
        if (AstTask* const taskp = VN_CAST(targetp, Task)) {
            AstTask* const rootp = activationFamilyRootp(taskp);
            AstClass* const rootClassp = VN_CAST(ownerModulep(rootp), Class);
            if (rootClassp && rootClassp->isInterfaceClass()) {
                nodep->v3warn(E_UNSUPPORTED,
                              "Unsupported: disabling an interface class task through an interface"
                              " class receiver");
            } else {
                AstVar* const registryp = getOrCreateActivationRegistryp(rootp);
                AstJumpBlock* const boundaryp = markActivationFamily(taskp, rootp, registryp);
                AstCStmt* const disablep = activationDisableStmtp(nodep, registryp);
                nodep->addNextHere(disablep);
                if (m_ftaskp == taskp && !m_inFork && boundaryp) {
                    disablep->addNextHere(new AstJumpGo{nodep->fileline(), boundaryp});
                }
            }
        } else if (AstFork* const forkp = VN_CAST(targetp, Fork)) {
            std::vector<AstBegin*> forks;
            for (AstBegin* itemp = forkp->forksp(); itemp; itemp = VN_AS(itemp->nextp(), Begin)) {
                forks.push_back(itemp);
            }
            handleDisableOnFork(nodep, forks);
        } else if (AstBegin* const beginp = VN_CAST(targetp, Begin)) {
            AstVar* const registryp = getOrCreateActivationRegistryp(beginp);
            AstJumpBlock* const boundaryp = markActivationBoundary(beginp, registryp);
            AstCStmt* const disablep = activationDisableStmtp(nodep, registryp);
            nodep->addNextHere(disablep);
            if (existsBlockAbove(beginp->name()) && !m_inFork) {
                disablep->addNextHere(new AstJumpGo{nodep->fileline(), boundaryp});
            }
        } else {
            nodep->v3fatalSrc("Disable linked with node of unhandled type "
                              << targetp->prettyTypeName());
        }
        nodep->unlinkFrBack();
        VL_DO_DANGLING(pushDeletep(nodep), nodep);
    }
    void visit(AstFinish* nodep) override {
        if (nodep->user1SetOnce()) return;  // Process once
        iterateChildren(nodep);
        if (m_inFork) {
            nodep->replaceWith(new AstFinishFork{nodep->fileline()});
            VL_DO_DANGLING(nodep->deleteTree(), nodep);
        } else if (m_loopp) {
            // Jump to the end of the loop (post-finish)
            AstJumpBlock* const blockp = getJumpBlock(m_loopp, false);
            nodep->addNextHere(new AstJumpGo{nodep->fileline(), blockp});
        }
    }
    void visit(AstVarRef* nodep) override {
        if (m_loopInc && nodep->varp()) nodep->varp()->usedLoopIdx(true);
    }
    void visit(AstConst*) override {}
    void visit(AstNode* nodep) override { iterateChildren(nodep); }

public:
    // CONSTRUCTORS
    explicit LinkJumpVisitor(AstNetlist* nodep) {
        { ActivationOwnerVisitor{nodep, m_activationOwnerModules, m_activationOwnerFTasks}; }
        iterate(nodep);
    }
    ~LinkJumpVisitor() override = default;
};

//######################################################################
// Task class functions

void V3LinkJump::linkJump(AstNetlist* nodep) {
    UINFO(2, __FUNCTION__ << ":");
    { LinkJumpVisitor{nodep}; }  // Destruct before checking
    V3Global::dumpCheckGlobalTree("linkjump", 0, dumpTreeEitherLevel() >= 3);
}
