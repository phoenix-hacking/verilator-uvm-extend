// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
//
// Code available from: https://verilator.org
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2001-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//=========================================================================
///
/// \file
/// \brief Verilated timing implementation code
///
/// This file must be compiled and linked against all Verilated objects
/// that use timing features.
///
/// See the internals documentation docs/internals.rst for details.
///
//=========================================================================

#include "verilated_timing.h"

namespace {

// Process-tree transitions and fork callbacks share this lock.  Callbacks are always delivered
// after releasing it, as they may synchronously resume generated code.
VerilatedMutex s_processMutex;
// Avoid taking the process mutex on the ordinary scheduler fast path when no named activation can
// own the suspension.
std::atomic<size_t> s_namedActivationCount{0};

}  // namespace

//======================================================================
// Named activation runtime state

class VlNamedActivationRegistryState final {
public:
    std::map<uint64_t, std::shared_ptr<VlNamedActivationState>>
        m_activations VL_GUARDED_BY(s_processMutex);
    uint64_t m_nextId VL_GUARDED_BY(s_processMutex) = 0;
};

using VlNamedActivationWeak = std::weak_ptr<VlNamedActivationState>;
using VlNamedActivationWeakSet
    = std::set<VlNamedActivationWeak, std::owner_less<VlNamedActivationWeak>>;
using VlCoroutineHandleStateWeak = std::weak_ptr<VlCoroutineHandleState>;
using VlCoroutineHandleStateWeakSet
    = std::set<VlCoroutineHandleStateWeak, std::owner_less<VlCoroutineHandleStateWeak>>;
using VlProcessWeak = std::weak_ptr<VlProcess>;
using VlProcessWeakSet = std::set<VlProcessWeak, std::owner_less<VlProcessWeak>>;

namespace {

struct VlCoroutineHandleContent final {
    std::coroutine_handle<> m_coro;
    VlProcessRef m_process;
    VlFileLineDebug m_fileline;
};

void destroyCoroutine(VlCoroutineHandleContent content);
bool resumeCoroutine(VlCoroutineHandleContent content);

}  // namespace

// Shared only for suspensions that belong to an active named activation.  The scheduler and
// activation registry race to consume this state exactly once; the scheduler keeps the empty state
// afterward as a harmless tombstone.
class VlCoroutineHandleState final {
public:
    VlCoroutineHandleContent m_content VL_GUARDED_BY(s_processMutex);
    std::vector<VlNamedActivationWeak> m_activationps VL_GUARDED_BY(s_processMutex);

    VlCoroutineHandleState(std::coroutine_handle<> coro, VlProcessRef process,
                           VlFileLineDebug fileline)
        : m_content{coro, std::move(process), fileline} {}

    bool pendingLocked() const VL_REQUIRES(s_processMutex) {
        return static_cast<bool>(m_content.m_coro);
    }
};

class VlNamedActivationState final {
public:
    std::weak_ptr<VlNamedActivationRegistryState> m_registryp;
    const std::shared_ptr<std::atomic<bool>> m_canceledp;
    const uint64_t m_id;
    VlNamedActivationWeakSet m_parentActivations VL_GUARDED_BY(s_processMutex);
    VlNamedActivationWeakSet m_childActivations VL_GUARDED_BY(s_processMutex);
    VlCoroutineHandleStateWeakSet m_suspensions VL_GUARDED_BY(s_processMutex);
    VlProcessWeakSet m_childProcessps VL_GUARDED_BY(s_processMutex);
    VlProcessWeakSet m_memberProcessps VL_GUARDED_BY(s_processMutex);
    bool m_active VL_GUARDED_BY(s_processMutex) = true;

    VlNamedActivationState(const std::shared_ptr<VlNamedActivationRegistryState>& registryp,
                           std::shared_ptr<std::atomic<bool>> canceledp, uint64_t id)
        : m_registryp{registryp}
        , m_canceledp{std::move(canceledp)}
        , m_id{id} {}

    bool activeLocked() const VL_REQUIRES(s_processMutex) { return m_active; }
};

