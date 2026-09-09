//
// DESCRIPTION: Verilator: Verilog Multiple Model Test Module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2022 Geza Lore
// SPDX-License-Identifier: CC0-1.0
//

#include "verilated.h"
#include "verilated_profiler.h"

#include VM_PREFIX_INCLUDE

#include <memory>
#include <thread>

int main(int argc, char** argv) {
    srand48(5);

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    // VL_USE_THREADS define is set in t_gantt_two.py
    contextp->threads(TEST_USE_THREADS);
    contextp->debug(0);
    contextp->commandArgs(argc, argv);

    std::unique_ptr<VM_PREFIX> topap{new VM_PREFIX{contextp.get(), "topa"}};
    std::unique_ptr<VM_PREFIX> topbp{new VM_PREFIX{contextp.get(), "topb"}};

    topap->clk = false;
    topap->eval();
    topbp->clk = false;
    topbp->eval();

    contextp->timeInc(10);
    while ((contextp->time() < 1100) && !contextp->gotFinish()) {
        topap->clk = !topap->clk;
        topap->eval();
        topbp->clk = !topbp->clk;
        topbp->eval();
        contextp->timeInc(5);
    }
    if (!contextp->gotFinish()) {
        vl_fatal(__FILE__, __LINE__, "main", "%Error: Timeout; never got a $finish");
    }
    // Dump the existing profile while a different context is current. The report
    // must retain its owner's settings and must not create a pool in either context.
    VlExecutionProfiler* const profilerp = static_cast<VlExecutionProfiler*>(
        contextp->enableExecutionProfiler(&VlExecutionProfiler::construct));
    const std::string filename = contextp->profExecFilename() + ".context";
    std::thread reporter{[&]() {
        VerilatedContext otherContext;
        otherContext.threads(2);
        otherContext.profExecStart(99);
        otherContext.profExecWindow(99);
        profilerp->dump(filename.c_str(), VL_CPU_TICK());
        // This is rejected if dumping incorrectly initialized otherContext's pool.
        otherContext.threads(1);
        Verilated::threadContextp(contextp.get());
    }};
    reporter.join();
    return 0;
}
