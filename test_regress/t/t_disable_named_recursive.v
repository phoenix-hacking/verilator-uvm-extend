// DESCRIPTION: Verilator: Recursive named-task dynamic activations
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  int entered;
  int after_wait;
  event release_task;

  task automatic recursive_task(input int depth);
    entered++;
    if (depth != 0) begin
      recursive_task(depth - 1);
    end else begin
      @release_task;
    end
    after_wait++;
  endtask

  initial begin
    fork
      recursive_task(3);
      begin
        wait (entered == 4);
        #1;
        disable recursive_task;
      end
    join

    `checkd(entered, 4)
    `checkd(after_wait, 0)
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
