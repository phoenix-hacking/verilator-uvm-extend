// DESCRIPTION: Verilator: Named activation runtime registry driver
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include "verilated.h"
#include "verilated_timing.h"

#include VM_PREFIX_INCLUDE

#include <cstdio>
#include <memory>
#include <string>

#ifndef TEST_USE_THREADS
#define TEST_USE_THREADS 1
#endif

static VlCoroutine observeCancellation(VlForkSync& forkSync, VlNamedActivationRegistry& registry,
                                       const VlProcessRef& ownerp,
                                       VlNamedActivationGuard& reentrantGuard,
                                       VlNamedActivationToken outerToken,
                                       VlNamedActivationToken innerToken, VlProcessRef firstp,
                                       VlProcessRef secondp, VlProcessRef descendantp,
                                       int& callbackCount, bool& aggregateStateSeen) {
    co_await forkSync.join(nullptr);
    ++callbackCount;
    aggregateStateSeen
        = outerToken.canceled() && innerToken.canceled() && firstp->state() == VlProcess::KILLED
          && secondp->state() == VlProcess::KILLED && descendantp->state() == VlProcess::KILLED;
    reentrantGuard = registry.activate(ownerp);
}

static bool checkNamedActivationRuntime() {
    const auto fail = [](const char* const step) {
        std::fprintf(stderr, "%%Error: named activation runtime failed at %s\n", step);
        return false;
    };
    VlProcess* const initialCurrentp = VlProcess::currentp();

    // Normal lexical exit unregisters immediately.  A later disable is a no-op even while a
    // join_none-style child remains live in the ordinary process forest.
    VlNamedActivationRegistry completedRegistry;
    VlProcessRef completedOwnerp = std::make_shared<VlProcess>();
    completedOwnerp->srandom(0x1234U);
    const std::string completedOwnerRandstate = completedOwnerp->randstate();
    VlProcessRef completedChildp;
    VlNamedActivationToken completedToken;
    {
        VlNamedActivationGuard completedGuard = completedRegistry.activate(completedOwnerp);
        completedToken = completedGuard.token();
        completedChildp = VlProcess::createChild(completedOwnerp);
        completedChildp->state(VlProcess::WAITING);
        if (completedRegistry.size() != 1 || completedToken.canceled()) {
            return fail("normal activation entry");
        }
    }
    if (completedRegistry.size() != 0 || completedToken.canceled()) {
        return fail("normal activation leave");
    }
    completedRegistry.disableAll();
    if (completedChildp->state() != VlProcess::WAITING || completedToken.canceled()
        || completedOwnerp->state() != VlProcess::RUNNING
        || completedOwnerp->randstate() != completedOwnerRandstate) {
        return fail("late disable no-op");
    }
    completedChildp->state(VlProcess::KILLED);

    // Registry operations preserve the executing source process identity, status, and RNG.
    VlNamedActivationRegistry contextRegistry;
    VlProcessRef contextOwnerp = std::make_shared<VlProcess>();
    contextOwnerp->srandom(0x2468U);
    const std::string contextRandstate = contextOwnerp->randstate();
    {
        VlProcessContext context{contextOwnerp.get()};
        VlNamedActivationGuard contextGuard = contextRegistry.activate(contextOwnerp);
        contextRegistry.disableAll();
        if (VlProcess::currentp() != contextOwnerp.get() || !contextGuard.canceled()
            || contextOwnerp->state() != VlProcess::RUNNING
            || contextOwnerp->randstate() != contextRandstate) {
            return fail("source process identity and RNG");
        }
    }
    if (VlProcess::currentp() != initialCurrentp) return fail("source process context restore");

    // If an outer guard exits before a moved inner guard, both directions of the weak
    // containment edge are removed immediately.
    VlNamedActivationRegistry parentExitRegistry;
    VlNamedActivationRegistry survivingInnerRegistry;
    VlProcessRef parentExitOwnerp = std::make_shared<VlProcess>();
    VlNamedActivationGuard survivingInner;
    {
        VlNamedActivationGuard parent = parentExitRegistry.activate(parentExitOwnerp);
        survivingInner = survivingInnerRegistry.activate(parentExitOwnerp);
        const VlNamedActivationStats innerStats = survivingInnerRegistry.stats();
        if (innerStats.m_parentActivations != 1 || innerStats.m_processMembers != 1
            || innerStats.m_globalProcessMapEntries != 1
            || innerStats.m_globalProcessMemberships != 2) {
            return fail("live parent activation edge");
        }
    }
    const VlNamedActivationStats survivingInnerStats = survivingInnerRegistry.stats();
    if (parentExitRegistry.size() != 0 || survivingInnerStats.m_activations != 1
        || survivingInnerStats.m_parentActivations != 0
        || survivingInnerStats.m_processMembers != 1
        || survivingInnerStats.m_globalProcessMapEntries != 1
        || survivingInnerStats.m_globalProcessMemberships != 1) {
        return fail("parent activation edge cleanup");
    }
    survivingInner = VlNamedActivationGuard{};
    if (survivingInnerRegistry.size() != 0
        || survivingInnerRegistry.stats().m_globalProcessMapEntries != 0) {
        return fail("moved inner activation cleanup");
    }

    // Terminal process memberships and normally returned nested activations are removed while
    // their outer activation remains live.  Cardinalities must stay bounded across repeated use.
    VlNamedActivationRegistry cleanupRegistry;
    VlNamedActivationRegistry cleanupInnerRegistry;
    VlProcessRef cleanupOwnerp = std::make_shared<VlProcess>();
    VlNamedActivationGuard cleanupOuter = cleanupRegistry.activate(cleanupOwnerp);
    const auto cleanupAtBaseline = [&cleanupRegistry]() {
        const VlNamedActivationStats stats = cleanupRegistry.stats();
        return stats.m_activations == 1 && stats.m_parentActivations == 0
               && stats.m_childActivations == 0 && stats.m_processMembers == 1
               && stats.m_childProcesses == 0 && stats.m_globalProcessMapEntries == 1
               && stats.m_globalProcessMemberships == 1;
    };
    if (!cleanupAtBaseline()) return fail("cleanup baseline");
    for (int i = 0; i < 256; ++i) {
        VlProcessRef childp = VlProcess::createChild(cleanupOwnerp);
        const VlNamedActivationStats liveStats = cleanupRegistry.stats();
        if (liveStats.m_processMembers != 2 || liveStats.m_childProcesses != 1
            || liveStats.m_globalProcessMapEntries != 2
            || liveStats.m_globalProcessMemberships != 2) {
            return fail("live child tracking");
        }
        childp->state(VlProcess::FINISHED);
        childp.reset();
        if (!cleanupAtBaseline()) return fail("terminal child cleanup");
    }
    for (int i = 0; i < 256; ++i) {
        {
            VlNamedActivationGuard inner = cleanupInnerRegistry.activate(cleanupOwnerp);
            const VlNamedActivationStats liveStats = cleanupRegistry.stats();
            const VlNamedActivationStats innerStats = cleanupInnerRegistry.stats();
            if (liveStats.m_childActivations != 1 || innerStats.m_parentActivations != 1
                || liveStats.m_globalProcessMapEntries != 1
                || liveStats.m_globalProcessMemberships != 2) {
                return fail("live nested activation tracking");
            }
        }
        if (!cleanupAtBaseline() || cleanupInnerRegistry.size() != 0) {
            return fail("nested activation cleanup");
        }
    }
    VlNamedActivationGuard cleanupInner = cleanupInnerRegistry.activate(cleanupOwnerp);
    VlProcessRef cleanupFinishedp = VlProcess::createChild(cleanupOwnerp);
    VlProcessRef cleanupChildp = VlProcess::createChild(cleanupFinishedp);
    cleanupChildp->state(VlProcess::WAITING);
    cleanupFinishedp->state(VlProcess::FINISHED);
    const VlNamedActivationStats retainedDescendantStats = cleanupRegistry.stats();
    if (retainedDescendantStats.m_processMembers != 2
        || retainedDescendantStats.m_childProcesses != 1
        || retainedDescendantStats.m_globalProcessMapEntries != 2
        || retainedDescendantStats.m_globalProcessMemberships != 4) {
        return fail("live descendant tracking");
    }
    cleanupRegistry.disableAll();
    const VlNamedActivationStats cleanupAfterDisable = cleanupRegistry.stats();
    if (!cleanupOuter.canceled() || !cleanupInner.canceled()
        || cleanupFinishedp->state() != VlProcess::FINISHED
        || cleanupChildp->state() != VlProcess::KILLED || cleanupRegistry.size() != 0
        || cleanupInnerRegistry.size() != 0 || cleanupAfterDisable.m_activations != 0
        || cleanupAfterDisable.m_parentActivations != 0
        || cleanupAfterDisable.m_childActivations != 0 || cleanupAfterDisable.m_processMembers != 0
        || cleanupAfterDisable.m_childProcesses != 0
        || cleanupAfterDisable.m_globalProcessMapEntries != 0
        || cleanupAfterDisable.m_globalProcessMemberships != 0) {
        return fail("live state after bounded cleanup");
    }

    // Every recursive/concurrent record in one declaration registry is drained together, while
    // source owners remain alive and retain their RNG state.
    VlNamedActivationRegistry batchRegistry;
    VlProcessRef recursiveOwnerp = std::make_shared<VlProcess>();
    VlProcessRef concurrentOwnerp = std::make_shared<VlProcess>();
    recursiveOwnerp->srandom(0x5678U);
    const std::string recursiveRandstate = recursiveOwnerp->randstate();
    VlNamedActivationGuard recursiveOuter = batchRegistry.activate(recursiveOwnerp);
    VlNamedActivationGuard recursiveInner = batchRegistry.activate(recursiveOwnerp);
    VlNamedActivationGuard concurrent = batchRegistry.activate(concurrentOwnerp);
    VlProcessRef recursiveChildp = VlProcess::createChild(recursiveOwnerp);
    VlProcessRef concurrentChildp = VlProcess::createChild(concurrentOwnerp);
    recursiveChildp->state(VlProcess::WAITING);
    concurrentChildp->state(VlProcess::WAITING);
    if (batchRegistry.size() != 3) return fail("recursive/concurrent entry count");
    batchRegistry.disableAll();
    if (!recursiveOuter.canceled() || !recursiveInner.canceled() || !concurrent.canceled()
        || batchRegistry.size() != 0 || recursiveChildp->state() != VlProcess::KILLED
        || concurrentChildp->state() != VlProcess::KILLED
        || recursiveOwnerp->state() != VlProcess::RUNNING
        || concurrentOwnerp->state() != VlProcess::RUNNING
        || recursiveOwnerp->randstate() != recursiveRandstate) {
        return fail("recursive/concurrent cancellation");
    }

    // An outer named activation owns dynamically nested named activations even when the inner
    // declaration uses a different registry.
    VlNamedActivationRegistry outerRegistry;
    VlNamedActivationRegistry innerRegistry;
    VlProcessRef nestedOwnerp = std::make_shared<VlProcess>();
    VlNamedActivationGuard outerGuard = outerRegistry.activate(nestedOwnerp);
    VlNamedActivationGuard innerGuard = innerRegistry.activate(nestedOwnerp);
    VlProcessRef nestedChildp = VlProcess::createChild(nestedOwnerp);
    nestedChildp->state(VlProcess::WAITING);
    outerRegistry.disableAll();
    if (!outerGuard.canceled() || !innerGuard.canceled() || outerRegistry.size() != 0
        || innerRegistry.size() != 0 || nestedChildp->state() != VlProcess::KILLED
        || nestedOwnerp->state() != VlProcess::RUNNING) {
        return fail("nested activation containment");
    }

    // Unrelated declaration registries and source processes remain isolated.
    VlNamedActivationRegistry firstRegistry;
    VlNamedActivationRegistry secondRegistry;
    VlProcessRef firstOwnerp = std::make_shared<VlProcess>();
    VlProcessRef secondOwnerp = std::make_shared<VlProcess>();
    VlNamedActivationGuard firstGuard = firstRegistry.activate(firstOwnerp);
    VlNamedActivationGuard secondGuard = secondRegistry.activate(secondOwnerp);
    VlProcessRef firstChildp = VlProcess::createChild(firstOwnerp);
    VlProcessRef secondChildp = VlProcess::createChild(secondOwnerp);
    firstChildp->state(VlProcess::WAITING);
    secondChildp->state(VlProcess::WAITING);
    firstRegistry.disableAll();
    if (!firstGuard.canceled() || secondGuard.canceled() || firstRegistry.size() != 0
        || secondRegistry.size() != 1 || firstChildp->state() != VlProcess::KILLED
        || secondChildp->state() != VlProcess::WAITING) {
        return fail("registry isolation");
    }
    secondRegistry.disableAll();
    if (!secondGuard.canceled() || secondRegistry.size() != 0
        || secondChildp->state() != VlProcess::KILLED) {
        return fail("isolated registry drain");
    }

    // The registry swaps generations and marks every token and process before callbacks.  A
    // callback may reenter the same declaration; the new activation survives the old drain.
    VlNamedActivationRegistry callbackRegistry;
    VlNamedActivationRegistry callbackInnerRegistry;
    VlProcessRef callbackOwnerp = std::make_shared<VlProcess>();
    VlNamedActivationGuard callbackGuard = callbackRegistry.activate(callbackOwnerp);
    VlNamedActivationGuard callbackInnerGuard = callbackInnerRegistry.activate(callbackOwnerp);
    const VlNamedActivationToken callbackToken = callbackGuard.token();
    const VlNamedActivationToken callbackInnerToken = callbackInnerGuard.token();
    VlProcessRef callbackFirstp = VlProcess::createChild(callbackOwnerp);
    VlProcessRef callbackSecondp = VlProcess::createChild(callbackOwnerp);
    VlProcessRef callbackDescendantp = VlProcess::createChild(callbackFirstp);
    callbackFirstp->state(VlProcess::WAITING);
    callbackSecondp->state(VlProcess::WAITING);
    callbackDescendantp->state(VlProcess::WAITING);
    int callbackCount = 0;
    bool aggregateStateSeen = false;
    VlNamedActivationGuard reentrantGuard;
    {
        VlForkSync callbackSync;
        callbackSync.init(1, nullptr);
        VlCoroutine callbackObserver = observeCancellation(
            callbackSync, callbackRegistry, callbackOwnerp, reentrantGuard, callbackToken,
            callbackInnerToken, callbackFirstp, callbackSecondp, callbackDescendantp,
            callbackCount, aggregateStateSeen);
        callbackSync.onKill(callbackFirstp);
        callbackRegistry.disableAll();
    }
    if (callbackCount != 1 || !aggregateStateSeen || !callbackGuard.canceled()
        || !callbackInnerGuard.canceled() || reentrantGuard.canceled()
        || callbackRegistry.size() != 1 || callbackInnerRegistry.size() != 0) {
        return fail("generation swap and callback order");
    }
    callbackRegistry.disableAll();
    if (callbackCount != 1 || !reentrantGuard.canceled() || callbackRegistry.size() != 0) {
        return fail("reentrant generation drain");
    }
    if (VlProcess::currentp() != initialCurrentp) return fail("source process context");

    return true;
}

int main(int argc, char** argv) {
    if (!checkNamedActivationRuntime()) return 10;

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->threads(TEST_USE_THREADS);
    contextp->commandArgs(argc, argv);
    const std::unique_ptr<VM_PREFIX> topp{new VM_PREFIX{contextp.get()}};
    while (!contextp->gotFinish()) {
        topp->eval();
        if (contextp->gotFinish()) break;
        if (!topp->eventsPending()) {
            VL_FATAL_MT(__FILE__, __LINE__, "main", "No event before $finish");
        }
        contextp->time(topp->nextTimeSlot());
    }
    std::printf("NAMED_ACTIVATION_RUNTIME_SENTINEL pass=1\n");
    std::printf("*-* All Finished *-*\n");
    return 0;
}
