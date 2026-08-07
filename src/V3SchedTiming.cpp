// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
// DESCRIPTION: Verilator: Code scheduling
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
//
// Functions defined in this file are used by V3Sched.cpp to properly integrate
// static scheduling with timing features. They create external domains for
// variables, remap them to trigger vectors, and create timing resume/ready
// calls for the global eval loop. There is also a function that transforms
// forks into emittable constructs.
//
// See the internals documentation docs/internals.rst for more details.
//
//*************************************************************************

#include "V3PchAstNoMT.h"  // VL_MT_DISABLED_CODE_UNIT

#include "V3EmitCBase.h"
#include "V3Sched.h"
#include "V3UniqueNames.h"

#include <unordered_map>

VL_DEFINE_DEBUG_FUNCTIONS;

namespace V3Sched {

//============================================================================
// Remaps external domains using the specified trigger map

std::map<const AstVarScope*, std::vector<AstSenTree*>>
TimingKit::remapDomains(const std::unordered_map<const AstSenTree*, AstSenTree*>& trigMap) const {
    std::map<const AstVarScope*, std::vector<AstSenTree*>> remappedDomainMap;
    for (const auto& vscpDomains : m_externalDomains) {
        const AstVarScope* const vscp = vscpDomains.first;
        const auto& domains = vscpDomains.second;
        auto& remappedDomains = remappedDomainMap[vscp];
        remappedDomains.reserve(domains.size());
        for (AstSenTree* const domainp : domains) {
            remappedDomains.push_back(trigMap.at(domainp));
        }
    }
    return remappedDomainMap;
}

//============================================================================
// Creates a timing resume call (if needed, else returns null)

AstCCall* TimingKit::createResume(AstNetlist* const netlistp) {
    if (!m_resumeFuncp) {
        if (m_lbs.empty()) return nullptr;
        // Create global resume function
        AstScope* const scopeTopp = netlistp->topScopep()->scopep();
        m_resumeFuncp = new AstCFunc{netlistp->fileline(), "_timing_resume", scopeTopp, ""};
        m_resumeFuncp->dontCombine(true);
        m_resumeFuncp->isLoose(true);
        m_resumeFuncp->isConst(false);
        m_resumeFuncp->declPrivate(true);
        scopeTopp->addBlocksp(m_resumeFuncp);

        for (const auto& p : m_lbs) {
            AstActive* const activep = p.second;
            activep->foreach([this](AstCMethodHard* const exprp) {
                if (exprp->method() != VCMethod::SCHED_RESUME) return;
                AstNodeExpr* const fromp = exprp->fromp();
                if (VN_AS(fromp->dtypep(), BasicDType)->keyword()
                    != VBasicDTypeKwd::TRIGGER_SCHEDULER) {
                    return;
                }
                AstCMethodHard* const moveToResumep = new AstCMethodHard{
                    fromp->fileline(), fromp->cloneTree(false),
                    VCMethod::SCHED_MOVE_TO_RESUME_QUEUE,
                    exprp->pinsp() ? exprp->pinsp()->cloneTree(true) : nullptr};
                moveToResumep->dtypeSetVoid();
                m_resumeFuncp->addStmtsp(moveToResumep->makeStmt());
            });
        }

        // Put all the timing actives in the resume function
        AstIf* dlyShedIfp = nullptr;
        for (auto& p : m_lbs) {
            AstActive* const activep = p.second;
            // Resume time delays last. For no particular reason other than
            // that's what we used to do prior to proper #0 support.
            AstVarRef* const schedrefp = VN_AS(
                VN_AS(VN_AS(activep->stmtsp(), StmtExpr)->exprp(), CMethodHard)->fromp(), VarRef);

            AstNode* const actionp = activep->stmtsp()->unlinkFrBackWithNext();
            if (schedrefp->varScopep()->dtypep()->basicp()->isDelayScheduler()) {
                dlyShedIfp = V3Sched::util::createIfFromSenTree(activep->sentreep());
                dlyShedIfp->addThensp(actionp);
            } else {
                m_resumeFuncp->addStmtsp(actionp);
            }
        }
        if (dlyShedIfp) m_resumeFuncp->addStmtsp(dlyShedIfp);

        // These are now spent, oispose of now empty AstActive instances
        m_lbs.deleteActives();
    }
    AstCCall* const callp = new AstCCall{m_resumeFuncp->fileline(), m_resumeFuncp};
    callp->dtypeSetVoid();
    return callp;
}

AstVarScope* TimingKit::getDelayScheduler(AstNetlist* const /*netlistp*/) {
    for (auto& p : m_lbs) {
        AstActive* const ap = p.second;
        // TODO: this triple VN_AS expression is ridiculous
        AstVarRef* const schedrefp
            = VN_AS(VN_AS(VN_AS(ap->stmtsp(), StmtExpr)->exprp(), CMethodHard)->fromp(), VarRef);
        AstVarScope* const vscp = schedrefp->varScopep();
        if (vscp->dtypep()->basicp()->isDelayScheduler()) return vscp;
    }
    // None found. Design doesn't use any time delays
    return nullptr;
}

//============================================================================
// Creates a timing ready call (if needed, else returns null)

AstCCall* TimingKit::createReady(AstNetlist* const netlistp) {
    if (!m_readyFuncp) {
        for (auto& p : m_lbs) {
            AstActive* const activep = p.second;
            auto* const resumep = VN_AS(VN_AS(activep->stmtsp(), StmtExpr)->exprp(), CMethodHard);
            UASSERT_OBJ(!resumep->nextp(), resumep, "Should be the only statement here");
            AstVarScope* const schedulerp = VN_AS(resumep->fromp(), VarRef)->varScopep();
            UASSERT_OBJ(schedulerp->dtypep()->basicp()->isDelayScheduler()
                            || schedulerp->dtypep()->basicp()->isTriggerScheduler()
                            || schedulerp->dtypep()->basicp()->isDynamicTriggerScheduler(),
                        schedulerp, "Unexpected type");
            if (!schedulerp->dtypep()->basicp()->isTriggerScheduler()) continue;
            // Create the global ready function only if we have trigger schedulers
            if (!m_readyFuncp) {
                AstScope* const scopeTopp = netlistp->topScopep()->scopep();
                m_readyFuncp = new AstCFunc{netlistp->fileline(), "_timing_ready", scopeTopp, ""};
                m_readyFuncp->dontCombine(true);
                m_readyFuncp->isLoose(true);
                m_readyFuncp->isConst(false);
                m_readyFuncp->declPrivate(true);
                scopeTopp->addBlocksp(m_readyFuncp);
            }

            AstSenTree* const senTreep = activep->sentreep();
            FileLine* const flp = senTreep->fileline();

            // Create an 'AstIf' sensitive to the suspending triggers
            AstIf* const ifp = V3Sched::util::createIfFromSenTree(senTreep);
            m_readyFuncp->addStmtsp(ifp);

            // Mark as ready the processes resumed on this sensitivity expression
            AstVarRef* const refp = new AstVarRef{flp, schedulerp, VAccess::READWRITE};
            AstCMethodHard* const callp = new AstCMethodHard{flp, refp, VCMethod::SCHED_READY};
            callp->dtypeSetVoid();
            if (resumep->pinsp()) callp->addPinsp(resumep->pinsp()->cloneTree(false));
            ifp->addThensp(callp->makeStmt());
        }
        // We still haven't created a ready function (no trigger schedulers), return null
        if (!m_readyFuncp) return nullptr;
    }
    AstCCall* const callp = new AstCCall{m_readyFuncp->fileline(), m_readyFuncp};
    callp->dtypeSetVoid();
    return callp;
}

//============================================================================
// Creates the timing kit and marks variables written by suspendables

class AwaitVisitor final : public VNVisitor {
    // NODE STATE
    //  AstSenTree::user1()  -> bool.  Set true if the sentree has been visited.
    const VNUser1InUse m_inuser1;

