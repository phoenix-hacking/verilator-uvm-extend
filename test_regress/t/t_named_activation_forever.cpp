// DESCRIPTION: Verilator: Named activation constant-false wait lifecycle driver
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include "verilated.h"
#include "verilated_timing.h"

#include VM_PREFIX_INCLUDE

#include <cstdio>
#include <memory>

#ifndef TEST_USE_THREADS
#define TEST_USE_THREADS 1
#endif

namespace {

struct LockingDestructionProbe final {
    VlNamedActivationRegistry& m_registry;
    int& m_count;

    LockingDestructionProbe(VlNamedActivationRegistry& registry, int& count)
        : m_registry{registry}
        , m_count{count} {}
    ~LockingDestructionProbe() {
        // stats() takes the process mutex.  Any caller destroying this frame while holding that
        // mutex deadlocks the regression instead of silently accepting the invalid lock order.
        (void)m_registry.stats();
        ++m_count;
    }
};

VlCoroutine waitInNamedActivation(VlNamedActivationRegistry& registry, VlProcessRef processp,
                                  int& resumeCount, bool& canceledSeen, int& destructionCount) {
    LockingDestructionProbe probe{registry, destructionCount};
    VlNamedActivationGuard guard = registry.activate(processp);
    const VlNamedActivationToken token = guard.token();
    co_await VlForever{processp};
    ++resumeCount;
    canceledSeen = token.canceled();
}

VlCoroutine waitInDetachedChild(VlNamedActivationRegistry& registry, VlProcessRef processp,
                                int& resumeCount, int& destructionCount) {
    LockingDestructionProbe probe{registry, destructionCount};
    co_await VlForever{processp};
    ++resumeCount;
}

VlCoroutine waitThroughNestedDetachedChild(VlNamedActivationRegistry& registry,
                                           VlProcessRef processp, int& resumeCount,
                                           int& destructionCount) {
    co_await waitInDetachedChild(registry, processp, resumeCount, destructionCount);
    ++resumeCount;
}

VlCoroutine waitSchedulerEvent(VlDelayScheduler& scheduler, VlProcessRef processp,
                               int& resumeCount) {
    co_await scheduler.delay(1, processp);
    ++resumeCount;
}

VlCoroutine awaitStoredForever(VlCoroutine& waiter, int& continuationCount) {
    co_await waiter;
    ++continuationCount;
}

bool checkNamedActivationForever() {
    const auto fail = [](const char* const step) {
        std::fprintf(stderr, "%%Error: named activation forever failed at %s\n", step);
        return false;
    };

    // An active sequential target at wait(0) keeps its frame and activation record.  Named disable
    // consumes the suspension once and resumes the surviving source process with cancellation set.
    {
        VerilatedContext schedulerContext;
        VlDelayScheduler scheduler{schedulerContext};
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        int resumeCount = 0;
        int destructionCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter
            = waitInNamedActivation(registry, ownerp, resumeCount, canceledSeen, destructionCount);
        const VlNamedActivationStats waitingStats = registry.stats();
        if (registry.size() != 1 || waitingStats.m_suspensions != 1
            || ownerp->state() != VlProcess::WAITING || resumeCount != 0
            || destructionCount != 0) {
            return fail("active wait registration");
        }
        registry.disableAll();
        // A cancellation-only forever state must not manufacture a live scheduler event.
        if (registry.size() != 0 || registry.stats().m_suspensions != 0 || resumeCount != 1
            || !canceledSeen || destructionCount != 1 || ownerp->state() != VlProcess::RUNNING
            || !scheduler.empty() || scheduler.awaitingCurrentTime()
            || scheduler.awaitingZeroDelay()) {
            return fail("active wait cancellation resume");
        }
        int eventResumeCount = 0;
        VlCoroutine event
            = waitSchedulerEvent(scheduler, std::make_shared<VlProcess>(), eventResumeCount);
        if (scheduler.empty() || scheduler.nextTimeSlot() != 1) {
            return fail("live event after forever cancellation");
        }
        schedulerContext.time(1);
        scheduler.resume();
        if (eventResumeCount != 1 || !scheduler.empty()) {
            return fail("scheduler liveness after forever cancellation");
        }
        registry.disableAll();
        if (resumeCount != 1 || destructionCount != 1) {
            return fail("late disable after canceled completion");
        }
    }

    // A join_none child suspended in wait(0) through a nested VlCoroutine call outlives normal
    // exit of the activation that spawned it.  Its generated frames may be discarded, but the
    // WAITING process remains in the semantic tree, so wait fork still sees it.  Every returned
    // VlCoroutine remains forever-suspended, and a later named disable is a no-op.
    {
        VlNamedActivationRegistry registry;
        const VlProcessRef parentp = std::make_shared<VlProcess>();
        VlNamedActivationGuard enclosingGuard = registry.activate(parentp);
        const VlProcessRef childp = VlProcess::createChild(parentp);
        int resumeCount = 0;
        int destructionCount = 0;
        VlCoroutine waiter
            = waitThroughNestedDetachedChild(registry, childp, resumeCount, destructionCount);
        if (registry.stats().m_suspensions != 1 || childp->state() != VlProcess::WAITING
            || parentp->completedFork()) {
            return fail("detached wait registration");
        }
        enclosingGuard = VlNamedActivationGuard{};
        if (registry.size() != 0 || registry.stats().m_suspensions != 0
            || childp->state() != VlProcess::WAITING || parentp->completedFork()
            || resumeCount != 0 || destructionCount != 1) {
            return fail("detached wait survives normal exit");
        }
        int continuationCount = 0;
        VlCoroutine continuation = awaitStoredForever(waiter, continuationCount);
        if (continuationCount != 0) return fail("detached wait remains forever suspended");
        registry.disableAll();
        if (childp->state() != VlProcess::WAITING || parentp->completedFork() || resumeCount != 0
            || destructionCount != 1) {
            return fail("late named disable no-op");
        }
        childp->disable();
        childp->disable();
        if (childp->state() != VlProcess::KILLED || !parentp->completedFork() || resumeCount != 0
            || destructionCount != 1) {
            return fail("detached wait explicit kill");
        }
    }

    // A descendant disable after outer scope exit kills a sibling suspended forever inside a
    // nested activation.  The killed process's frame must be consumed exactly once, even though
    // normal outer exit already released its own suspension association.
    {
        VlNamedActivationRegistry outerRegistry;
        VlNamedActivationRegistry innerRegistry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard outerGuard = outerRegistry.activate(ownerp);
        const VlNamedActivationToken outerToken = outerGuard.token();
        const VlProcessRef disablerp = VlProcess::createChild(ownerp);
        const VlProcessRef waiterp = VlProcess::createChild(ownerp);
        int resumeCount = 0;
        int destructionCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter = waitInNamedActivation(innerRegistry, waiterp, resumeCount,
                                                   canceledSeen, destructionCount);
        if (outerRegistry.stats().m_suspensions != 1 || innerRegistry.size() != 1
            || waiterp->state() != VlProcess::WAITING || destructionCount != 0) {
            return fail("nested detached wait registration");
        }
        outerGuard = VlNamedActivationGuard{};
        if (outerRegistry.size() != 0 || innerRegistry.size() != 1
            || waiterp->state() != VlProcess::WAITING || destructionCount != 0) {
            return fail("nested detached wait survives outer exit");
        }
        {
            VlProcessContext disablerContext{disablerp.get()};
            outerRegistry.disableAll();
        }
        if (!outerToken.canceled() || disablerp->state() != VlProcess::KILLED
            || waiterp->state() != VlProcess::KILLED || ownerp->state() != VlProcess::RUNNING
            || innerRegistry.size() != 0 || resumeCount != 0 || canceledSeen
            || destructionCount != 1) {
            return fail("nested detached wait descendant disable");
        }
    }

    // Direct process kill of an activation-owned wait consumes and destroys the forever frame
    // outside the process mutex.  The guarded frame destructor takes that mutex, and repeated kill
    // or later named disable must neither resume nor destroy the frame twice.
    {
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        int resumeCount = 0;
        int destructionCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter
            = waitInNamedActivation(registry, ownerp, resumeCount, canceledSeen, destructionCount);
        ownerp->disable();
        if (ownerp->state() != VlProcess::KILLED || registry.size() != 0 || resumeCount != 0
            || canceledSeen || destructionCount != 1) {
            return fail("direct kill frame destruction");
        }
        ownerp->disable();
        registry.disableAll();
        if (resumeCount != 0 || canceledSeen || destructionCount != 1) {
            return fail("direct kill one-shot");
        }
    }

    return true;
}

}  // namespace

int main(int argc, char** argv) {
    if (!checkNamedActivationForever()) return 10;

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->threads(TEST_USE_THREADS);
    contextp->commandArgs(argc, argv);
    const std::unique_ptr<VM_PREFIX> topp{new VM_PREFIX{contextp.get()}};
    while (!contextp->gotFinish()) {
        topp->eval();
        if (contextp->gotFinish()) break;
        if (!topp->eventsPending()) return 11;
        contextp->time(topp->nextTimeSlot());
    }

    std::printf("NAMED_ACTIVATION_FOREVER_SENTINEL pass=1 threads=%u\n", contextp->threads());
    return 0;
}