namespace {

using VlNamedActivationProcessMap
    = std::map<VlProcessWeak, VlNamedActivationWeakSet, std::owner_less<VlProcessWeak>>;
VlNamedActivationProcessMap s_namedActivationsByProcess VL_GUARDED_BY(s_processMutex);

void detachNamedActivationLocked(const std::shared_ptr<VlNamedActivationState>& activationp)
    VL_REQUIRES(s_processMutex) {
    VL_DEBUG_IFDEF(assert(activationp->m_active););
    activationp->m_active = false;
    s_namedActivationCount.fetch_sub(1, std::memory_order_release);
    const VlNamedActivationWeak activationWeak{activationp};
    for (const VlProcessWeak& member : activationp->m_memberProcessps) {
        const auto processIt = s_namedActivationsByProcess.find(member);
        if (processIt == s_namedActivationsByProcess.end()) continue;
        VlNamedActivationWeakSet& processActivations = processIt->second;
        processActivations.erase(activationWeak);
        if (processActivations.empty()) s_namedActivationsByProcess.erase(processIt);
    }
    for (const VlNamedActivationWeak& parent : activationp->m_parentActivations) {
        if (const std::shared_ptr<VlNamedActivationState> parentp = parent.lock()) {
            parentp->m_childActivations.erase(activationWeak);
        }
    }
    for (const VlNamedActivationWeak& child : activationp->m_childActivations) {
        if (const std::shared_ptr<VlNamedActivationState> childp = child.lock()) {
            childp->m_parentActivations.erase(activationWeak);
        }
    }
    activationp->m_parentActivations.clear();
    activationp->m_childActivations.clear();
    activationp->m_suspensions.clear();
    activationp->m_childProcessps.clear();
    activationp->m_memberProcessps.clear();
}

std::vector<std::shared_ptr<VlNamedActivationState>>
activeNamedActivationsLocked(const VlProcessRef& processp) VL_REQUIRES(s_processMutex) {
    std::vector<std::shared_ptr<VlNamedActivationState>> result;
    if (!processp) return result;
    const auto processIt = s_namedActivationsByProcess.find(VlProcessWeak{processp});
    if (processIt == s_namedActivationsByProcess.end()) return result;
    VlNamedActivationWeakSet& processActivations = processIt->second;
    for (auto it = processActivations.begin(); it != processActivations.end();) {
        const std::shared_ptr<VlNamedActivationState> activationp = it->lock();
        if (!activationp || !activationp->activeLocked()) {
            it = processActivations.erase(it);
            continue;
        }
        result.emplace_back(activationp);
        ++it;
    }
    if (processActivations.empty()) s_namedActivationsByProcess.erase(processIt);
    return result;
}

std::shared_ptr<VlCoroutineHandleState>
registerNamedActivationSuspensionLocked(std::coroutine_handle<> coro, const VlProcessRef& processp,
                                        VlFileLineDebug fileline) VL_REQUIRES(s_processMutex) {
    const std::vector<std::shared_ptr<VlNamedActivationState>> activationps
        = activeNamedActivationsLocked(processp);
    if (activationps.empty()) return nullptr;
    const std::shared_ptr<VlCoroutineHandleState> statep
        = std::make_shared<VlCoroutineHandleState>(coro, processp, fileline);
    for (const std::shared_ptr<VlNamedActivationState>& activationp : activationps) {
        activationp->m_suspensions.emplace(statep);
        statep->m_activationps.emplace_back(activationp);
    }
    return statep;
}

VlCoroutineHandleContent
takeNamedActivationSuspensionLocked(const std::shared_ptr<VlCoroutineHandleState>& statep)
    VL_REQUIRES(s_processMutex) {
    const VlCoroutineHandleStateWeak stateWeak{statep};
    for (const VlNamedActivationWeak& activation : statep->m_activationps) {
        if (const std::shared_ptr<VlNamedActivationState> activationp = activation.lock()) {
            activationp->m_suspensions.erase(stateWeak);
        }
    }
    statep->m_activationps.clear();
    return std::exchange(statep->m_content, VlCoroutineHandleContent{});
}

std::vector<std::shared_ptr<VlCoroutineHandleState>>
activeNamedActivationSuspensionsLocked(const std::shared_ptr<VlNamedActivationState>& activationp)
    VL_REQUIRES(s_processMutex) {
    std::vector<std::shared_ptr<VlCoroutineHandleState>> result;
    for (auto it = activationp->m_suspensions.begin(); it != activationp->m_suspensions.end();) {
        const std::shared_ptr<VlCoroutineHandleState> statep = it->lock();
        if (!statep || !statep->pendingLocked()) {
            it = activationp->m_suspensions.erase(it);
            continue;
        }
        result.emplace_back(statep);
        ++it;
    }
    return result;
}

void addNamedActivationMemberLocked(const std::shared_ptr<VlNamedActivationState>& activationp,
                                    const VlProcessRef& processp, bool childProcess)
    VL_REQUIRES(s_processMutex) {
    if (!processp || !activationp->activeLocked()) return;
    const VlProcessWeak processWeak{processp};
    const auto inserted = activationp->m_memberProcessps.emplace(processWeak);
    if (inserted.second) { s_namedActivationsByProcess[processWeak].emplace(activationp); }
    if (childProcess) activationp->m_childProcessps.emplace(processWeak);
}

void detachNamedActivationProcessLocked(const VlProcessRef& processp) VL_REQUIRES(s_processMutex) {
    const VlProcessWeak processWeak{processp};
    const auto processIt = s_namedActivationsByProcess.find(processWeak);
    if (processIt == s_namedActivationsByProcess.end()) return;
    const VlNamedActivationWeakSet processActivations = processIt->second;
    s_namedActivationsByProcess.erase(processIt);
    for (const VlNamedActivationWeak& activation : processActivations) {
        if (const std::shared_ptr<VlNamedActivationState> activationp = activation.lock()) {
            activationp->m_memberProcessps.erase(processWeak);
            activationp->m_childProcessps.erase(processWeak);
        }
    }
}

}  // namespace

//======================================================================
// VlNamedActivationRegistry/VlNamedActivationGuard:: Methods

