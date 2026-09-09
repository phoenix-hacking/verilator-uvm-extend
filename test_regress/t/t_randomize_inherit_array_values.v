// DESCRIPTION: Verilator: Inherited dynamic arrays obey element constraints on first randomize
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
endclass

class queue_base;
  typedef bit [6:0] element_t;
  rand element_t values[$];
  int requested;
  constraint values_c {
    values.size() == requested;
    foreach (values[index]) values[index] == 7'(index + requested);
  }
endclass

class queue_middle extends queue_base;
endclass

class queue_derived extends queue_middle;
endclass

module t;
  array_derived item;
  queue_base base_item;
  queue_derived derived_item;
  initial begin
    int result;
    int sizes[5];
    sizes = '{3, 1, 7, 0, 5};
    item = new();
    repeat (5) begin
      result = item.randomize();
      `checkd(result, 1)
      `checkd(item.values.size(), 3)
      foreach (item.values[index]) `checkd(item.values[index], index + 1)
    end
    base_item = new();
    derived_item = new();
    foreach (sizes[iteration]) begin
      base_item.requested = sizes[iteration];
      derived_item.requested = sizes[iteration];
      result = base_item.randomize();
      `checkd(result, 1)
      result = derived_item.randomize();
      `checkd(result, 1)
      `checkd(base_item.values.size(), sizes[iteration])
      `checkd(derived_item.values.size(), sizes[iteration])
      foreach (base_item.values[index])
        `checkd(int'(base_item.values[index]), index + sizes[iteration])
      foreach (derived_item.values[index])
        `checkd(int'(derived_item.values[index]), index + sizes[iteration])
    end
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
