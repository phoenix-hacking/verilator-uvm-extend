// DESCRIPTION: Verilator: Constraint foreach indices have implicit iteration drivers
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off DECLFILENAME

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class foreach_base;
  rand int values[];
  constraint values_c {
    values.size() == 3;
    foreach (values[index]) values[index] == index + 1;
  }
endclass

class foreach_derived extends foreach_base;
  rand int matrix[2][3];
  rand int descending[3:1];
  constraint arrays_c {
    foreach (matrix[row, column]) matrix[row][column] == row * 10 + column;
    foreach (descending[index]) descending[index] == index * 3;
  }
endclass

class foreach_inline;
  rand int queue_values[$];
  constraint size_c {queue_values.size() == 3;}
endclass

module t;
  foreach_derived item;
  foreach_inline inline_item;
  initial begin
    int result;
    item = new();
    result = item.randomize();
    `checkd(result, 1)
    foreach (item.values[index]) `checkd(item.values[index], index + 1)
    foreach (item.matrix[row, column]) `checkd(item.matrix[row][column], row * 10 + column)
    foreach (item.descending[index]) `checkd(item.descending[index], index * 3)
    inline_item = new();
    result = inline_item.randomize() with {
      foreach (queue_values[index]) queue_values[index] == index + 7;
    };
    `checkd(result, 1)
    foreach (inline_item.queue_values[index]) `checkd(inline_item.queue_values[index], index + 7)
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