    // STATE
    bool m_inProcess = false;  // Are we in a process?
    bool m_gatherVars = false;  // Should we gather vars in m_writtenBySuspendable?
    AstScope* const m_scopeTopp;  // Scope at the top
    LogicByScope& m_lbs;  // Timing resume actives
    AstNodeStmt*& m_postUpdatesr;  // Post updates for the trigger eval function
    // Additional var sensitivities
    std::map<const AstVarScope*, std::set<AstSenTree*>>& m_externalDomains;
    std::set<AstSenTree*> m_processDomains;  // Sentrees from the current process
    // Variables written by suspendable processes
    std::vector<AstVarScope*> m_writtenBySuspendable;

    // METHODS
    // Add arguments to a resume() call based on arguments in the suspending call
    void addResumePins(AstCMethodHard* const resumep, AstNodeExpr* pinsp) {
        AstCExpr* const exprp = VN_CAST(pinsp, CExpr);
        AstText* const textp = VN_CAST(exprp->nodesp(), Text);
        if (textp) {
            // The first argument, vlProcess, isn't used by any of resume() methods, skip it
            if ((pinsp = VN_CAST(pinsp->nextp(), NodeExpr))) {
                resumep->addPinsp(pinsp->cloneTree(false));
            }
        } else {
            resumep->addPinsp(pinsp->cloneTree(false));
        }
    }
    // Create an active with a timing scheduler resume() call
    void createResumeActive(AstCAwait* const awaitp) {
        auto* const methodp = VN_AS(awaitp->exprp(), CMethodHard);
        AstVarScope* const schedulerp = VN_AS(methodp->fromp(), VarRef)->varScopep();
        AstSenTree* const sentreep = awaitp->sentreep();
        FileLine* const flp = sentreep->fileline();
        // Create a resume() call on the timing scheduler
        auto* const resumep = new AstCMethodHard{
            flp, new AstVarRef{flp, schedulerp, VAccess::READWRITE}, VCMethod::SCHED_RESUME};
        resumep->dtypeSetVoid();
        if (schedulerp->dtypep()->basicp()->isTriggerScheduler()) {
            UASSERT_OBJ(methodp->pinsp(), methodp,
                        "Trigger method should have pins from V3Timing");
            // The first pin is the ready boolean, the rest (if any) should be debug info
            // See V3Timing for details
            if (AstNode* const dbginfop = methodp->pinsp()->nextp()) {
                if (methodp->pinsp()) addResumePins(resumep, static_cast<AstNodeExpr*>(dbginfop));
            }
        } else if (schedulerp->dtypep()->basicp()->isDynamicTriggerScheduler()) {
            auto* const postp = resumep->cloneTree(false);
            postp->method(VCMethod::SCHED_DO_POST_UPDATES);
            m_postUpdatesr = AstNode::addNext(m_postUpdatesr, postp->makeStmt());
        }
        // Put it in an active
        AstActive* const activep = new AstActive{flp, "_timing", sentreep};
        activep->addStmtsp(resumep->makeStmt());
        m_lbs.emplace_back(m_scopeTopp, activep);
    }