VlNamedActivationRegistry::VlNamedActivationRegistry()
    : m_statep{std::make_shared<VlNamedActivationRegistryState>()} {}

VlNamedActivationRegistry::~VlNamedActivationRegistry() {
    const VerilatedLockGuard lock{s_processMutex};
    std::vector<std::shared_ptr<VlNamedActivationState>> activationps;
    activationps.reserve(m_statep->m_activations.size());
    for (const auto& activation : m_statep->m_activations) {
        activationps.emplace_back(activation.second);
    }
    m_statep->m_activations.clear();
    for (const std::shared_ptr<VlNamedActivationState>& activationp : activationps) {
        detachNamedActivationLocked(activationp);
    }
}

VlNamedActivationGuard VlNamedActivationRegistry::activate(const VlProcessRef& ownerp) VL_MT_SAFE {
    const VerilatedLockGuard lock{s_processMutex};
    VL_DEBUG_IFDEF(assert(!ownerp || !ownerp->completed()););
    const std::vector<std::shared_ptr<VlNamedActivationState>> parentActivations
        = activeNamedActivationsLocked(ownerp);
    const std::shared_ptr<std::atomic<bool>> canceledp
        = std::make_shared<std::atomic<bool>>(false);
    const std::shared_ptr<VlNamedActivationState> activationp
        = std::make_shared<VlNamedActivationState>(m_statep, canceledp, m_statep->m_nextId++);
    const auto inserted = m_statep->m_activations.emplace(activationp->m_id, activationp);
    VL_DEBUG_IFDEF(assert(inserted.second););
    s_namedActivationCount.fetch_add(1, std::memory_order_release);
    for (const std::shared_ptr<VlNamedActivationState>& parentp : parentActivations) {
        parentp->m_childActivations.emplace(activationp);
        activationp->m_parentActivations.emplace(parentp);
    }
    addNamedActivationMemberLocked(activationp, ownerp, false);
    return VlNamedActivationGuard{activationp};
}

void VlNamedActivationRegistry::disableAll() VL_MT_UNSAFE {
    const std::shared_ptr<VlNamedActivationRegistryState> replacementp
        = std::make_shared<VlNamedActivationRegistryState>();
    std::vector<std::shared_ptr<VlNamedActivationState>> activationps;
    std::set<std::shared_ptr<VlCoroutineHandleState>,
             std::owner_less<std::shared_ptr<VlCoroutineHandleState>>>
        suspensionps;
    std::vector<VlProcessRef> rootProcessps;
    std::vector<VlProcessRef> heldProcessps;
    std::vector<std::shared_ptr<VlForkSyncState>> forkSyncps;
    std::vector<VlCoroutineHandleContent> killedSuspensions;
    std::vector<VlCoroutineHandleContent> ownerSuspensions;
    {
        const VerilatedLockGuard lock{s_processMutex};
        const std::shared_ptr<VlNamedActivationRegistryState> drainedp
            = std::exchange(m_statep, replacementp);
        replacementp->m_nextId = drainedp->m_nextId;
        std::vector<std::shared_ptr<VlNamedActivationState>> pendingActivationps;
        pendingActivationps.reserve(drainedp->m_activations.size());
        for (const auto& activation : drainedp->m_activations) {
            pendingActivationps.emplace_back(activation.second);
        }
        std::set<VlNamedActivationState*> seenActivationps;
        while (!pendingActivationps.empty()) {
            std::shared_ptr<VlNamedActivationState> activationp
                = std::move(pendingActivationps.back());
            pendingActivationps.pop_back();
            if (!activationp || !activationp->activeLocked()
                || !seenActivationps.emplace(activationp.get()).second) {
                continue;
            }
            activationps.emplace_back(activationp);
            for (const VlNamedActivationWeak& child : activationp->m_childActivations) {
                if (const std::shared_ptr<VlNamedActivationState> childp = child.lock()) {
                    pendingActivationps.emplace_back(childp);
                }
            }
        }

        // Every activation observes cancellation before a killed child can resume generated code.
        for (const std::shared_ptr<VlNamedActivationState>& activationp : activationps) {
            activationp->m_canceledp->store(true, std::memory_order_release);
            if (const std::shared_ptr<VlNamedActivationRegistryState> registryp
                = activationp->m_registryp.lock()) {
                registryp->m_activations.erase(activationp->m_id);
            }
            for (const VlProcessWeak& child : activationp->m_childProcessps) {
                if (const VlProcessRef childp = child.lock()) {
                    rootProcessps.emplace_back(childp);
                }
            }
            const std::vector<std::shared_ptr<VlCoroutineHandleState>> activationSuspensionps
                = activeNamedActivationSuspensionsLocked(activationp);
            suspensionps.insert(activationSuspensionps.begin(), activationSuspensionps.end());
        }
        for (const std::shared_ptr<VlNamedActivationState>& activationp : activationps) {
            detachNamedActivationLocked(activationp);
        }
        VlProcess::disableProcessesLocked(rootProcessps, heldProcessps, forkSyncps);
        for (const std::shared_ptr<VlCoroutineHandleState>& suspensionp : suspensionps) {
            VlCoroutineHandleContent content = takeNamedActivationSuspensionLocked(suspensionp);
            if (!content.m_coro) continue;
            if (content.m_process && content.m_process->state() == VlProcess::KILLED) {
                killedSuspensions.emplace_back(std::move(content));
            } else {
                ownerSuspensions.emplace_back(std::move(content));
            }
        }
    }
    // A killed frame can own the last fork-sync reference and must be gone before callbacks
    // inspect the completed forest.  Callbacks may reenter generated code; canceled surviving
    // owners resume only after every callback observes the aggregate killed state.
    for (VlCoroutineHandleContent& content : killedSuspensions) {
        destroyCoroutine(std::move(content));
    }
    for (const std::shared_ptr<VlForkSyncState>& forkSyncp : forkSyncps) forkSyncp->done();
    for (VlCoroutineHandleContent& content : ownerSuspensions) {
        resumeCoroutine(std::move(content));
    }
}

