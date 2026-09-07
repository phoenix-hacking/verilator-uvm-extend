// DESCRIPTION: Verilator: Randomize nullable and replaced child handles
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class nullable_child;
  typedef enum bit [6:0] {
    IDLE = 3,
    BUSY = 17,
    DONE = 65
  } state_t;
  rand bit [6:0] value;
  rand bit [64:0] wide;
  rand state_t state;
  rand bit [6:0] fixed_data[3:1];
  rand bit [6:0] dynamic_data[];
  bit [6:0] requested;
  int pre_count;
  int post_count;
  constraint value_c {
    value == requested;
    wide == {58'b0, requested};
    state != DONE;
    foreach (fixed_data[i]) fixed_data[i] == value;
    foreach (dynamic_data[i]) dynamic_data[i] == value;
  }
  function new();
    dynamic_data = new[2];
  endfunction
  function void pre_randomize();
    pre_count++;
  endfunction
  function void post_randomize();
    post_count++;
  endfunction
endclass

typedef nullable_child child_alias_t;

class nullable_parent;
  rand child_alias_t child;
  rand bit [6:0] value;
  bit [6:0] requested;
  constraint value_c {value == requested;}
endclass

`ifndef NULL_CHILD_REPRO
class nullable_derived extends nullable_parent;
  rand nullable_child other;
endclass

class nullable_top;
  rand nullable_parent parent_item;
  rand bit marker;
  constraint marker_c {marker == 1;}
endclass

class callback_parent extends nullable_parent;
  child_alias_t next_child;
  function void pre_randomize();
    child = next_child;
  endfunction
endclass

class plain_child;
  rand bit [6:0] value;
  constraint value_c {value == 7;}
endclass

class plain_parent;
  rand plain_child child;
endclass

class static_child;
  rand bit [6:0] value;
  static constraint value_c {value == 9;}
endclass

class static_parent;
  rand static_child child;
endclass
`endif

`ifdef NULL_CHILD_REPRO
module t;
  initial begin
    nullable_child child;
    nullable_parent parent_item;
    int result;
    child = new();
    child.requested = 7;
    child.value_c.constraint_mode(1);
    parent_item = new();
    parent_item.requested = 11;
    result = parent_item.randomize();
    `checkd(result, 1)
    `checkd(parent_item.child == null, 1)
    `checkd(parent_item.value, 11)
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
`else
module t;
  initial begin
    nullable_child first;
    nullable_child second;
    nullable_derived parent_item;
    nullable_top top_item;
    callback_parent callback_item;
    plain_parent plain_item;
    static_parent static_item;
    static_child mode_item;
    int result;
    int old_pre;
    int old_post;

    // The original crash: a child constraint's mode exists, but the handle does not.
    first = new();
    first.value_c.constraint_mode(1);
    parent_item = new();
    parent_item.requested = 11;
    result = parent_item.randomize();
    `checkd(result, 1)
    `checkd(parent_item.value, 11)
    `checkd(parent_item.child == null, 1)
    `checkd(parent_item.other == null, 1)

    // Constraints without mode arrays, and static constraint modes, also skip null.
    plain_item = new();
    result = plain_item.randomize();
    `checkd(result, 1)
    `checkd(plain_item.child == null, 1)
    plain_item.child = new();
    result = plain_item.randomize();
    `checkd(result, 1)
    `checkd(plain_item.child.value, 7)
    plain_item.child = null;
    result = plain_item.randomize();
    `checkd(result, 1)
    mode_item = new();
    mode_item.value_c.constraint_mode(1);
    static_item = new();
    result = static_item.randomize();
    `checkd(result, 1)
    static_item.child = mode_item;
    result = static_item.randomize();
    `checkd(result, 1)
    `checkd(mode_item.value, 9)
    static_item.child = null;
    mode_item.value = 33;
    result = static_item.randomize();
    `checkd(result, 1)
    `checkd(mode_item.value, 33)

    // Keep the previous object alive to detect stale solver writes deterministically.
    second = new();
    second.dynamic_data = new[3];
    for (int epoch = 0; epoch < 12; epoch++) begin
      first.value = 93;
      first.wide = 65'h1_dead_beef_f00d_abcd;
      second.value = 94;
      second.wide = 65'h1_cafe_beef_f00d_abcd;
      parent_item.requested = 7'(epoch + 1);
      if (epoch % 3 == 0) parent_item.child = null;
      else if (epoch % 3 == 1) parent_item.child = first;
      else parent_item.child = second;
      if (parent_item.child != null) begin
        parent_item.child.requested = 7'(epoch + 19);
        old_pre = parent_item.child.pre_count;
        old_post = parent_item.child.post_count;
      end
      if (epoch % 2 == 0) result = parent_item.randomize();
      else result = parent_item.randomize() with {value == requested;};
      `checkd(result, 1)
      `checkd(parent_item.value, parent_item.requested)
      `checkd(parent_item.other == null, 1)
      if (parent_item.child != null) begin
        `checkd(parent_item.child.value, parent_item.child.requested)
        `checkd(parent_item.child.wide, {58'b0, parent_item.child.requested})
        `checkd(parent_item.child.state inside {nullable_child::IDLE, nullable_child::BUSY}, 1)
        foreach (parent_item.child.fixed_data[i]) begin
          `checkd(parent_item.child.fixed_data[i], parent_item.child.requested)
        end
        foreach (parent_item.child.dynamic_data[i]) begin
          `checkd(parent_item.child.dynamic_data[i], parent_item.child.requested)
        end
        `checkd(parent_item.child.pre_count, old_pre + 1)
        `checkd(parent_item.child.post_count, old_post + 1)
      end
      if (parent_item.child != first) begin
        `checkd(first.value, 93)
        `checkd(first.wide, 65'h1_dead_beef_f00d_abcd)
      end
      if (parent_item.child != second) begin
        `checkd(second.value, 94)
        `checkd(second.wide, 65'h1_cafe_beef_f00d_abcd)
      end
    end

    // Sibling registrations stay independent when one handle disappears.
    parent_item.child = first;
    parent_item.other = second;
    first.requested = 49;
    second.requested = 51;
    result = parent_item.randomize();
    `checkd(result, 1)
    `checkd(first.value, 49)
    `checkd(second.value, 51)
    parent_item.child = null;
    first.value = 93;
    second.requested = 53;
    result = parent_item.randomize() with {value == requested;};
    `checkd(result, 1)
    `checkd(first.value, 93)
    `checkd(second.value, 53)
    parent_item.other = null;

    // Register the graph after pre_randomize changes the selected child.
    callback_item = new();
    callback_item.requested = 55;
    callback_item.next_child = first;
    result = callback_item.randomize();
    `checkd(result, 1)
    `checkd(callback_item.child == first, 1)
    `checkd(first.value, first.requested)
    callback_item.next_child = second;
    first.value = 93;
    result = callback_item.randomize() with {value == requested;};
    `checkd(result, 1)
    `checkd(callback_item.child == second, 1)
    `checkd(first.value, 93)
    `checkd(second.value, second.requested)
    callback_item.next_child = null;
    second.value = 94;
    result = callback_item.randomize();
    `checkd(result, 1)
    `checkd(callback_item.child == null, 1)
    `checkd(second.value, 94)

    // Every prefix in a deeper path may independently be null.
    top_item = new();
    result = top_item.randomize();
    `checkd(result, 1)
    `checkd(top_item.marker, 1)
    top_item.parent_item = parent_item;
    parent_item.child = null;
    result = top_item.randomize();
    `checkd(result, 1)
    parent_item.child = first;
    first.requested = 43;
    result = top_item.randomize();
    `checkd(result, 1)
    `checkd(first.value, 43)
    top_item.parent_item = null;
    first.value = 93;
    result = top_item.randomize() with {marker == 1;};
    `checkd(result, 1)
    `checkd(first.value, 93)

    // A refreshed registration must still honor rand_mode and constraint_mode.
    parent_item.child = first;
    first.value_c.constraint_mode(0);
    first.value.rand_mode(0);
    first.value = 91;
    result = parent_item.randomize();
    `checkd(result, 1)
    `checkd(first.value, 91)
    first.value.rand_mode(1);
    first.value_c.constraint_mode(1);
    first.requested = 45;
    result = parent_item.randomize();
    `checkd(result, 1)
    `checkd(first.value, 45)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
`endif
