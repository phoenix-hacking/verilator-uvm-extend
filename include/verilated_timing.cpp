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

}  // namespace

//======================================================================
// VlCoroutineHandle:: Methods

void VlCoroutineHandle::resume() {
    // Only null if we have a fork..join_any and one of the other child processes resumed the
    // main process
    const std::coroutine_handle<> coro = std::exchange(m_coro, nullptr);
    if (VL_LIKELY(coro)) {
        const VlProcessRef process = m_process;
        VL_DEBUG_IF(VL_DBG_MSGF("             Resuming: "); dump(););
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
    }
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
    bool resumed = false;

    while (!m_queue.empty() && (m_queue.cbegin()->first == m_context.time())) {
        VlCoroutineHandle handle = std::move(m_queue.begin()->second);
        m_queue.erase(m_queue.begin());
        handle.resume();
        resumed = true;
    }

    if (!resumed) {
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
    if (!m_queue.empty()) return m_queue.cbegin()->first;
    if (m_zeroDelayed.empty())
        VL_FATAL_MT(__FILE__, __LINE__, "", "There is no next time slot scheduled");
    return m_context.time();
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
                                       std::vector<std::shared_ptr<VlForkSyncState>>& forkSyncps) {
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