size_t VlNamedActivationRegistry::size() const VL_MT_SAFE {
    const VerilatedLockGuard lock{s_processMutex};
    return m_statep->m_activations.size();
}

VlNamedActivationStats VlNamedActivationRegistry::stats() const VL_MT_SAFE {
    const VerilatedLockGuard lock{s_processMutex};
    VlNamedActivationStats result;
    result.m_activations = m_statep->m_activations.size();
    for (const auto& activation : m_statep->m_activations) {
        const std::shared_ptr<VlNamedActivationState>& activationp = activation.second;
        result.m_parentActivations += activationp->m_parentActivations.size();
        result.m_childActivations += activationp->m_childActivations.size();
        result.m_processMembers += activationp->m_memberProcessps.size();
        result.m_childProcesses += activationp->m_childProcessps.size();
        result.m_suspensions += activeNamedActivationSuspensionsLocked(activationp).size();
    }
    result.m_globalProcessMapEntries = s_namedActivationsByProcess.size();
    for (const auto& process : s_namedActivationsByProcess) {
        result.m_globalProcessMemberships += process.second.size();
    }
    return result;
}

VlNamedActivationGuard::VlNamedActivationGuard(
    const std::shared_ptr<VlNamedActivationState>& statep)
    : m_statep{statep}
    , m_token{statep->m_canceledp} {}

VlNamedActivationGuard::VlNamedActivationGuard(VlNamedActivationGuard&& moved) noexcept
    : m_statep{std::move(moved.m_statep)}
    , m_token{std::move(moved.m_token)} {}

VlNamedActivationGuard&
VlNamedActivationGuard::operator=(VlNamedActivationGuard&& moved) noexcept {
    if (this == &moved) return *this;
    leave();
    m_statep = std::move(moved.m_statep);
    m_token = std::move(moved.m_token);
    return *this;
}

VlNamedActivationGuard::~VlNamedActivationGuard() { leave(); }

void VlNamedActivationGuard::leave() {
    const std::shared_ptr<VlNamedActivationState> statep = m_statep.lock();
    m_statep.reset();
    if (!statep) return;
    const VerilatedLockGuard lock{s_processMutex};
    if (!statep->activeLocked()) return;
    if (const std::shared_ptr<VlNamedActivationRegistryState> registryp
        = statep->m_registryp.lock()) {
        registryp->m_activations.erase(statep->m_id);
    }
    detachNamedActivationLocked(statep);
}

bool VlNamedActivationGuard::canceled() const VL_MT_SAFE { return m_token.canceled(); }

//======================================================================
// VlCoroutineHandle:: Methods

namespace {

void destroyCoroutine(VlCoroutineHandleContent content) {
    if (!content.m_coro) return;
    const std::coroutine_handle<> coro = std::exchange(content.m_coro, nullptr);
    const VlProcessRef process = std::move(content.m_process);
    coro.destroy();
    if (process && process->state() != VlProcess::KILLED) { process->state(VlProcess::FINISHED); }
}

bool resumeCoroutine(VlCoroutineHandleContent content) {
    const std::coroutine_handle<> coro = std::exchange(content.m_coro, nullptr);
    if (!coro) return false;
    const VlProcessRef process = std::move(content.m_process);
#ifdef VL_DEBUG
    VL_DEBUG_IF(VL_DBG_MSGF("             Resuming: Process waiting at %s:%d\n",
                            content.m_fileline.filename(), content.m_fileline.lineno()););
#endif
    if (process) {  // If process state is managed with std::process
        if (process->state() == VlProcess::KILLED) {
            coro.destroy();
        } else {
            process->state(VlProcess::RUNNING);
            const bool contextOwner = process->enter();
            coro();
            if (contextOwner) process->leave();
        }
    } else {
        VlProcess* const previousProcessp = VlProcess::currentp();
        VlProcess::currentp(nullptr);
        coro();
        VlProcess::currentp(previousProcessp);
    }
    return true;
}

}  // namespace

VlCoroutineHandle::VlCoroutineHandle(VlProcessRef process)
    : m_coro{nullptr}
    , m_process{std::move(process)} {
    if (m_process) m_process->state(VlProcess::WAITING);
}