    // VISITORS
    void visit(AstNodeProcedure* const nodep) override {
        UASSERT_OBJ(!m_inProcess && !m_gatherVars && m_processDomains.empty()
                        && m_writtenBySuspendable.empty(),
                    nodep, "Process in process?");
        m_inProcess = true;
        m_gatherVars = nodep->isSuspendable();  // Only gather vars in a suspendable
        const VNUser2InUse user2InUse;  // AstVarScope -> bool: Set true if var has been added
                                        // to m_writtenBySuspendable
        iterateChildren(nodep);
        for (AstVarScope* const vscp : m_writtenBySuspendable) {
            m_externalDomains[vscp].insert(m_processDomains.begin(), m_processDomains.end());
            vscp->varp()->setWrittenBySuspendable();
        }
        m_processDomains.clear();
        m_writtenBySuspendable.clear();
        m_inProcess = false;
        m_gatherVars = false;
    }
    void visit(AstFork* nodep) override {
        VL_RESTORER(m_gatherVars);
        if (m_inProcess) m_gatherVars = true;
        // If not in a process, we don't need to gather variables or domains
        iterateChildren(nodep);
    }
    void visit(AstCAwait* nodep) override {
        if (AstSenTree* const sentreep = nodep->sentreep()) {
            if (!sentreep->user1SetOnce()) createResumeActive(nodep);
            if (m_inProcess) m_processDomains.insert(sentreep);
        }
    }
    void visit(AstNodeVarRef* nodep) override {
        if (m_gatherVars && nodep->access().isWriteOrRW() && !nodep->varp()->ignoreSchedWrite()
            && !nodep->varScopep()->user2SetOnce()) {
            m_writtenBySuspendable.push_back(nodep->varScopep());
        }
    }
    void visit(AstExprStmt* nodep) override { iterateChildren(nodep); }

