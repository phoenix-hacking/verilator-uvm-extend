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

class reused_top;
  rand reused_parent nested;
  function new();
    nested = new();
  endfunction
endclass

class static_child extends reused_child;
  static constraint limit_c {value < 64;}
endclass

class static_parent;
  rand static_child child;
  function new();
    child = new();
  endfunction
endclass

module t;
  int mode_calls;
  function bit disable_mode();
    mode_calls++;
    return 0;
  endfunction

  initial begin
    reused_child item;
    reused_parent parent_item;
    inline_child arg_item;
    inline_parent arg_parent;
    reused_parent other_parent;
    reused_top top_item;
    static_child static_item;
    static_parent static_container;
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

    // A cloned constraint reads the mode of its original object. Parent and
    // child share a base type here, but must retain independent mode values.
    other_parent = new();
    for (int request_value = 1; request_value <= 8; ++request_value) begin
      parent_item.constraint_mode(1);
      parent_item.requested = request_value;
      parent_item.child.requested = request_value + 1;
      parent_item.child.value_c.constraint_mode(0);
      result = parent_item.randomize();
      `checkd(result, 1)
      `checkd(int'(parent_item.value), request_value)
      `checkd(int'(parent_item.child.value), request_value)
      `checkd(parent_item.value_c.constraint_mode(), 1)
      `checkd(parent_item.child.value_c.constraint_mode(), 0)

      parent_item.child.value_c.constraint_mode(1);
      result = parent_item.randomize();
      `checkd(result, 0)
      parent_item.value_c.constraint_mode(0);
      result = parent_item.randomize();
      `checkd(result, 1)
      `checkd(int'(parent_item.value), request_value + 1)
      `checkd(int'(parent_item.child.value), request_value + 1)

      // Disabling all constraints on the parent must not disable the child's.
      parent_item.constraint_mode(0);
      result = parent_item.randomize() with {int'(child.value) == local:: request_value;};
      `checkd(result, 0)
      parent_item.child.constraint_mode(0);
      result = parent_item.randomize() with {int'(child.value) == local:: request_value;};
      `checkd(result, 1)
      `checkd(int'(parent_item.child.value), request_value)

      // A second instance keeps its own enabled constraint modes.
      other_parent.requested = request_value;
      other_parent.child.requested = request_value + 1;
      result = other_parent.randomize();
      `checkd(result, 0)
    end

    // Flattening a previously flattened parent must retain the entire path to
    // the original constraint's mode, including inherited child constraints.
    top_item = new();
    top_item.nested.requested = 11;
    top_item.nested.child.requested = 12;
    top_item.nested.child.value_c.constraint_mode(0);
    result = top_item.randomize();
    `checkd(result, 1)
    `checkd(int'(top_item.nested.value), 11)
    `checkd(int'(top_item.nested.child.value), 11)
    top_item.nested.child.value_c.constraint_mode(1);
    result = top_item.randomize();
    `checkd(result, 0)
    // A class with only nested constraints has no local mode slots. Its setter
    // still evaluates the argument once and leaves the nested modes enabled.
    top_item.constraint_mode(disable_mode());
    `checkd(mode_calls, 1)
    result = top_item.randomize();
    `checkd(result, 0)
    parent_item.constraint_mode(1);
    parent_item.constraint_mode(disable_mode());
    `checkd(mode_calls, 2)
    `checkd(parent_item.value_c.constraint_mode(), 0)
    `checkd(parent_item.child_c.constraint_mode(), 0)

    // Static constraint modes retain the original class's shared storage.
    static_item = new();
    static_container = new();
    static_container.child.requested = 65;
    static_item.limit_c.constraint_mode(1);
    result = static_container.randomize();
    `checkd(result, 0)
    static_item.limit_c.constraint_mode(0);
    result = static_container.randomize();
    `checkd(result, 1)
    `checkd(int'(static_container.child.value), 65)
    static_container.child.limit_c.constraint_mode(1);
    `checkd(static_item.limit_c.constraint_mode(), 1)
    result = static_container.randomize() with {child.value == 65;};
    `checkd(result, 0)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