VlCoroutineHandle::VlCoroutineHandle(std::coroutine_handle<> coro, VlProcessRef process,
                                     VlFileLineDebug fileline)
    : m_coro{coro}
    , m_process{std::move(process)}
    , m_fileline{fileline} {
    if (!m_process) return;
    m_process->state(VlProcess::WAITING);
    m_process->leave();
    if (s_namedActivationCount.load(std::memory_order_acquire) != 0) {
        const VerilatedLockGuard lock{s_processMutex};
        m_statep = registerNamedActivationSuspensionLocked(m_coro, m_process, m_fileline);
        if (m_statep) {
            m_coro = nullptr;
            m_process.reset();
        }
    }
}

VlCoroutineHandle::VlCoroutineHandle(VlCoroutineHandle&& moved)
    : m_coro{std::exchange(moved.m_coro, nullptr)}
    , m_statep{std::move(moved.m_statep)}
    , m_process{std::exchange(moved.m_process, nullptr)}
    , m_fileline{moved.m_fileline} {}

VlCoroutineHandle::~VlCoroutineHandle() { reset(); }

VlCoroutineHandle& VlCoroutineHandle::operator=(VlCoroutineHandle&& moved) {
    if (this == &moved) return *this;
    reset();
    m_coro = std::exchange(moved.m_coro, nullptr);
    m_statep = std::move(moved.m_statep);
    m_process = std::exchange(moved.m_process, nullptr);
    m_fileline = moved.m_fileline;
    return *this;
}

void VlCoroutineHandle::reset() {
    VlCoroutineHandleContent content{std::exchange(m_coro, nullptr),
                                     std::exchange(m_process, nullptr), m_fileline};
    if (m_statep) {
        const std::shared_ptr<VlCoroutineHandleState> statep = std::move(m_statep);
        const VerilatedLockGuard lock{s_processMutex};
        content = takeNamedActivationSuspensionLocked(statep);
    }
    // Destroy outside the process mutex: frame destructors may clear fork callbacks and take it.
    destroyCoroutine(std::move(content));
}

bool VlCoroutineHandle::pending() const {
    if (!m_statep) return static_cast<bool>(m_coro);
    const VerilatedLockGuard lock{s_processMutex};
    return m_statep->pendingLocked();
}

bool VlCoroutineHandle::resume() {
    // Only null if we have a fork..join_any and one of the other child processes resumed the
    // main process.  A canceled activation also leaves a null shared tombstone behind.
    if (m_statep) {
        const std::shared_ptr<VlCoroutineHandleState> statep = std::move(m_statep);
        VlCoroutineHandleContent content;
        {
            const VerilatedLockGuard lock{s_processMutex};
            content = takeNamedActivationSuspensionLocked(statep);
        }
        return resumeCoroutine(std::move(content));
    }
    return resumeCoroutine(VlCoroutineHandleContent{
        std::exchange(m_coro, nullptr), std::exchange(m_process, nullptr), m_fileline});
}

#ifdef VL_DEBUG
void VlCoroutineHandle::dump() const {
    VL_PRINTF("Process waiting at %s:%d\n", m_fileline.filename(), m_fileline.lineno());
}
#endif

//======================================================================
// VlDelayScheduler:: Methods

void VlDelayScheduler::resume() {
#ifdef VL_DEBUG
    VL_DEBUG_IF(dump(); VL_DBG_MSGF("         Resuming delayed processes\n"););
#endif
    if (VL_UNLIKELY(m_context.gotFinish())) {
        m_queue.clear();
        m_zeroDelayed.clear();
        m_zeroDelayesSwap.clear();
        return;
    }
    bool processed = false;

    while (!m_queue.empty() && (m_queue.cbegin()->first <= m_context.time())) {
        const uint64_t resumeTime = m_queue.cbegin()->first;
        VlCoroutineHandle handle = std::move(m_queue.begin()->second);
        m_queue.erase(m_queue.begin());
        // A canceled entry may legitimately remain as an overdue tombstone.  Discard it before
        // checking the next entry, but never let it hide a live process whose time slot was
        // missed.
        if (resumeTime < m_context.time() && handle.pending()) {
            VL_FATAL_MT(__FILE__, __LINE__, "",
                        "%Error: Encountered process that should've been resumed at an "
                        "earlier simulation time. Missed a time slot?\n");
        }
        handle.resume();
        processed = true;
    }

    if (!processed) {
        if (m_context.time() == 0) {
            // Nothing was scheduled at time 0, but resume() got called due to --x-initial-edge
            return;
        }

        VL_FATAL_MT(__FILE__, __LINE__, "",
                    "%Error: Encountered process that should've been resumed at an "
                    "earlier simulation time. Missed a time slot?\n");
    }
}

void VlDelayScheduler::resumeZeroDelay() {
    if (VL_UNLIKELY(m_context.gotFinish())) {
        m_zeroDelayed.clear();
        m_zeroDelayesSwap.clear();
        return;
    }
    m_zeroDelayesSwap.swap(m_zeroDelayed);
    for (VlCoroutineHandle& handle : m_zeroDelayesSwap) handle.resume();
    m_zeroDelayesSwap.clear();
}

