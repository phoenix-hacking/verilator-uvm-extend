// DESCRIPTION: Verilator: Preserve nested constraints after independent randomization
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off DECLFILENAME

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class reused_child;
  rand bit [6:0] value;
  int requested;
  int pre_count;
  int post_count;
  constraint value_c {int'(value) == requested;}
  function void pre_randomize();
    pre_count++;
  endfunction
  function void post_randomize();
    post_count++;
  endfunction
endclass

class reused_parent extends reused_child;
  rand reused_child child;
  constraint child_c {child.value == value;}
  function new();
    child = new();
  endfunction
endclass

class inline_child;
  rand bit [6:0] value;
  int requested;
  int pre_count;
  int post_count;
  constraint value_c {int'(value) == requested;}
  function void pre_randomize();
    pre_count++;
  endfunction
  function void post_randomize();
    post_count++;
  endfunction
endclass

class inline_parent;
  rand inline_child child;
  constraint child_c {child.value == 5;}
endclass

module t;
  initial begin
    reused_child item;
    reused_parent parent_item;
    inline_child arg_item;
    inline_parent arg_parent;
    int result;

    // Both standalone and inline uses precede a call on a containing object.
    item = new();
    item.requested = 7;
    result = item.randomize();
    `checkd(result, 1)
    `checkd(int'(item.value), 7)
    result = item.randomize() with {value == 7;};
    `checkd(result, 1)
    `checkd(item.pre_count, 2)
    `checkd(item.post_count, 2)

    parent_item = new();
    parent_item.requested = 5;
    parent_item.child.requested = 6;
    result = parent_item.randomize();
    `checkd(result, 0)
    `checkd(parent_item.pre_count, 1)
    `checkd(parent_item.post_count, 0)
    `checkd(parent_item.child.pre_count, 1)
    `checkd(parent_item.child.post_count, 0)
    parent_item.child.requested = 5;
    result = parent_item.randomize();
    `checkd(result, 1)
    `checkd(int'(parent_item.value), 5)
    `checkd(int'(parent_item.child.value), 5)
    `checkd(parent_item.pre_count, 2)
    `checkd(parent_item.post_count, 1)
    `checkd(parent_item.child.pre_count, 2)
    `checkd(parent_item.child.post_count, 1)
    parent_item.child.requested = 6;
    result = parent_item.randomize() with {value == 5;};
    `checkd(result, 0)
    `checkd(parent_item.pre_count, 3)
    `checkd(parent_item.post_count, 1)
    `checkd(parent_item.child.pre_count, 3)
    `checkd(parent_item.child.post_count, 1)

    // Explicit variable arguments also mark a class before its first nested use.
    arg_item = new();
    arg_item.requested = 7;
    result = arg_item.randomize(value);
    `checkd(result, 1)
    `checkd(int'(arg_item.value), 7)
    `checkd(arg_item.pre_count, 1)
    `checkd(arg_item.post_count, 1)
    arg_parent = new();
    arg_parent.child = arg_item;
    arg_item.requested = 6;
    result = arg_parent.randomize();
    `checkd(result, 0)
    `checkd(arg_item.pre_count, 2)
    `checkd(arg_item.post_count, 1)
    arg_item.requested = 5;
    result = arg_parent.randomize();
    `checkd(result, 1)
    `checkd(int'(arg_item.value), 5)
    `checkd(arg_item.pre_count, 3)
    `checkd(arg_item.post_count, 2)
    arg_item.value.rand_mode(0);
    arg_item.requested = 6;
    result = arg_parent.randomize();
    `checkd(result, 0)
    `checkd(int'(arg_item.value), 5)
    `checkd(arg_item.pre_count, 4)
    `checkd(arg_item.post_count, 2)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
