// DESCRIPTION: Verilator: Restore parent process context after a fork branch suspends
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
  process parent_process;
  process child_process;
  bit child_ready;
  string child_before_object;

  initial begin
    parent_process = process::self();
    parent_process.srandom(100);
    fork
      begin
        child_process = process::self();
        child_process.srandom(200);
        child_before_object = child_process.get_randstate();
        child_ready = 1'b1;
        #10;
      end
      begin
        rng_owner object;

        // Creating this sibling process and its object must consume the parent and sibling RNG
        // streams, not the first child's stream left at its suspension point.
        wait (child_ready);
        object = new;
      end
    join

    `checkd(child_process == null, 0)
    `checkd(child_process.get_randstate() == child_before_object, 1)
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
