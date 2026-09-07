// DESCRIPTION: Verilator: Sized storage indices in constraint foreach loops
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class constrained_bounds;
  rand bit [6:0] descending[3:1];
  rand bit [6:0] ascending[-3:-1];
  rand bit [6:0] zero_based[0:2];
  bit [6:0] requested;
  constraint values_c {
    foreach (descending[i]) int'(descending[i]) == int'(requested) + i;
    foreach (ascending[i]) int'(ascending[i]) == int'(requested) + i;
    foreach (zero_based[i]) int'(zero_based[i]) == int'(requested) + i;
  }
endclass

module t;
  initial begin
    constrained_bounds item;
    int result;
    item = new();
    for (int epoch = 0; epoch < 8; epoch++) begin
      item.requested = 7'(epoch + 19);
      result = item.randomize();
      `checkd(result, 1)
      foreach (item.descending[i]) begin
        `checkd(int'(item.descending[i]), int'(item.requested) + i)
      end
      foreach (item.ascending[i]) begin
        `checkd(int'(item.ascending[i]), int'(item.requested) + i)
      end
      foreach (item.zero_based[i]) begin
        `checkd(int'(item.zero_based[i]), int'(item.requested) + i)
      end
    end
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
