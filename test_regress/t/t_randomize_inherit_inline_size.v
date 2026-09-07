// DESCRIPTION: Verilator: Inherited array size constraints survive inline randomization
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off DECLFILENAME

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class array_base;
  rand int values[];
  constraint values_c {
    values.size() == 3;
    foreach (values[index]) values[index] == index + 1;
  }
endclass

class array_derived extends array_base;
  rand int tag;
endclass

class inline_arrays;
  rand bit [6:0] values[];
  rand bit [6:0] queue_values[$];
  rand bit [4:0] length;
endclass

module t;
  array_derived item;
  inline_arrays inline_item;
  initial begin
    int result;
    int sizes[5];
    sizes = '{3, 1, 7, 0, 5};
    item = new();
    result = item.randomize() with {tag == 11;};
    `checkd(result, 1)
    `checkd(item.values.size(), 3)
    foreach (item.values[index]) `checkd(item.values[index], index + 1)
    `checkd(item.tag, 11)
    result = item.randomize() with {tag == 12;};
    `checkd(result, 1)
    `checkd(item.values.size(), 3)
    foreach (item.values[index]) `checkd(item.values[index], index + 1)
    `checkd(item.tag, 12)
    inline_item = new();
    foreach (sizes[iteration]) begin
      int requested;
      requested = sizes[iteration];
      result = inline_item.randomize() with {
        int'(length) == requested;
        values.size() == int'(length);
        queue_values.size() == int'(length) + 1;
        foreach (values[index]) values[index] == 7'(index + requested);
        foreach (queue_values[index]) queue_values[index] == 7'(index + requested + 9);
      };
      `checkd(result, 1)
      `checkd(int'(inline_item.length), requested)
      `checkd(inline_item.values.size(), requested)
      `checkd(inline_item.queue_values.size(), requested + 1)
      foreach (inline_item.values[index])
        `checkd(int'(inline_item.values[index]), index + requested)
      foreach (inline_item.queue_values[index])
        `checkd(int'(inline_item.queue_values[index]), index + requested + 9)
    end
    // A second call site must reuse size variables while still resizing arrays.
    result = inline_item.randomize() with {
      length == 2;
      values.size() == 2;
      queue_values.size() == 1;
      foreach (values[index]) values[index] == 7'(index + 31);
      queue_values[0] == 51;
    };
    `checkd(result, 1)
    `checkd(inline_item.values.size(), 2)
    `checkd(inline_item.queue_values.size(), 1)
    foreach (inline_item.values[index]) `checkd(int'(inline_item.values[index]), index + 31)
    `checkd(int'(inline_item.queue_values[0]), 51)
    result = inline_item.randomize() with {
      values.size() == 2;
      values.size() == 3;
    };
    `checkd(result, 0)
    `checkd(inline_item.values.size(), 2)
    `checkd(inline_item.queue_values.size(), 1)
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