    //--------------------
    void visit(AstNode* nodep) override { iterateChildren(nodep); }

public:
    // CONSTRUCTORS
    explicit AwaitVisitor(AstNetlist* nodep, LogicByScope& lbs, AstNodeStmt*& postUpdatesr,
                          std::map<const AstVarScope*, std::set<AstSenTree*>>& externalDomains)
        : m_scopeTopp{nodep->topScopep()->scopep()}
        , m_lbs{lbs}
        , m_postUpdatesr{postUpdatesr}
        , m_externalDomains{externalDomains} {
        iterate(nodep);
    }
    ~AwaitVisitor() override = default;
};

TimingKit prepareTiming(AstNetlist* const netlistp) {
    if (!v3Global.usesTiming()) return {};
    LogicByScope lbs;
    AstNodeStmt* postUpdates = nullptr;
    std::map<const AstVarScope*, std::set<AstSenTree*>> externalDomains;
    { AwaitVisitor{netlistp, lbs, postUpdates, externalDomains}; }
    return {std::move(lbs), postUpdates, std::move(externalDomains)};
}

//============================================================================
// Visits all forks and transforms their sub-statements into separate functions.

// Transform all forked processes into functions
class TransformForksVisitor final : public VNVisitor {
    // NODE STATE
    //  AstVar::user1()  -> bool.  Set true if the variable was declared before the current fork.
    const VNUser1InUse m_inuser1;

    // STATE
    bool m_inClass = false;  // Are we in a class?
    bool m_beginHasAwaits = false;  // Does the current begin have awaits?
    AstFork* m_forkp = nullptr;  // Current fork
    AstCFunc* m_funcp = nullptr;  // Current function
    AstBasicDType* m_processDtp = nullptr;  // Process-reference type
    V3UniqueNames m_processNames{"__VforkProcess"};  // Branch-process temporary names
    std::vector<AstNode*> m_processSetups;  // Process creation before any branch starts
    std::vector<AstNode*> m_registrationSetups;  // Named-disable registration before branch starts
    std::vector<AstNode*> m_onKillSetups;  // Fork join kill hooks before branch starts

    // METHODS
    // Timing coroutines start eagerly.  Collect every branch process, named-disable registration,
    // and kill hook so the parent installs the complete fork topology before invoking any branch.
    // Remap local vars referenced by the given fork function
    // TODO: We should only pass variables to the fork that are
    // live in the fork body, but for that we need a proper data
    // flow analysis framework which we don't have at the moment
    void remapLocals(AstCFunc* const funcp, AstCCall* const callp) {
        const VNUser2InUse user2InUse;  // AstVarScope -> AstVarScope: var to remap to
        funcp->foreach([&](AstNodeVarRef* refp) {
            AstVar* const varp = refp->varp();
            AstBasicDType* const dtypep = varp->dtypep()->basicp();
            // If not a fork..join, copy. All write refs should've been handled by V3Fork
            bool passByValue = !m_forkp->joinType().join();
            if (!varp->isFuncLocal()) {
                // Not func local. Its lifetime is longer than the forked process. Skip
                return;
            } else if (!varp->user1()) {
                // Not declared before the fork. It cannot outlive the forked process
                return;
            } else if (dtypep && dtypep->isForkSync()) {
                // We can just pass it by value to the new function
                passByValue = true;
            }
            // Remap the reference
            AstVarScope* const vscp = refp->varScopep();
            if (!vscp->user2p()) {
                // Clone the var to the new function
                AstVar* const newvarp
                    = new AstVar{varp->fileline(), VVarType::BLOCKTEMP, varp->name(), varp};
                newvarp->funcLocal(true);
                newvarp->direction(passByValue ? VDirection::INPUT : VDirection::REF);
                funcp->addArgsp(newvarp);
                AstVarScope* const newvscp
                    = new AstVarScope{newvarp->fileline(), funcp->scopep(), newvarp};
                funcp->scopep()->addVarsp(newvscp);
                vscp->user2p(newvscp);
                callp->addArgsp(new AstVarRef{refp->fileline(), vscp,
                                              passByValue ? VAccess::READ : VAccess::READWRITE});
            }
            AstVarScope* const newvscp = VN_AS(vscp->user2p(), VarScope);
            refp->varScopep(newvscp);
            refp->varp(newvscp->varp());
        });
    }

    AstBasicDType* getCreateProcessDTypep(FileLine* const flp) {
        if (m_processDtp) return m_processDtp;
        m_processDtp
            = new AstBasicDType{flp, VBasicDTypeKwd::PROCESS_REFERENCE, VSigning::UNSIGNED};
        v3Global.rootp()->typeTablep()->addTypesp(m_processDtp);
        return m_processDtp;
    }

