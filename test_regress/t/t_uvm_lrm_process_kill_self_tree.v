// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  process ancestor_process;
  process child_process;
  process descendant_process;
  bit after_kill;
  bit after_descendant_task;
  bit after_child_join;

  task automatic kill_ancestor_from_descendant(input process target_process);
    descendant_process = process::self();
    #1;
    target_process.kill();

    // A process that kills itself through an ancestor handle is part of the
    // disabled process tree. It must not execute beyond process::kill().
    after_kill = 1'b1;
  endtask

  task automatic run_child(input process target_process);
    child_process = process::self();
    fork
      kill_ancestor_from_descendant(target_process);
    join

    after_descendant_task = 1'b1;
  endtask

  task automatic run_ancestor();
    ancestor_process = process::self();
    fork
      run_child(ancestor_process);
    join

    after_child_join = 1'b1;
  endtask

  initial begin
    fork
      run_ancestor();
    join_none

    wait (ancestor_process != null);
    wait (child_process != null);
    wait (descendant_process != null);
    #2;

    `checkd(after_kill, 0)
    `checkd(after_descendant_task, 0)
    `checkd(after_child_join, 0)
    `checkd(ancestor_process.status(), process::KILLED)
    `checkd(child_process.status(), process::KILLED)
    `checkd(descendant_process.status(), process::KILLED)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #20 $stop;  // timeout
endmodule
