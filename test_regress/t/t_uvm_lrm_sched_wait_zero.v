// DESCRIPTION: Verilator: Constant-false wait blocks through nested class tasks
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  bit caller_returned = 0;

  class waiter;
    task inner();
      // A constant-false wait must suspend this process permanently, including
      // when lowered from inside nested class-task call frames.
      // verilator lint_off WAITCONST
      wait (0);
      // verilator lint_on WAITCONST
      $write("WAIT_ZERO_RETURNED\n");
    endtask

    task outer();
      inner();
      caller_returned = 1;
      $write("WAIT_ZERO_RETURNED\n");
    endtask
  endclass

  initial begin
    waiter object;
    object = new;
    fork
      object.outer();
    join_none

    #10;
    if (caller_returned) $stop;
    $write("WAIT_ZERO_BLOCKED\n");
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