uint64_t VlDelayScheduler::nextTimeSlot() const {
    for (const auto& delayed : m_queue) {
        if (delayed.second.pending()) return delayed.first;
    }
    for (const VlCoroutineHandle& handle : m_zeroDelayed) {
        if (handle.pending()) return m_context.time();
    }
    VL_FATAL_MT(__FILE__, __LINE__, "", "There is no next time slot scheduled");
    return 0;
}

#ifdef VL_DEBUG
void VlDelayScheduler::dump() const {
    if (m_queue.empty() && m_zeroDelayed.empty()) {
        VL_DBG_MSGF("         No delayed processes:\n");
    } else {
        VL_DBG_MSGF("         Delayed processes:\n");
        for (const auto& susp : m_zeroDelayed) {
            VL_DBG_MSGF("             Awaiting #0-delayed resumption, "
                        "time () %" PRIu64 ": ",
                        m_context.time());
            susp.dump();
        }
        for (const auto& susp : m_queue) {
            VL_DBG_MSGF("             Awaiting time %" PRIu64 ": ", susp.first);
            susp.second.dump();
        }
    }
}
#endif

//======================================================================
// VlTriggerScheduler:: Methods

void VlTriggerScheduler::resume(const char* eventDescription) {
#ifdef VL_DEBUG
    VL_DEBUG_IF(dump(eventDescription);
                VL_DBG_MSGF("         Resuming processes waiting for %s\n", eventDescription););
#endif
    if (VL_UNLIKELY(Verilated::threadContextp()->gotFinish())) {
        m_toResume.clear();
        m_fired.clear();
        m_awaiting.clear();
        return;
    }
    for (VlCoroutineHandle& coro : m_toResume) coro.resume();
    m_toResume.clear();
}

void VlTriggerScheduler::moveToResumeQueue(const char* eventDescription) {
#ifdef VL_DEBUG
    if (!m_fired.empty()) {
        VL_DEBUG_IF(VL_DBG_MSGF("         Moving to resume queue processes waiting for %s:\n",
                                eventDescription);
                    for (const auto& susp
                         : m_fired) {
                        VL_DBG_MSGF("           - ");
                        susp.dump();
                    });
    }
#endif
    if (VL_UNLIKELY(Verilated::threadContextp()->gotFinish())) {
        m_toResume.clear();
        m_fired.clear();
        return;
    }
    std::swap(m_fired, m_toResume);
}

void VlTriggerScheduler::ready(const char* eventDescription) {
#ifdef VL_DEBUG
    if (!m_awaiting.empty()) {
        VL_DEBUG_IF(
            VL_DBG_MSGF("         Committing processes waiting for %s:\n", eventDescription);
            for (const auto& susp
                 : m_awaiting) {
                VL_DBG_MSGF("           - ");
                susp.dump();
            });
    }
#endif
    if (VL_UNLIKELY(Verilated::threadContextp()->gotFinish())) {
        m_fired.clear();
        m_awaiting.clear();
        return;
    }
    const size_t expectedSize = m_fired.size() + m_awaiting.size();
    if (m_fired.capacity() < expectedSize) m_fired.reserve(expectedSize * 2);
    m_fired.insert(m_fired.end(), std::make_move_iterator(m_awaiting.begin()),
                   std::make_move_iterator(m_awaiting.end()));
    m_awaiting.clear();
}

#ifdef VL_DEBUG
void VlTriggerScheduler::dump(const char* eventDescription) const {
    if (m_toResume.empty()) {
        VL_DBG_MSGF("         No process to resume waiting for %s\n", eventDescription);
    } else {
        for (const auto& susp : m_toResume) {
            VL_DBG_MSGF("         Processes to resume waiting for %s:\n", eventDescription);
            VL_DBG_MSGF("           - ");
            susp.dump();
        }
    }
    if (!m_fired.empty()) {
        VL_DBG_MSGF("         Triggered processes waiting for %s:\n", eventDescription);
        for (const auto& susp : m_awaiting) {
            VL_DBG_MSGF("           - ");
            susp.dump();
        }
    }
    if (!m_awaiting.empty()) {
        VL_DBG_MSGF("         Not triggered processes waiting for %s:\n", eventDescription);
        for (const auto& susp : m_awaiting) {
            VL_DBG_MSGF("           - ");
            susp.dump();
        }
    }
}
#endif

//======================================================================
// VlDynamicTriggerScheduler:: Methods

bool VlDynamicTriggerScheduler::evaluate() {
    if (VL_UNLIKELY(Verilated::threadContextp()->gotFinish())) {
        m_anyTriggered = false;
        m_suspended.clear();
        m_evaluated.clear();
        m_triggered.clear();
        m_post.clear();
        return false;
    }
    m_anyTriggered = false;
    VL_DEBUG_IF(dump(););
    std::swap(m_suspended, m_evaluated);
    for (auto& coro : m_evaluated) coro.resume();
    m_evaluated.clear();
    return m_anyTriggered;
}

