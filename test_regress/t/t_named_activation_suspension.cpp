// DESCRIPTION: Verilator: Named activation cancellation-aware scheduler suspension driver
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

struct DestructionProbe final {
    bool& m_destroyed;
    explicit DestructionProbe(bool& destroyed)
        : m_destroyed{destroyed} {}
    ~DestructionProbe() { m_destroyed = true; }
};

VlCoroutine waitDelay(VlDelayScheduler& scheduler, uint64_t delay, VlProcessRef processp,
                      VlNamedActivationToken token, int& resumeCount, bool& canceledSeen) {
    co_await scheduler.delay(delay, processp);
    ++resumeCount;
    canceledSeen = token.canceled();
}

VlCoroutine waitTrigger(VlTriggerScheduler& scheduler, bool ready, VlProcessRef processp,
                        VlNamedActivationToken token, int& resumeCount, bool& canceledSeen) {
    co_await scheduler.trigger(ready, processp);
    ++resumeCount;
    canceledSeen = token.canceled();
}

enum class DynamicPhase : uint8_t { EVALUATION, POST_UPDATE, RESUMPTION };

VlCoroutine waitDynamic(VlDynamicTriggerScheduler& scheduler, DynamicPhase phase,
                        VlProcessRef processp, VlNamedActivationToken token, int& resumeCount,
                        bool& canceledSeen) {
    switch (phase) {
    case DynamicPhase::EVALUATION:
        co_await scheduler.evaluation(processp, "evaluation", __FILE__, __LINE__);
        break;
    case DynamicPhase::POST_UPDATE:
        co_await scheduler.postUpdate(processp, "post update", __FILE__, __LINE__);
        break;
    case DynamicPhase::RESUMPTION:
        co_await scheduler.resumption(processp, "resumption", __FILE__, __LINE__);
        break;
    }
    ++resumeCount;
    canceledSeen = token.canceled();
}

VlCoroutine waitKilledChild(VlDelayScheduler& scheduler, VlProcessRef processp,
                            bool& frameDestroyed) {
    DestructionProbe probe{frameDestroyed};
    co_await scheduler.delay(100, processp);
}

VlCoroutine waitJoin(VlForkSync& forkSync, VlProcessRef processp, VlNamedActivationToken token,
                     const bool& childFrameDestroyed, int& resumeCount, bool& orderSeen,
                     bool& canceledSeen) {
    co_await forkSync.join(processp);
    ++resumeCount;
    orderSeen = childFrameDestroyed;
    canceledSeen = token.canceled();
}

