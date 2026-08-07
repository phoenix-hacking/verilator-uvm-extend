// DESCRIPTION: Verilator: Self-kill isolation between initial processes
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

class rng_owner;
  rand int value;
endclass

module t;
  process killed_process;
  process finished_process;
  bit killed_process_started;
  bit killed_process_fell_through;
  bit finished_process_ran;
  bit initial_context_restored;
  string finished_process_randstate;

  initial begin
    killed_process = process::self();
    killed_process_started = 1'b1;
    killed_process.kill();
    killed_process_fell_through = 1'b1;
  end

  initial begin
    finished_process = process::self();
    finished_process.srandom(42);
    finished_process_randstate = finished_process.get_randstate();
    finished_process_ran = 1'b1;
  end

  initial begin
    rng_owner object;

    wait (killed_process_started && finished_process_ran);
    #0;
    object = new;
    initial_context_restored
        = finished_process.get_randstate() == finished_process_randstate;
    $finish;
  end

  final begin
    `checkd(killed_process_started, 1)
    `checkd(killed_process_fell_through, 0)
    `checkd(finished_process_ran, 1)
    `checkd(killed_process == null, 0)
    `checkd(finished_process == null, 0)
    `checkd(killed_process == finished_process, 0)
    `checkd(killed_process.status(), process::KILLED)
    `checkd(finished_process.status(), process::FINISHED)
    `checkd(initial_context_restored, 1)
    $write("*-* All Finished *-*\n");
  end

  initial #100 `stop;
endmodule
