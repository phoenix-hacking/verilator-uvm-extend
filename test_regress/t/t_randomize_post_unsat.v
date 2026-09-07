// DESCRIPTION: Verilator: Failed randomization skips post callbacks and permits recovery
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off DECLFILENAME

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class callback_base;
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

class callback_derived extends callback_base;
  int derived_post;
  function void post_randomize();
    derived_post++;
    super.post_randomize();
  endfunction
endclass

class callback_child;
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

class callback_parent extends callback_base;
  rand callback_child child;
  constraint child_c {child.value == value;}
  function new();
    child = new();
  endfunction
endclass

class callback_array extends callback_base;
  rand bit [6:0] data[];
  int element_requested;
  constraint data_c {
    data.size() == 3;
    foreach (data[i]) int'(data[i]) == element_requested;
  }
endclass

module t;
  initial begin
    callback_base item;
    callback_derived derived_item;
    callback_parent parent_item;
    callback_array array_item;
    int result;

    item = new();
    item.requested = 200;
    result = item.randomize();
    `checkd(result, 0)
    `checkd(item.pre_count, 1)
    `checkd(item.post_count, 0)
    item.requested = 7;
    result = item.randomize();
    `checkd(result, 1)
    `checkd(item.pre_count, 2)
    `checkd(item.post_count, 1)
    `checkd(int'(item.value), 7)

    item.value.rand_mode(0);
    item.requested = 8;
    result = item.randomize();
    `checkd(result, 0)
    `checkd(item.pre_count, 3)
    `checkd(item.post_count, 1)
    `checkd(int'(item.value), 7)
    item.value.rand_mode(1);

    result = item.randomize() with {value == 9;};
    `checkd(result, 0)
    `checkd(item.pre_count, 4)
    `checkd(item.post_count, 1)
    result = item.randomize() with {value == 8;};
    `checkd(result, 1)
    `checkd(item.pre_count, 5)
    `checkd(item.post_count, 2)

    // An inline call through a base handle must guard the virtual callback.
    derived_item = new();
    item = derived_item;
    item.requested = 3;
    result = item.randomize() with {value == 4;};
    `checkd(result, 0)
    `checkd(item.pre_count, 1)
    `checkd(item.post_count, 0)
    `checkd(derived_item.derived_post, 0)
    result = item.randomize() with {value == 3;};
    `checkd(result, 1)
    `checkd(item.pre_count, 2)
    `checkd(item.post_count, 1)
    `checkd(derived_item.derived_post, 1)

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
    `checkd(parent_item.pre_count, 2)
    `checkd(parent_item.post_count, 1)
    `checkd(parent_item.child.pre_count, 2)
    `checkd(parent_item.child.post_count, 1)
    result = parent_item.randomize() with {value == 6;};
    `checkd(result, 0)
    `checkd(parent_item.pre_count, 3)
    `checkd(parent_item.post_count, 1)
    `checkd(parent_item.child.pre_count, 3)
    `checkd(parent_item.child.post_count, 1)

    // Element constraints can fail after an initially empty array is sized.
    array_item = new();
    array_item.requested = 4;
    array_item.element_requested = 200;
    result = array_item.randomize();
    `checkd(result, 0)
    `checkd(array_item.pre_count, 1)
    `checkd(array_item.post_count, 0)
    array_item.element_requested = 17;
    result = array_item.randomize();
    `checkd(result, 1)
    `checkd(array_item.pre_count, 2)
    `checkd(array_item.post_count, 1)
    `checkd(array_item.data.size(), 3)
    foreach (array_item.data[i]) `checkd(int'(array_item.data[i]), 17)

    array_item.data.delete();
    array_item.element_requested = 200;
    result = array_item.randomize() with {value == 4;};
    `checkd(result, 0)
    `checkd(array_item.pre_count, 3)
    `checkd(array_item.post_count, 1)
    array_item.element_requested = 19;
    result = array_item.randomize() with {value == 4;};
    `checkd(result, 1)
    `checkd(array_item.pre_count, 4)
    `checkd(array_item.post_count, 2)
    `checkd(array_item.data.size(), 3)
    foreach (array_item.data[i]) `checkd(int'(array_item.data[i]), 19)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
