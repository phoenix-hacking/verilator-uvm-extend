// DESCRIPTION: Verilator: process::kill unwinds through non-coroutine functions
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  class killer;
    process void_process;
    process assignment_process;
    process condition_process;
    process ref_process;
    bit after_void_kill;
    bit after_void_call;
    bit after_assignment_kill;
    bit after_assignment_call;
    bit after_condition_kill;
    bit after_condition_call;
    bit after_ref_kill;
    bit after_ref_call;
    int assignment_side_effect = 1;
    bit condition_side_effect;
    int ref_side_effect = 1;

    function void kill_from_void_function();
      void_process = process::self();
      void_process.kill();
      after_void_kill = 1'b1;
    endfunction

    function int kill_from_assignment_function();
      assignment_process = process::self();
      assignment_process.kill();
      after_assignment_kill = 1'b1;
      return 123;
    endfunction

    function int kill_from_condition_function();
      condition_process = process::self();
      condition_process.kill();
      after_condition_kill = 1'b1;
      return 123;
    endfunction

    function void kill_with_ref(ref int value);
      ref_process = process::self();
      value = 2;
      ref_process.kill();
      after_ref_kill = 1'b1;
    endfunction

    task automatic run_void_function();
      kill_from_void_function();
      after_void_call = 1'b1;
    endtask

    task automatic run_assignment_function();
      assignment_side_effect = kill_from_assignment_function();
      after_assignment_call = 1'b1;
    endtask

    task automatic run_condition_function();
      if (kill_from_condition_function() == 0) condition_side_effect = 1'b1;
      after_condition_call = 1'b1;
    endtask

    task automatic run_ref_function();
      kill_with_ref(ref_side_effect);
      after_ref_call = 1'b1;
    endtask
  endclass

  initial begin
    killer object;
    object = new;
    fork
      object.run_void_function();
      object.run_assignment_function();
      object.run_condition_function();
      object.run_ref_function();
    join_none

    #1;

    if (object.void_process == null || object.assignment_process == null
        || object.condition_process == null || object.ref_process == null) $stop;
    `checkd(object.after_void_kill, 0)
    `checkd(object.after_void_call, 0)
    `checkd(object.after_assignment_kill, 0)
    `checkd(object.after_assignment_call, 0)
    `checkd(object.after_condition_kill, 0)
    `checkd(object.after_condition_call, 0)
    `checkd(object.after_ref_kill, 0)
    `checkd(object.after_ref_call, 0)
    `checkd(object.assignment_side_effect, 1)
    `checkd(object.condition_side_effect, 0)
    `checkd(object.ref_side_effect, 2)
    `checkd(object.void_process.status(), process::KILLED)
    `checkd(object.assignment_process.status(), process::KILLED)
    `checkd(object.condition_process.status(), process::KILLED)
    `checkd(object.ref_process.status(), process::KILLED)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #20 $stop;  // timeout
endmodule