    AstVarScope* createBranchProcess(AstBegin* const beginp) {
        FileLine* const flp = beginp->fileline();
        AstBasicDType* const processDtp = getCreateProcessDTypep(flp);
        AstVar* const processVarp
            = new AstVar{flp, VVarType::BLOCKTEMP, m_processNames.get("branch"), processDtp};
        processVarp->funcLocal(true);
        processVarp->noReset(true);
        m_funcp->addVarsp(processVarp);
        AstVarScope* const processVscp = new AstVarScope{flp, m_funcp->scopep(), processVarp};
        m_funcp->scopep()->addVarsp(processVscp);

        const std::string createProcess = m_funcp->needProcess()
                                              ? "VlProcess::createChild(vlProcess)"
                                              : "std::make_shared<VlProcess>()";
        AstCExpr* const createProcessp = new AstCExpr{flp, createProcess};
        createProcessp->dtypep(processDtp);
        AstAssign* const assignp
            = new AstAssign{flp, new AstVarRef{flp, processVscp, VAccess::WRITE}, createProcessp};
        m_processSetups.push_back(assignp);
        return processVscp;
    }

    static bool isProcessQueuePush(const AstNode* const nodep) {
        const AstStmtExpr* const stmtp = VN_CAST(nodep, StmtExpr);
        const AstCMethodHard* const methodp
            = stmtp ? VN_CAST(stmtp->exprp(), CMethodHard) : nullptr;
        if (!methodp || methodp->method() != VCMethod::ARRAY_PUSH_BACK) return false;
        const AstVarRef* const queueRefp = VN_CAST(methodp->fromp(), VarRef);
        return queueRefp && queueRefp->varp()->processQueue();
    }

    void hoistProcessQueueRegistrations(AstBegin* const beginp, AstVarScope* const processVscp) {
        while (beginp->stmtsp()) {
            AstComment* const commentp = VN_CAST(beginp->stmtsp(), Comment);
            AstNode* const selfNodep = commentp ? commentp->nextp() : beginp->stmtsp();
            AstNode* const resultNodep = selfNodep ? selfNodep->nextp() : nullptr;
            AstAssign* const resultAssignp = VN_CAST(resultNodep, Assign);
            AstNode* const pushNodep = resultAssignp ? resultAssignp->nextp() : resultNodep;
            if (!isProcessQueuePush(pushNodep)) break;

            AstStmtExpr* const selfStmtp = VN_CAST(selfNodep, StmtExpr);
            AstCCall* const selfCallp = selfStmtp ? VN_CAST(selfStmtp->exprp(), CCall) : nullptr;
            AstStmtExpr* const pushStmtp = VN_AS(pushNodep, StmtExpr);
            AstCMethodHard* const pushMethodp = VN_AS(pushStmtp->exprp(), CMethodHard);
            AstVarRef* const selfOutputp
                = selfCallp ? VN_CAST(selfCallp->argsp(), VarRef) : nullptr;
            AstVarRef* const pushValuep = VN_CAST(pushMethodp->pinsp(), VarRef);
            AstVarRef* const resultLhsp
                = resultAssignp ? VN_CAST(resultAssignp->lhsp(), VarRef) : nullptr;
            AstVarRef* const resultRhsp
                = resultAssignp ? VN_CAST(resultAssignp->rhsp(), VarRef) : nullptr;
            const AstClassPackage* const classPackagep
                = selfCallp && selfCallp->funcp()->scopep()
                      ? VN_CAST(selfCallp->funcp()->scopep()->modp(), ClassPackage)
                      : nullptr;
            const bool directResult
                = selfOutputp && pushValuep
                  && selfOutputp->varScopep() == pushValuep->varScopep();
            const bool assignedResult
                = selfOutputp && resultLhsp && resultRhsp && pushValuep
                  && selfOutputp->varScopep() == resultRhsp->varScopep()
                  && resultLhsp->varScopep() == pushValuep->varScopep();
            UASSERT_OBJ(selfCallp && selfCallp->funcp()->needProcess() && selfOutputp
                            && !selfCallp->processp() && !selfOutputp->nextp() && pushValuep
                            && !pushValuep->nextp() && (directResult || assignedResult)
                            && (resultAssignp != nullptr) == assignedResult && classPackagep
                            && classPackagep->classp() == v3Global.rootp()->stdPackageProcessp(),
                        pushStmtp, "Malformed compiler-generated process registration");

            selfCallp->processp(
                new AstVarRef{selfCallp->fileline(), processVscp, VAccess::READWRITE});
            if (commentp) m_registrationSetups.push_back(commentp->unlinkFrBack());
            m_registrationSetups.push_back(selfStmtp->unlinkFrBack());
            if (resultAssignp) m_registrationSetups.push_back(resultAssignp->unlinkFrBack());
            m_registrationSetups.push_back(pushStmtp->unlinkFrBack());
        }
        for (AstNode* stmtp = beginp->stmtsp(); stmtp; stmtp = stmtp->nextp()) {
            UASSERT_OBJ(!isProcessQueuePush(stmtp), stmtp,
                        "Compiler-generated process registration is not at branch entry");
        }
    }