void VlDynamicTriggerScheduler::doPostUpdates() {
    VL_DEBUG_IF(if (!m_post.empty())
                    VL_DBG_MSGF("         Doing post updates for processes:\n");  //
                for (const auto& susp
                     : m_post) {
                    VL_DBG_MSGF("           - ");
                    susp.dump();
                });
    if (VL_UNLIKELY(Verilated::threadContextp()->gotFinish())) {
        m_post.clear();
        return;
    }
    for (auto& coro : m_post) coro.resume();
    m_post.clear();
}

void VlDynamicTriggerScheduler::resume() {
    VL_DEBUG_IF(if (!m_triggered.empty()) VL_DBG_MSGF("         Resuming processes:\n");  //
                for (const auto& susp
                     : m_triggered) {
                    VL_DBG_MSGF("           - ");
                    susp.dump();
                });
    if (VL_UNLIKELY(Verilated::threadContextp()->gotFinish())) {
        m_triggered.clear();
        return;
    }
    for (auto& coro : m_triggered) coro.resume();
    m_triggered.clear();
}

#ifdef VL_DEBUG
void VlDynamicTriggerScheduler::dump() const {
    if (m_suspended.empty()) {
        VL_DBG_MSGF("         No suspended processes waiting for dynamic trigger evaluation\n");
    } else {
        for (const auto& susp : m_suspended) {
            VL_DBG_MSGF("         Suspended processes waiting for dynamic trigger evaluation:\n");
            VL_DBG_MSGF("           - ");
            susp.dump();
        }
    }
}
#endif

//======================================================================
// VlProcess:: Methods

VlProcess::VlProcess(const VlProcessRef& parentp)
    : m_state{RUNNING}
    , m_parentp{parentp} {}

VlProcessRef VlProcess::createChild(VlProcessRef parentp) {
    if (!parentp) return std::make_shared<VlProcess>();
    VlProcessRef processp{new VlProcess{parentp}};
    const VerilatedLockGuard lock{s_processMutex};
    VL_DEBUG_IFDEF(assert(!parentp->completed()););
    parentp->attachLocked(processp);
    const std::vector<std::shared_ptr<VlNamedActivationState>> activationps
        = activeNamedActivationsLocked(parentp);
    for (const std::shared_ptr<VlNamedActivationState>& activationp : activationps) {
        addNamedActivationMemberLocked(activationp, processp, true);
    }
    return processp;
}

void VlProcess::attachLocked(const VlProcessRef& childp) {
    VL_DEBUG_IFDEF(assert(!m_completedTree););
    const auto inserted = m_children.emplace(childp.get(), childp);
    VL_DEBUG_IFDEF(assert(inserted.second););
}

void VlProcess::detachLocked(VlProcess* const childp) {
    const auto it = m_children.find(childp);
    VL_DEBUG_IFDEF(assert(it != m_children.end()););
    if (it != m_children.end()) m_children.erase(it);
}

void VlProcess::completeTreeLocked() {
    VlProcessRef processp = shared_from_this();
    while (processp && processp->completed() && processp->m_children.empty()
           && !processp->m_completedTree) {
        processp->m_completedTree = true;
        const VlProcessRef parentp = processp->m_parentp.lock();
        processp->m_parentp.reset();
        if (parentp) parentp->detachLocked(processp.get());
        processp = parentp;
    }
}

bool VlProcess::completedForkLocked() const {
    for (const auto& child : m_children)
        if (!child.second->completed()) return false;
    return true;
}

bool VlProcess::completedFork() const {
    const VerilatedLockGuard lock{s_processMutex};
    return completedForkLocked();
}

void VlProcess::disableProcessesLocked(const std::vector<VlProcessRef>& rootProcessps,
                                       std::vector<VlProcessRef>& heldProcessps,
                                       std::vector<std::shared_ptr<VlForkSyncState>>& forkSyncps)
    VL_REQUIRES(s_processMutex) {
    std::vector<VlProcessRef> pendingProcessps = rootProcessps;
    std::set<VlProcess*> seenProcessps;
    while (!pendingProcessps.empty()) {
        VlProcessRef processp = std::move(pendingProcessps.back());
        pendingProcessps.pop_back();
        if (!processp || !seenProcessps.emplace(processp.get()).second) continue;
        heldProcessps.emplace_back(processp);
        for (const auto& child : processp->m_children) pendingProcessps.emplace_back(child.second);
    }
    forkSyncps.reserve(heldProcessps.size());

    // Mark the full tree before callbacks can resume or destroy any coroutine frames.
    for (const VlProcessRef& processp : heldProcessps) {
        const int state = processp->m_state.load(std::memory_order_relaxed);
        if (state == KILLED || state == FINISHED) continue;
        processp->m_state.store(KILLED, std::memory_order_release);
        if (processp->m_forkSyncOnKillDone) continue;
        if (const std::shared_ptr<VlForkSyncState> forkSyncp
            = processp->m_forkSyncOnKillp.lock()) {
            processp->m_forkSyncOnKillDone = true;
            forkSyncps.emplace_back(forkSyncp);
        }
    }

    for (const VlProcessRef& processp : heldProcessps) {
        detachNamedActivationProcessLocked(processp);
    }

    for (auto it = heldProcessps.rbegin(); it != heldProcessps.rend(); ++it) {
        (*it)->completeTreeLocked();
    }
}

