// DESCRIPTION: Verilator: Explicit constraint dereferences still reject null handles
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

class explicit_child;
  rand bit [6:0] value;
  constraint value_c {value == 7;}
endclass

class explicit_parent;
  rand explicit_child child;
`ifndef EXPLICIT_INLINE
  constraint child_c {child.value == 7;}
`endif
endclass

`ifdef NESTED_EXPLICIT
class explicit_outer;
  rand explicit_parent parent_item;
  function new();
    parent_item = new();
  endfunction
endclass
`endif

module t;
  initial begin
`ifdef NESTED_EXPLICIT
    explicit_outer parent_item;
`else
    explicit_parent parent_item;
`endif
    int result;
    parent_item = new();
`ifdef EXPLICIT_INLINE
    result = parent_item.randomize() with {child.value == 7;};
`else
    result = parent_item.randomize();
`endif
    $display("Unexpected completion: randomize returned %0d", result);
    $finish;
  end
endmodule
