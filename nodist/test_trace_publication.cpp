// DESCRIPTION: Verilator: Verify parallel trace publication and work item lifetime
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

#include "verilated.h"
#include "verilated_vcd_c.h"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <memory>
#include <pthread.h>
#include <string>
#include <thread>

// Hold the completion mutex at its unlock, after the callback has written its
// buffer. Publishing ready before this point lets dump destroy a locked mutex.
static thread_local bool t_holdUnlock = false;
static std::atomic<bool> s_workerBlocked{false};
static std::atomic<bool> s_releaseWorker{false};
static std::atomic<bool> s_dumpReturned{false};

extern "C" int __real_pthread_mutex_unlock(pthread_mutex_t* mutexp);
extern "C" int __wrap_pthread_mutex_unlock(pthread_mutex_t* mutexp) {
    if (t_holdUnlock) {
        t_holdUnlock = false;
        s_workerBlocked.store(true, std::memory_order_release);
        while (!s_releaseWorker.load(std::memory_order_acquire)) std::this_thread::yield();
    }
    return __real_pthread_mutex_unlock(mutexp);
}

// Supply the same configuration interface as a generated model, so the test
// runs the actual VCD buffer allocation, worker dispatch, wait and commit code.
class TraceModel final : public VerilatedModel {
public:
    explicit TraceModel(VerilatedContext& context)
        : VerilatedModel{context} {
        context.addModel(this);
    }
    const char* hierName() const override { return "top"; }
    const char* modelName() const override { return "TraceModel"; }
    unsigned threads() const override { return 2; }
    std::unique_ptr<VerilatedTraceConfig> traceConfig() const override {
        return std::unique_ptr<VerilatedTraceConfig>{new VerilatedTraceConfig{true}};
    }
};

struct TraceData final {
    const char* const m_namep;
    const bool m_slow;
    const bool m_holdUnlock;
    uint32_t m_code = 0;
    uint32_t m_value = 0;
};

static void initialize(void* userp, VerilatedVcd* tracep, uint32_t code) {
    TraceData* const datap = static_cast<TraceData*>(userp);
    datap->m_code = code;
    tracep->declBus(code, datap->m_namep, 31, 0);
}

static void record(void* userp, VerilatedVcd::Buffer* bufp) {
    TraceData* const datap = static_cast<TraceData*>(userp);
    if (datap->m_slow) std::this_thread::sleep_for(std::chrono::milliseconds{1});
    ++datap->m_value;
    bufp->fullIData(bufp->oldp(datap->m_code), datap->m_value, 32);
    t_holdUnlock = datap->m_holdUnlock;
}

int main(int argc, char** argv) {
    if (argc != 3) return 2;
    const std::string mode = argv[1];
    const bool holdUnlock = mode == "unlock";
    const bool slow = mode == "slow";
    if (!holdUnlock && !slow && mode != "fast") return 2;
    const uint32_t samples = holdUnlock ? 1 : slow ? 10 : 1000;

    VerilatedContext context;
    context.threads(2);
    context.useNumaAssign(false);
    context.traceEverOn(true);
    TraceModel model{context};
    TraceData mainData{"main_value", false, false};
    TraceData workerData{"worker_value", slow, holdUnlock};
    VerilatedVcd trace;
    trace.addModel(&model);
    for (const auto& item : {std::make_pair(&mainData, 0U), std::make_pair(&workerData, 1U)}) {
        trace.addInitCb(initialize, item.first, item.first->m_namep, false, 1);
        trace.addFullCb(record, item.second, item.first);
        trace.addChgCb(record, item.second, item.first);
    }
    trace.open(argv[2]);

    bool observedBlock = false;
    bool prematureReturn = false;
    std::thread controller;
    if (holdUnlock) {
        controller = std::thread{[&]() {
            const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds{2};
            while (!s_workerBlocked.load(std::memory_order_acquire)
                   && std::chrono::steady_clock::now() < deadline) {
                std::this_thread::yield();
            }
            observedBlock = s_workerBlocked.load(std::memory_order_acquire);
            const auto releaseTime
                = std::chrono::steady_clock::now() + std::chrono::milliseconds{100};
            while (!s_dumpReturned.load(std::memory_order_acquire)
                   && std::chrono::steady_clock::now() < releaseTime) {
                std::this_thread::yield();
            }
            prematureReturn = s_dumpReturned.load(std::memory_order_acquire);
            s_releaseWorker.store(true, std::memory_order_release);
        }};
    }
    bool incorrectValue = false;
    for (uint32_t i = 0; i < samples; ++i) {
        trace.dump(i);
        s_dumpReturned.store(true, std::memory_order_release);
        incorrectValue |= mainData.m_value != i + 1 || workerData.m_value != i + 1;
    }
    if (controller.joinable()) controller.join();
    trace.close();
    if (incorrectValue || (holdUnlock && (!observedBlock || prematureReturn))) {
        std::fprintf(stderr, "Trace publication failed: values=%d blocked=%d premature=%d\n",
                     incorrectValue, observedBlock, prematureReturn);
        return 1;
    }
    std::printf("Trace publication %s passed: %u samples per signal\n", mode.c_str(), samples);
    return 0;
}