void VlProcess::disableProcesses(const std::vector<VlProcessRef>& rootProcessps) {
    std::vector<VlProcessRef> heldProcessps;
    std::vector<std::shared_ptr<VlForkSyncState>> forkSyncps;
    {
        const VerilatedLockGuard lock{s_processMutex};
        disableProcessesLocked(rootProcessps, heldProcessps, forkSyncps);
    }
    for (const std::shared_ptr<VlForkSyncState>& forkSyncp : forkSyncps) forkSyncp->done();
}

void VlProcess::disable() { disableProcesses({shared_from_this()}); }

void VlProcess::disableFork() {
    std::vector<VlProcessRef> heldProcessps;
    std::vector<std::shared_ptr<VlForkSyncState>> forkSyncps;
    {
        const VerilatedLockGuard lock{s_processMutex};
        std::vector<VlProcessRef> processps;
        processps.reserve(m_children.size());
        for (const auto& child : m_children) processps.emplace_back(child.second);
        disableProcessesLocked(processps, heldProcessps, forkSyncps);
    }
    for (const std::shared_ptr<VlForkSyncState>& forkSyncp : forkSyncps) forkSyncp->done();
}

bool VlProcess::forkSyncOnKill(const std::shared_ptr<VlForkSyncState>& forkSyncp) {
    const VerilatedLockGuard lock{s_processMutex};
    if (completed()) return false;
    m_forkSyncOnKillp = forkSyncp;
    m_forkSyncOnKillDone = false;
    return true;
}

void VlProcess::forkSyncOnKillClear(VlForkSyncState* forkSyncp) {
    const VerilatedLockGuard lock{s_processMutex};
    const std::shared_ptr<VlForkSyncState> registeredp = m_forkSyncOnKillp.lock();
    if (registeredp && registeredp.get() != forkSyncp) return;
    m_forkSyncOnKillp.reset();
    m_forkSyncOnKillDone = false;
}

void VlProcess::state(int s) {
    if (s == KILLED) {
        disable();
        return;
    }
    if (s == FINISHED) {
        const VerilatedLockGuard lock{s_processMutex};
        const int oldState = m_state.load(std::memory_order_relaxed);
        if (oldState == KILLED || oldState == FINISHED) return;
        m_state.store(FINISHED, std::memory_order_release);
        detachNamedActivationProcessLocked(shared_from_this());
        completeTreeLocked();
        return;
    }
    int oldState = m_state.load(std::memory_order_acquire);
    while (oldState != KILLED && oldState != FINISHED
           && !m_state.compare_exchange_weak(oldState, s, std::memory_order_acq_rel,
                                             std::memory_order_acquire)) {}
}

VlForkSyncState::~VlForkSyncState() {
    for (const VlProcessRef& processp : m_onKillProcessps) processp->forkSyncOnKillClear(this);
}

void VlForkSync::onKill(VlProcessRef process) {
    if (!process) return;
    const std::shared_ptr<VlForkSyncState> statep = m_state;
    if (!process->forkSyncOnKill(statep)) {
        statep->done();
        return;
    }
    statep->m_onKillProcessps.emplace_back(process);
}

void VlForkSyncState::done(const char* filename, int lineno) {
    VL_DEBUG_IF(VL_DBG_MSGF("             Process forked at %s:%d finished\n", filename, lineno););
    if (!m_inited) {
        ++m_pendingDones;
        return;
    }
    if (m_counter > 0) m_counter--;
    if (m_counter != 0) return;
    if (m_inDone) {
        m_resumePending = true;
        return;
    }
    m_inDone = true;
    do {
        m_resumePending = false;
        m_susp.resume();
    } while (m_resumePending && m_inited && m_counter == 0);
    m_inDone = false;
}

//======================================================================
// VlCoroutine:: Methods

VlCoroutine::VlPromise::~VlPromise() {
    // Indicate to the return object that the coroutine has finished or been destroyed
    if (m_corop) m_corop->m_promisep = nullptr;
    // If there is a continuation, destroy it
    if (m_continuation) m_continuation.destroy();
}

void VlCoroutine::VlPromise::suspendForever() {
    if (!m_corop) return;
    m_corop->m_promisep = nullptr;
    m_corop->m_suspendedForever = true;
    m_corop = nullptr;
}

std::suspend_never VlCoroutine::VlPromise::final_suspend() noexcept {
    // Indicate to the return object that the coroutine has finished
    if (m_corop) {
        m_corop->m_promisep = nullptr;
        // Forget the return value, we won't need it and it won't be able to let us know if
        // it's destroyed
        m_corop = nullptr;
    }
    // If there is a continuation, resume it
    if (m_continuation) {
        m_continuation();
        m_continuation = nullptr;
    }
    return {};
}
