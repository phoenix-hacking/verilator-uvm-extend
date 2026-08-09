// DESCRIPTION: Verilator: Named sequential blocks preserve outward control flow
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  int return_after;
  int loop_body;
  int loop_tail;
  int helper_after;
  int outer_after;

  task automatic disable_outer();
    disable outer_task;
    helper_after++;
  endtask

  task automatic outer_task();
    disable_outer();
    outer_after++;
  endtask

  task automatic outward_return();
    begin : return_target
      return;
    end
    // The unreachable reference still makes return_target disable-addressable.
    disable return_target;
    return_after++;
  endtask

  initial begin
    // Process/token propagation is also required for a timing-free helper chain under
    // explicit --no-timing.
    outer_task();
    `checkd(helper_after, 0)
    `checkd(outer_after, 0)

    outward_return();
    `checkd(return_after, 0)

    for (int i = 0; i < 4; i++) begin
      begin : loop_target
        if (i == 0) continue;
        if (i == 2) break;
        loop_body++;
      end
      // A completed sequential block is inactive, so this is a no-op.
      disable loop_target;
      loop_tail++;
    end
    `checkd(loop_body, 1)
    `checkd(loop_tail, 1)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
