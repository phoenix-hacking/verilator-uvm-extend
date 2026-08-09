// DESCRIPTION: Verilator: Self-kill persists across always_comb triggers
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  logic trigger = 1'b0;
  int entry_marker;
  bit fell_through;
  process killed_process;
  process first_killed_process;
  process::state status_before_kill;

  always_comb begin : killed_comb
    process current_process;

    current_process = process::self();
    entry_marker = trigger ? 2 : 1;
    killed_process = current_process;
    status_before_kill = current_process.status();
    current_process.kill();
    fell_through = 1'b1;
  end

  initial begin
    #1;
    `checkd(entry_marker, 1)
    `checkd(killed_process == null, 0)
    `checkd(status_before_kill, process::RUNNING)
    `checkd(killed_process.status(), process::KILLED)
    first_killed_process = killed_process;

    // A killed always_comb process must not be recreated for a later input event.
    trigger = 1'b1;
    #1;
    `checkd(entry_marker, 1)
    `checkd(killed_process == first_killed_process, 1)
    `checkd(killed_process.status(), process::KILLED)
    `checkd(fell_through, 0)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #10 `stop;
endmodule
