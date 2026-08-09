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
  process parent_process;
  process child_process;
  process waiting_process;
  bit after_wait_zero;
  bit after_child_join;
  bit after_parent_join;

  task automatic wait_forever();
    waiting_process = process::self();
    wait (0);
    after_wait_zero = 1'b1;
  endtask

  task automatic run_child();
    child_process = process::self();
    fork
      wait_forever();
    join

    after_child_join = 1'b1;
  endtask

  task automatic run_parent();
    parent_process = process::self();
    fork
      run_child();
    join

    after_parent_join = 1'b1;
  endtask

  initial begin
    // This initial process remains outside the killed tree and therefore owns
    // both the kill request and the post-kill checks.
    fork
      run_parent();
    join_none

    wait (parent_process != null);
    wait (child_process != null);
    wait (waiting_process != null);
    #1;

    `checkd(waiting_process.status(), process::WAITING)

    parent_process.kill();
    parent_process.await();
    #1;

    `checkd(after_wait_zero, 0)
    `checkd(after_child_join, 0)
    `checkd(after_parent_join, 0)
    `checkd(parent_process.status(), process::KILLED)
    `checkd(child_process.status(), process::KILLED)
    `checkd(waiting_process.status(), process::KILLED)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #20 $stop;  // timeout
endmodule
