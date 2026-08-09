// DESCRIPTION: Verilator: Process tree ownership and terminal release driver
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

static VlCoroutine observeKillCallback(VlForkSync& forkSync, VlProcessRef firstp,
                                       VlProcessRef secondp, VlProcessRef descendantp,
                                       bool& callbackSeen, bool& allKilled) {
    co_await forkSync.join(nullptr);
    callbackSeen = true;
    allKilled = firstp->state() == VlProcess::KILLED && secondp->state() == VlProcess::KILLED
                && descendantp->state() == VlProcess::KILLED;
}

static bool checkProcessTree() {
    const auto fail = [](const char* const step) {
        std::fprintf(stderr, "%%Error: process tree ownership failed at %s\n", step);
        return false;
    };

    // A parent must retain a wait(0)-style child after its coroutine frame releases the only
    // generated local handle.  Killing the child releases both directions without a cycle.
    VlProcessRef parentp = std::make_shared<VlProcess>();
    VlProcessRef childp = VlProcess::createChild(parentp);
    const std::weak_ptr<VlProcess> weakChildp = childp;
    childp->state(VlProcess::WAITING);
    childp.reset();
    if (weakChildp.expired() || parentp->completedFork()) return fail("waiting child retention");
    if (const VlProcessRef retainedp = weakChildp.lock()) retainedp->state(VlProcess::KILLED);
    if (!weakChildp.expired() || !parentp->completedFork()) return fail("waiting child release");

    // wait fork observes immediate child completion, while ownership retains the finished child
    // until a live descendant completes.  This distinguishes process-tree lifetime from wait-fork
    // completion semantics.
    VlProcessRef secondParentp = std::make_shared<VlProcess>();
    VlProcessRef secondChildp = VlProcess::createChild(secondParentp);
    VlProcessRef grandchildp = VlProcess::createChild(secondChildp);
    const std::weak_ptr<VlProcess> weakSecondChildp = secondChildp;
    const std::weak_ptr<VlProcess> weakGrandchildp = grandchildp;
    grandchildp->state(VlProcess::WAITING);
    secondChildp->state(VlProcess::FINISHED);
    secondChildp.reset();
    grandchildp.reset();
    if (!secondParentp->completedFork() || weakSecondChildp.expired()
        || weakGrandchildp.expired()) {
        return fail("finished ancestor retention");
    }
    if (const VlProcessRef retainedp = weakGrandchildp.lock()) {
        retainedp->state(VlProcess::FINISHED);
    }
    if (!weakSecondChildp.expired() || !weakGrandchildp.expired()) {
        return fail("bottom-up tree release");
    }

    // disable fork must traverse a FINISHED immediate child to reach a live descendant.  The
    // immediate child already counts as complete for wait fork, but its retained subtree remains
    // part of recursive disable.
    VlProcessRef finishedParentp = std::make_shared<VlProcess>();
    VlProcessRef finishedChildp = VlProcess::createChild(finishedParentp);
    VlProcessRef waitingGrandchildp = VlProcess::createChild(finishedChildp);
    const std::weak_ptr<VlProcess> weakFinishedChildp = finishedChildp;
    const std::weak_ptr<VlProcess> weakWaitingGrandchildp = waitingGrandchildp;
    waitingGrandchildp->state(VlProcess::WAITING);
    finishedChildp->state(VlProcess::FINISHED);
    finishedChildp.reset();
    if (!finishedParentp->completedFork() || weakFinishedChildp.expired()
        || weakWaitingGrandchildp.expired()) {
        return fail("finished disable ancestor retention");
    }
    finishedParentp->disableFork();
    if (!weakFinishedChildp.expired() || waitingGrandchildp->state() != VlProcess::KILLED
        || !finishedParentp->completedFork()) {
        return fail("disable through finished ancestor");
    }
    waitingGrandchildp.reset();
    if (!weakWaitingGrandchildp.expired()) return fail("disabled grandchild release");

    // disable fork recursively marks and releases every descendant before returning.
    VlProcessRef thirdParentp = std::make_shared<VlProcess>();
    VlProcessRef thirdChildp = VlProcess::createChild(thirdParentp);
    VlProcessRef thirdGrandchildp = VlProcess::createChild(thirdChildp);
    const std::weak_ptr<VlProcess> weakThirdChildp = thirdChildp;
    const std::weak_ptr<VlProcess> weakThirdGrandchildp = thirdGrandchildp;
    thirdChildp.reset();
    thirdGrandchildp.reset();
    thirdParentp->disableFork();
    if (!weakThirdChildp.expired() || !weakThirdGrandchildp.expired()
        || !thirdParentp->completedFork()) {
        return fail("recursive disable release");
    }

    // All targets must be terminal before the first kill callback resumes generated code.
    VlProcessRef callbackParentp = std::make_shared<VlProcess>();
    VlProcessRef callbackFirstp = VlProcess::createChild(callbackParentp);
    VlProcessRef callbackSecondp = VlProcess::createChild(callbackParentp);
    VlProcessRef callbackDescendantp = VlProcess::createChild(callbackFirstp);
    bool callbackSeen = false;
    bool allKilled = false;
    {
        VlForkSync callbackSync;
        callbackSync.init(1, nullptr);
        VlCoroutine callbackObserver
            = observeKillCallback(callbackSync, callbackFirstp, callbackSecondp,
                                  callbackDescendantp, callbackSeen, allKilled);
        callbackSync.onKill(callbackFirstp);
        callbackParentp->disableFork();
    }
    if (!callbackSeen || !allKilled) return fail("mark all before kill callback");

    // A branch killed before its fork-sync hook is installed must contribute exactly one
    // completion.  A two-count join distinguishes one notification from zero or multiple.
    VlProcessRef killedBeforeHookp = std::make_shared<VlProcess>();
    killedBeforeHookp->state(VlProcess::KILLED);
    VlForkSync forkSync;
    forkSync.onKill(killedBeforeHookp);
    forkSync.init(2, nullptr);
    auto forkJoinBeforeDone = forkSync.join(nullptr);
    if (forkJoinBeforeDone.await_ready()) return fail("duplicate late kill-hook notification");
    forkSync.done();
    auto forkJoinAfterDone = forkSync.join(nullptr);
    if (!forkJoinAfterDone.await_ready()) return fail("missing late kill-hook notification");

    const std::weak_ptr<VlProcess> weakParentp = parentp;
    const std::weak_ptr<VlProcess> weakSecondParentp = secondParentp;
    const std::weak_ptr<VlProcess> weakThirdParentp = thirdParentp;
    const std::weak_ptr<VlProcess> weakFinishedParentp = finishedParentp;
    const std::weak_ptr<VlProcess> weakCallbackParentp = callbackParentp;
    parentp.reset();
    secondParentp.reset();
    thirdParentp.reset();
    finishedParentp.reset();
    callbackFirstp.reset();
    callbackSecondp.reset();
    callbackDescendantp.reset();
    callbackParentp.reset();
    if (!weakParentp.expired() || !weakSecondParentp.expired() || !weakThirdParentp.expired()
        || !weakFinishedParentp.expired() || !weakCallbackParentp.expired()) {
        return fail("root release");
    }
    return true;
}

int main(int argc, char** argv) {
    if (!checkProcessTree()) return 10;

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
    std::printf("PROCESS_TREE_OWNERSHIP_SENTINEL pass=1\n");
    std::printf("*-* All Finished *-*\n");
    return 0;
}
