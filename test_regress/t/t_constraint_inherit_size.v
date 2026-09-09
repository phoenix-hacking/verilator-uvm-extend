// DESCRIPTION: Verilator: Prepare inherited array size constraints before inline lowering
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off DECLFILENAME

class size_base;
  rand int values[];
  constraint values_c {values.size() == 3;}
endclass

class size_middle extends size_base;
  typedef bit [6:0] element_t;
  rand element_t queue_values[$];
  constraint queue_c {queue_values.size() == 5;}
endclass

class size_derived extends size_middle;
  rand int tag;
endclass

module t;
  size_derived item;
  initial begin
    int result;
    item = new();
    result = item.randomize() with {tag == 11;};
    $display("result=%0d values=%p queue=%p tag=%0d", result, item.values, item.queue_values,
             item.tag);
    $finish;
  end
endmodule