    bool hoistForkOnKill(AstBegin* const beginp, AstVarScope* const processVscp) {
        AstStmtExpr* const stmtp = VN_CAST(beginp->stmtsp(), StmtExpr);
        AstCMethodHard* const methodp = stmtp ? VN_CAST(stmtp->exprp(), CMethodHard) : nullptr;
        if (!methodp || methodp->method() != VCMethod::FORK_ON_KILL) return false;
        if (AstNode* const pinsp = methodp->pinsp()) {
            VL_DO_DANGLING(pushDeletep(pinsp->unlinkFrBackWithNext()), pinsp);
        }
        methodp->addPinsp(new AstVarRef{methodp->fileline(), processVscp, VAccess::READ});
        m_onKillSetups.push_back(stmtp->unlinkFrBack());
        return true;
    }

    // VISITORS
    void visit(AstNodeModule* nodep) override {
        VL_RESTORER(m_inClass);
        VL_RESTORER(m_processNames);
        m_inClass = VN_IS(nodep, Class);
        m_processNames.reset();
        iterateChildren(nodep);
    }
    void visit(AstCFunc* nodep) override {
        VL_RESTORER(m_funcp);
        m_funcp = nodep;
        iterateChildren(nodep);
    }
    void visit(AstVar* nodep) override {
        if (!m_forkp) nodep->user1(true);
    }
    void visit(AstFork* nodep) override {
        if (m_forkp) return;  // Handle forks in forks after moving them to new functions
        VL_RESTORER(m_forkp);
        VL_RESTORER(m_processSetups);
        VL_RESTORER(m_registrationSetups);
        VL_RESTORER(m_onKillSetups);
        m_forkp = nodep;
        m_processSetups.clear();
        m_registrationSetups.clear();
        m_onKillSetups.clear();
        iterateChildrenConst(nodep);  // Const, so we don't iterate the calls twice
        // Replace self with the function calls (no co_await, as we don't want the main
        // process to suspend whenever any of the children do)
        // V3Dead could have removed all statements from the fork, so guard against it
        // Inline begins now that they are not needed
        AstNode* resp = nullptr;
        if (AstNode* const declsp = nodep->declsp()) {
            resp = AstNode::addNext(resp, declsp->unlinkFrBackWithNext());
        }
        if (AstNode* const stmtsp = nodep->stmtsp()) {
            resp = AstNode::addNext(resp, stmtsp->unlinkFrBackWithNext());
        }
        for (AstNode* const setupp : m_processSetups) resp = AstNode::addNext(resp, setupp);
        for (AstNode* const setupp : m_registrationSetups) resp = AstNode::addNext(resp, setupp);
        for (AstNode* const setupp : m_onKillSetups) resp = AstNode::addNext(resp, setupp);
        while (AstBegin* const beginp = nodep->forksp()) {
            if (AstNode* const declsp = beginp->declsp()) {
                resp = AstNode::addNext(resp, declsp->unlinkFrBackWithNext());
            }
            if (AstNode* const stmtsp = beginp->stmtsp()) {
                resp = AstNode::addNext(resp, stmtsp->unlinkFrBackWithNext());
            }
            VL_DO_DANGLING(pushDeletep(beginp->unlinkFrBack()), beginp);
        }
        if (resp) {
            nodep->replaceWith(resp);
        } else {
            nodep->unlinkFrBack();
        }
        VL_DO_DANGLING(pushDeletep(nodep), nodep);
    }
    void visit(AstBegin* nodep) override {
        UASSERT_OBJ(m_forkp, nodep, "Begin outside of a fork");
        // Start with children, so later we only find awaits that are actually in this begin
        m_beginHasAwaits = false;
        iterateChildrenConst(nodep);
        if (!nodep->stmtsp()) return;
        if (!m_beginHasAwaits && !nodep->needProcess()) return;

        UASSERT_OBJ(!nodep->name().empty(), nodep, "Begin needs a name");
        // Create a function to put this begin's statements in
        FileLine* const flp = nodep->fileline();
        AstCFunc* const newfuncp = new AstCFunc{flp, m_funcp->name() + "__" + nodep->name(),
                                                m_funcp->scopep(), "VlCoroutine"};

        m_funcp->addNextHere(newfuncp);
        newfuncp->isLoose(m_funcp->isLoose());
        newfuncp->slow(m_funcp->slow());
        newfuncp->isConst(m_funcp->isConst());
        newfuncp->declPrivate(true);
        // Create the call to the function
        AstCCall* const callp = new AstCCall{flp, newfuncp};
        callp->dtypeSetVoid();
        AstVarScope* const processVscp
            = nodep->needProcess() ? createBranchProcess(nodep) : nullptr;
        if (processVscp) {
            const bool hasOnKill = hoistForkOnKill(nodep, processVscp);
            UASSERT_OBJ(m_forkp->joinType().joinNone() || hasOnKill, nodep,
                        "Process-backed blocking fork branch has no kill hook");
            hoistProcessQueueRegistrations(nodep, processVscp);
            callp->processp(new AstVarRef{flp, processVscp, VAccess::READWRITE});
        }
        // If we're in a class, add a vlSymsp arg
        if (m_inClass) {
            newfuncp->addStmtsp(new AstCStmt{flp, "VL_KEEP_THIS;"});
            newfuncp->argTypes(EmitCUtil::symClassVar());
            callp->argTypes("vlSymsp");
        }
        if (processVscp) {
            newfuncp->addStmtsp(new AstCStmt{
                flp, "if (VL_UNLIKELY(vlProcess->state() == VlProcess::KILLED)) co_return;"});
        }
        // Put the begin's statements in the function
        if (AstNode* const declsp = nodep->declsp()) {
            newfuncp->addStmtsp(declsp->unlinkFrBackWithNext());
        }
        if (AstNode* const stmtsp = nodep->stmtsp()) {
            newfuncp->addStmtsp(stmtsp->unlinkFrBackWithNext());
        }
        // Replace the body of the begin with a call to the newly created function
        nodep->addStmtsp(callp->makeStmt());
        // Propagate if needs process
        if (nodep->needProcess()) {
            newfuncp->setNeedProcess();
            auto* const finishedp
                = new AstCStmt{flp, "if (vlProcess->state() != VlProcess::KILLED) "
                                    "vlProcess->state(VlProcess::FINISHED);"};
            AstNode* tailp = newfuncp->stmtsp();
            while (tailp && tailp->nextp()) tailp = tailp->nextp();
            const AstStmtExpr* const stmtp = VN_CAST(tailp, StmtExpr);
            const AstCMethodHard* const methodp
                = stmtp ? VN_CAST(stmtp->exprp(), CMethodHard) : nullptr;
            // done() can synchronously resume the joining parent, which must observe FINISHED.
            if (methodp && methodp->method() == VCMethod::FORK_DONE) {
                tailp->addHereThisAsNext(finishedp);
            } else {
                newfuncp->addStmtsp(finishedp);
            }
        }
        remapLocals(newfuncp, callp);
    }
    void visit(AstCAwait* nodep) override {
        m_beginHasAwaits = true;
        iterateChildrenConst(nodep);
    }

    //--------------------
    void visit(AstNode* nodep) override { iterateChildren(nodep); }

public:
    // CONSTRUCTORS
    explicit TransformForksVisitor(AstNetlist* nodep) { iterate(nodep); }
    ~TransformForksVisitor() override = default;
};

void transformForks(AstNetlist* const netlistp) {
    if (!v3Global.usesTiming()) return;
    { TransformForksVisitor{netlistp}; }
    V3Global::dumpCheckGlobalTree("transform_forks", 0, dumpTreeEitherLevel() >= 3);
}

}  // namespace V3Sched