bool checkNamedActivationSuspension() {
    const auto fail = [](const char* const step) {
        std::fprintf(stderr, "%%Error: named activation suspension failed at %s\n", step);
        return false;
    };

    // Non-zero and #0 delays are resumed once by cancellation, then leave scheduler tombstones.
    {
        VerilatedContext context;
        VlDelayScheduler scheduler{context};
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard guard = registry.activate(ownerp);
        const VlNamedActivationToken token = guard.token();
        int resumeCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter = waitDelay(scheduler, 10, ownerp, token, resumeCount, canceledSeen);
        if (registry.stats().m_suspensions != 1 || ownerp->state() != VlProcess::WAITING) {
            return fail("delayed suspension registration");
        }
        registry.disableAll();
        if (resumeCount != 1 || !canceledSeen || !guard.canceled()
            || ownerp->state() != VlProcess::RUNNING || registry.stats().m_suspensions != 0
            || !scheduler.empty()) {
            return fail("delayed cancellation");
        }
        context.time(10);
        scheduler.resume();
        if (resumeCount != 1 || !scheduler.empty()) return fail("delayed tombstone");
    }
    {
        VerilatedContext context;
        VlDelayScheduler scheduler{context};
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard guard = registry.activate(ownerp);
        int resumeCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter
            = waitDelay(scheduler, 0, ownerp, guard.token(), resumeCount, canceledSeen);
        registry.disableAll();
        if (!scheduler.empty()) return fail("zero-delay tombstone liveness");
        scheduler.resumeZeroDelay();
        if (resumeCount != 1 || !canceledSeen || !scheduler.empty()) {
            return fail("zero-delay tombstone");
        }
    }

    // A canceled overdue tombstone must not hide the next live delay, while live overdue entries
    // retain the existing missed-time-slot diagnostic.
    {
        VerilatedContext context;
        VlDelayScheduler scheduler{context};
        VlNamedActivationRegistry registry;
        const VlProcessRef canceledOwnerp = std::make_shared<VlProcess>();
        const VlProcessRef liveOwnerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard guard = registry.activate(canceledOwnerp);
        int canceledCount = 0;
        int liveCount = 0;
        bool canceledSeen = false;
        bool liveCanceledSeen = true;
        VlCoroutine canceledWaiter
            = waitDelay(scheduler, 5, canceledOwnerp, guard.token(), canceledCount, canceledSeen);
        VlCoroutine liveWaiter = waitDelay(scheduler, 6, liveOwnerp, VlNamedActivationToken{},
                                           liveCount, liveCanceledSeen);
        registry.disableAll();
        if (scheduler.nextTimeSlot() != 6) return fail("next live time slot");
        context.time(scheduler.nextTimeSlot());
        scheduler.resume();
        if (canceledCount != 1 || liveCount != 1 || !canceledSeen || liveCanceledSeen
            || !scheduler.empty()) {
            return fail("overdue tombstone pruning");
        }
    }

    // Static trigger queues retain a tombstone regardless of whether registration entered the
    // awaiting or already-fired stage.
    for (const bool ready : {false, true}) {
        VlTriggerScheduler scheduler;
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard guard = registry.activate(ownerp);
        int resumeCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter
            = waitTrigger(scheduler, ready, ownerp, guard.token(), resumeCount, canceledSeen);
        registry.disableAll();
        if (!scheduler.empty()) return fail("static trigger tombstone liveness");
        scheduler.ready();
        scheduler.moveToResumeQueue();
        scheduler.resume();
        if (resumeCount != 1 || !canceledSeen || !scheduler.empty()) {
            return fail(ready ? "fired trigger tombstone" : "static trigger tombstone");
        }
    }

    // All three dynamic-trigger suspension stages use the same cancellation one-shot state.
    for (const DynamicPhase phase :
         {DynamicPhase::EVALUATION, DynamicPhase::POST_UPDATE, DynamicPhase::RESUMPTION}) {
        VlDynamicTriggerScheduler scheduler;
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard guard = registry.activate(ownerp);
        int resumeCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter
            = waitDynamic(scheduler, phase, ownerp, guard.token(), resumeCount, canceledSeen);
        registry.disableAll();
        switch (phase) {
        case DynamicPhase::EVALUATION: scheduler.evaluate(); break;
        case DynamicPhase::POST_UPDATE: scheduler.doPostUpdates(); break;
        case DynamicPhase::RESUMPTION: scheduler.resume(); break;
        }
        if (resumeCount != 1 || !canceledSeen) return fail("dynamic trigger tombstone");
    }

    // Destroy killed child frames before fork callbacks, and deliver callbacks before resuming the
    // canceled but non-killed source owner.  The join scheduler subsequently observes a tombstone.
    {
        VerilatedContext context;
        VlDelayScheduler childScheduler{context};
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard guard = registry.activate(ownerp);
        const VlProcessRef childp = VlProcess::createChild(ownerp);
        VlForkSync forkSync;
        forkSync.init(1, ownerp);
        forkSync.onKill(childp);
        bool childFrameDestroyed = false;
        int ownerResumeCount = 0;
        bool destructionOrderSeen = false;
        bool canceledSeen = false;
        VlCoroutine childWaiter = waitKilledChild(childScheduler, childp, childFrameDestroyed);
        VlCoroutine ownerWaiter = waitJoin(forkSync, ownerp, guard.token(), childFrameDestroyed,
                                           ownerResumeCount, destructionOrderSeen, canceledSeen);
        if (registry.stats().m_suspensions != 2) return fail("fork suspension registration");
        registry.disableAll();
        if (!childFrameDestroyed || ownerResumeCount != 1 || !destructionOrderSeen || !canceledSeen
            || childp->state() != VlProcess::KILLED || ownerp->state() != VlProcess::RUNNING
            || registry.size() != 0 || registry.stats().m_suspensions != 0
            || !childScheduler.empty()) {
            return fail("killed frame callback owner order");
        }
        context.time(100);
        childScheduler.resume();
        if (ownerResumeCount != 1) return fail("fork tombstones consumed once");
    }

    // Disabling only an inner declaration cancels and wakes its suspension without canceling the
    // dynamically enclosing activation.  A shared state is nevertheless consumed only once.
    {
        VerilatedContext context;
        VlDelayScheduler scheduler{context};
        VlNamedActivationRegistry outerRegistry;
        VlNamedActivationRegistry innerRegistry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard outerGuard = outerRegistry.activate(ownerp);
        VlNamedActivationGuard innerGuard = innerRegistry.activate(ownerp);
        int resumeCount = 0;
        bool innerCanceledSeen = false;
        VlCoroutine waiter
            = waitDelay(scheduler, 20, ownerp, innerGuard.token(), resumeCount, innerCanceledSeen);
        if (outerRegistry.stats().m_suspensions != 1 || innerRegistry.stats().m_suspensions != 1) {
            return fail("nested suspension registration");
        }
        innerRegistry.disableAll();
        if (resumeCount != 1 || !innerCanceledSeen || !innerGuard.canceled()
            || outerGuard.canceled() || outerRegistry.size() != 1
            || outerRegistry.stats().m_suspensions != 0) {
            return fail("inner-only cancellation");
        }
        context.time(20);
        scheduler.resume();
        if (resumeCount != 1) return fail("nested tombstone consumed once");
    }

    // Recursive activations of one declaration all observe the same drain, but their shared
    // suspension still resumes exactly once.
    {
        VerilatedContext context;
        VlDelayScheduler scheduler{context};
        VlNamedActivationRegistry registry;
        const VlProcessRef ownerp = std::make_shared<VlProcess>();
        VlNamedActivationGuard outerGuard = registry.activate(ownerp);
        VlNamedActivationGuard innerGuard = registry.activate(ownerp);
        int resumeCount = 0;
        bool canceledSeen = false;
        VlCoroutine waiter
            = waitDelay(scheduler, 30, ownerp, innerGuard.token(), resumeCount, canceledSeen);
        registry.disableAll();
        if (resumeCount != 1 || !canceledSeen || !outerGuard.canceled() || !innerGuard.canceled()
            || registry.size() != 0) {
            return fail("recursive activation cancellation");
        }
        context.time(30);
        scheduler.resume();
        if (resumeCount != 1) return fail("recursive tombstone consumed once");
    }

    return true;
}

}  // namespace

int main(int argc, char** argv) {
    if (!checkNamedActivationSuspension()) return 10;

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

    std::printf("NAMED_ACTIVATION_SUSPENSION_SENTINEL pass=1 threads=%u\n", contextp->threads());
    return 0;
}
