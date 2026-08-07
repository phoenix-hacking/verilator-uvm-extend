// DESCRIPTION: Verilator: Process tree ownership and terminal release
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  bit waiter_started;
  bit wait_fork_returned;

  task automatic spawn_detached_waiter();
    fork
      begin
        waiter_started = 1'b1;
        // The task returns after join_none, so its local fork state no longer owns this process.
        // verilator lint_off WAITCONST
        wait (0);
        // verilator lint_on WAITCONST
      end
    join_none
  endtask

  initial begin
    fork
      begin
        spawn_detached_waiter();
        wait (waiter_started);
        #1;
        wait fork;
        wait_fork_returned = 1'b1;
      end
    join_none

    #10;
    `checkd(waiter_started, 1)
    `checkd(wait_fork_returned, 0)
    $finish;
  end
endmodule
