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
  rand bit [30:0] free_value;
  rand bit [64:0] wide_value;
  int requested;
  bit pre_override;
  int pre_count;
  int post_count;
  constraint value_c {int'(value) == requested;}
  function void pre_randomize();
    pre_count++;
    if (pre_override) begin
      free_value = 31'h1234567;
      wide_value = 65'h1_01234567_89abcdef;
    end
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
  rand bit [30:0] free_value;
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

`ifdef FAILED_STATE_EXPANDED
class snapshot_leaf;
  rand bit [30:0] value;
  static rand bit [30:0] shared_value;
  bit pre_override;
  bit pre_disable;
  int pre_count;
  int post_count;
  function void pre_randomize();
    ++pre_count;
    if (pre_override) value = 31'h13579;
    if (pre_disable) value.rand_mode(0);
  endfunction
  function void post_randomize();
    ++post_count;
  endfunction
endclass

typedef struct {
  snapshot_leaf peer;
  bit [14:0] tag;
} snapshot_wrapper_t;
typedef snapshot_leaf snapshot_queue_t[$];

class snapshot_graph;
  rand snapshot_leaf down[3:1];
  rand snapshot_leaf up[-2:0];
  rand snapshot_leaf dynamic_values[];
  rand snapshot_leaf queue_values[$];
  rand snapshot_leaf associative_values[string];
  rand snapshot_wrapper_t wrapped;
  rand snapshot_leaf matrix[3:1][2:1];
  rand snapshot_wrapper_t boxes[-1:1];
  rand snapshot_queue_t lanes[1:3];
  rand bit [6:0] bound;
  int requested;
  constraint c_bound {int'(bound) == requested;}

  function new();
    down[1] = new;
    down[2] = new;
    up[-2] = new;
    up[-1] = new;
    up[0] = down[1];
    dynamic_values = new[2];
    dynamic_values[0] = down[2];
    dynamic_values[1] = new;
    queue_values.push_back(down[1]);
    queue_values.push_back(null);
    associative_values["first"] = new;
    associative_values["empty"] = null;
    associative_values["alias"] = up[-2];
    wrapped.peer = new;
    foreach (matrix[i, j]) matrix[i][j] = new;
    foreach (boxes[i]) boxes[i].peer = new;
    lanes[1].push_back(down[1]);
    lanes[2].push_back(boxes[-1].peer);
    lanes[3].push_back(null);
  endfunction

  function void reset_values();
    foreach (down[i]) if (down[i] != null) down[i].value = 31'd77;
    foreach (up[i]) if (up[i] != null) up[i].value = 31'd77;
    foreach (dynamic_values[i]) if (dynamic_values[i] != null) dynamic_values[i].value = 31'd77;
    foreach (queue_values[i]) if (queue_values[i] != null) queue_values[i].value = 31'd77;
    foreach (associative_values[i])
    if (associative_values[i] != null) associative_values[i].value = 31'd77;
    wrapped.peer.value = 31'd77;
    wrapped.tag = 15'd13;
    foreach (matrix[i, j]) matrix[i][j].value = 31'd77;
    foreach (boxes[i]) begin
      boxes[i].peer.value = 31'd77;
      boxes[i].tag = 15'd13;
    end
    foreach (lanes[i, j]) if (lanes[i][j] != null) lanes[i][j].value = 31'd77;
    snapshot_leaf::shared_value = 31'd99;
  endfunction

  function void check_restored();
    foreach (down[i]) if (down[i] != null) `checkd(down[i].value, 31'd77)
    foreach (up[i]) if (up[i] != null) `checkd(up[i].value, 31'd77)
    foreach (dynamic_values[i])
    if (dynamic_values[i] != null) `checkd(dynamic_values[i].value, 31'd77)
    foreach (queue_values[i]) if (queue_values[i] != null) `checkd(queue_values[i].value, 31'd77)
    foreach (associative_values[i])
    if (associative_values[i] != null) `checkd(associative_values[i].value, 31'd77)
    `checkd(wrapped.peer.value, 31'd77)
    `checkd(wrapped.tag, 15'd13)
    foreach (matrix[i, j]) `checkd(matrix[i][j].value, 31'd77)
    foreach (boxes[i]) begin
      `checkd(boxes[i].peer.value, 31'd77)
      `checkd(boxes[i].tag, 15'd13)
    end
    foreach (lanes[i, j]) if (lanes[i][j] != null) `checkd(lanes[i][j].value, 31'd77)
    `checkd(snapshot_leaf::shared_value, 31'd99)
    `checkd(dynamic_values.size(), 2)
    `checkd(queue_values.size(), 2)
    `checkd(associative_values.size(), 3)
    `checkd(down[3] == null, 1'b1)
    `checkd(up[0] == down[1], 1'b1)
    `checkd(dynamic_values[0] == down[2], 1'b1)
  endfunction
endclass

class snapshot_rebuild;
  rand snapshot_leaf values[];
  rand bit [6:0] bound;
  snapshot_leaf retained;
  int requested;
  int pre_count;
  int post_count;
  constraint c_bound {int'(bound) == requested;}

  function new();
    retained = new;
    values = new[1];
    values[0] = retained;
  endfunction
  function void pre_randomize();
    ++pre_count;
    values = new[3];
    values[0] = new;
    values[0].value = 31'd101;
    values[1] = retained;
    values[1].value = 31'd201;
  endfunction
  function void post_randomize();
    ++post_count;
  endfunction
  function void check_restored();
    `checkd(values.size(), 3)
    `checkd(values[0].value, 31'd101)
    `checkd(values[1].value, 31'd201)
    `checkd(values[1] == retained, 1'b1)
    `checkd(values[2] == null, 1'b1)
    `checkd(post_count, 0)
  endfunction
endclass

class snapshot_extra extends callback_child;
  rand bit [64:0] extra_value;
endclass

class snapshot_callback_parent;
  rand snapshot_leaf children[1];
  rand bit [6:0] bound;
  int requested;
  constraint c_bound {int'(bound) == requested;}
  function new();
    children[0] = new;
  endfunction
endclass

class snapshot_cycles;
  rand bit [6:0] bound;
  randc bit [2:0] basic_cycle;
  randc bit [6:0] solved_cycle;
  int requested;
  constraint c_bound {int'(bound) == requested;}
  constraint c_cycle {solved_cycle inside {[7'd0 : 7'd5]};}
endclass
`endif

module t;
  initial begin
    callback_base item;
    callback_derived derived_item;
    callback_parent parent_item;
    callback_array array_item;
    int result;
    bit [30:0] free_before;
    bit [64:0] wide_before;

    item = new();
    item.value = 23;
    item.free_value = 31'h7654321;
    item.wide_value = 65'h1_abcdef01_23456789;
    item.requested = 200;
    result = item.randomize();
    `checkd(result, 0)
    `checkd(item.pre_count, 1)
    `checkd(item.post_count, 0)
    `checkd(int'(item.value), 23)
    `checkd(item.free_value, 31'h7654321)
    `checkd(item.wide_value, 65'h1_abcdef01_23456789)
    item.requested = 7;
    result = item.randomize();
    `checkd(result, 1)
    `checkd(item.pre_count, 2)
    `checkd(item.post_count, 1)
    `checkd(int'(item.value), 7)

    item.value.rand_mode(0);
    free_before = item.free_value;
    wide_before = item.wide_value;
    item.requested = 8;
    result = item.randomize();
    `checkd(result, 0)
    `checkd(item.pre_count, 3)
    `checkd(item.post_count, 1)
    `checkd(int'(item.value), 7)
    `checkd(item.free_value, free_before)
    `checkd(item.wide_value, wide_before)
    item.value.rand_mode(1);

    // Changes made by pre_randomize survive a failed solve.
    item.pre_override = 1;
    result = item.randomize() with {value == 9;};
    `checkd(result, 0)
    `checkd(item.pre_count, 4)
    `checkd(item.post_count, 1)
    `checkd(item.free_value, 31'h1234567)
    `checkd(item.wide_value, 65'h1_01234567_89abcdef)
    item.pre_override = 0;
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
    parent_item.free_value = 31'h3579;
    parent_item.child.free_value = 31'h1357;
    parent_item.requested = 5;
    parent_item.child.requested = 6;
    result = parent_item.randomize();
    `checkd(result, 0)
    `checkd(parent_item.pre_count, 1)
    `checkd(parent_item.post_count, 0)
    `checkd(parent_item.child.pre_count, 1)
    `checkd(parent_item.child.post_count, 0)
    `checkd(parent_item.free_value, 31'h3579)
    `checkd(parent_item.child.free_value, 31'h1357)
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
    array_item.value = 44;
    array_item.free_value = 31'h2468;
    array_item.requested = 4;
    array_item.element_requested = 200;
    result = array_item.randomize();
    `checkd(result, 0)
    `checkd(array_item.pre_count, 1)
    `checkd(array_item.post_count, 0)
    `checkd(int'(array_item.value), 44)
    `checkd(array_item.free_value, 31'h2468)
    `checkd(array_item.data.size(), 0)
    array_item.element_requested = 17;
    result = array_item.randomize();
    `checkd(result, 1)
    `checkd(array_item.pre_count, 2)
    `checkd(array_item.post_count, 1)
    `checkd(array_item.data.size(), 3)
    foreach (array_item.data[i]) `checkd(int'(array_item.data[i]), 17)

    array_item.data = new[2];
    array_item.data[0] = 11;
    array_item.data[1] = 13;
    array_item.element_requested = 200;
    result = array_item.randomize() with {value == 4;};
    `checkd(result, 0)
    `checkd(array_item.pre_count, 3)
    `checkd(array_item.post_count, 1)
    `checkd(array_item.data.size(), 2)
    `checkd(int'(array_item.data[0]), 11)
    `checkd(int'(array_item.data[1]), 13)
    array_item.element_requested = 19;
    result = array_item.randomize() with {value == 4;};
    `checkd(result, 1)
    `checkd(array_item.pre_count, 4)
    `checkd(array_item.post_count, 2)
    `checkd(array_item.data.size(), 3)
    foreach (array_item.data[i]) `checkd(int'(array_item.data[i]), 19)

    // A failed element solve must also undo shrinking and retain every element.
    array_item.data = new[5];
    foreach (array_item.data[i]) array_item.data[i] = 7'(i + 31);
    array_item.element_requested = 200;
    result = array_item.randomize();
    `checkd(result, 0)
    `checkd(array_item.data.size(), 5)
    foreach (array_item.data[i]) `checkd(int'(array_item.data[i]), i + 31)
    array_item.element_requested = 21;
    result = array_item.randomize();
    `checkd(result, 1)
    `checkd(array_item.data.size(), 3)
    foreach (array_item.data[i]) `checkd(int'(array_item.data[i]), 21)

`ifdef FAILED_STATE_EXPANDED
    begin
      automatic snapshot_graph graph = new;
      automatic snapshot_rebuild rebuilt = new;
      automatic snapshot_callback_parent callback_items = new;
      automatic snapshot_extra extra = new;
      automatic callback_parent polymorphic_parent = new;
      automatic snapshot_cycles cycles = new;
      bit changed;
      bit [7:0] basic_seen;
      bit [5:0] solved_seen;
      bit [2:0] basic_before;
      bit [6:0] solved_before;

      // Restore whole containers before reusing their child bindings; aliases remain aliases.
      for (int attempt = 0; attempt < 2; ++attempt) begin
        graph.reset_values();
        graph.requested = 200;
        result = graph.randomize();
        `checkd(result, 0)
        graph.check_restored();
        result = graph.randomize() with {bound == 7'd3;};
        `checkd(result, 0)
        graph.check_restored();
        graph.requested = 5;
        result = graph.randomize();
        `checkd(result, 1)
        `checkd(graph.bound, 7'd5)
        // Every aliased object receives one callback per attempt.
        `checkd(graph.down[1].pre_count, 3 * (attempt + 1))
        `checkd(graph.down[1].post_count, attempt + 1)
        changed = 0;
        foreach (graph.down[i]) if (graph.down[i] != null) changed |= graph.down[i].value != 31'd77;
        `checkd(changed, 1'b1)
      end

      // Snapshot the container and handles installed by pre_randomize.
      rebuilt.requested = 200;
      result = rebuilt.randomize();
      `checkd(result, 0)
      `checkd(rebuilt.pre_count, 1)
      rebuilt.check_restored();
      result = rebuilt.randomize() with {bound == 7'd3;};
      `checkd(result, 0)
      `checkd(rebuilt.pre_count, 2)
      rebuilt.check_restored();

      // Child callbacks in arrays finish before snapshotting, even when they disable a field.
      callback_items.requested = 200;
      callback_items.children[0].value = 31'h2468;
      callback_items.children[0].pre_override = 1;
      callback_items.children[0].pre_disable = 1;
      result = callback_items.randomize();
      `checkd(result, 0)
      `checkd(callback_items.children[0].value, 31'h13579)
      `checkd(callback_items.children[0].pre_count, 1)
      `checkd(callback_items.children[0].post_count, 0)
      callback_items.children[0].pre_disable = 0;
      callback_items.children[0].value.rand_mode(1);
      result = callback_items.randomize() with {bound == 7'd3;};
      `checkd(result, 0)
      `checkd(callback_items.children[0].value, 31'h13579)
      `checkd(callback_items.children[0].pre_count, 2)
      `checkd(callback_items.children[0].post_count, 0)
      callback_items.requested = 5;
      callback_items.children[0].pre_override = 0;
      result = callback_items.randomize();
      `checkd(result, 1)
      `checkd(callback_items.children[0].pre_count, 3)
      `checkd(callback_items.children[0].post_count, 1)
      `checkd(callback_items.children[0].value != 31'h13579, 1'b1)

      // A base-typed rand handle must preserve the dynamic type's additional fields.
      polymorphic_parent.child = extra;
      polymorphic_parent.requested = 200;
      extra.requested = 7;
      extra.free_value = 31'h13579;
      extra.extra_value = 65'h1_01234567_89abcdef;
      result = polymorphic_parent.randomize();
      `checkd(result, 0)
      `checkd(extra.free_value, 31'h13579)
      `checkd(extra.extra_value, 65'h1_01234567_89abcdef)
      result = polymorphic_parent.randomize() with {value == 7'd3;};
      `checkd(result, 0)
      `checkd(extra.free_value, 31'h13579)
      `checkd(extra.extra_value, 65'h1_01234567_89abcdef)

      // Failed attempts must not consume basic or solver-managed cyclic values.
      for (int iteration = 0; iteration < 24; ++iteration) begin
        if ((iteration % 8) == 0) basic_seen = 0;
        if ((iteration % 6) == 0) solved_seen = 0;
        cycles.requested = 5;
        result = cycles.randomize();
        `checkd(result, 1)
        `checkd(basic_seen[cycles.basic_cycle], 1'b0)
        `checkd(solved_seen[3'(cycles.solved_cycle)], 1'b0)
        basic_seen[cycles.basic_cycle] = 1;
        solved_seen[3'(cycles.solved_cycle)] = 1;
        basic_before = cycles.basic_cycle;
        solved_before = cycles.solved_cycle;
        cycles.requested = 200;
        result = cycles.randomize();
        `checkd(result, 0)
        `checkd(cycles.basic_cycle, basic_before)
        `checkd(cycles.solved_cycle, solved_before)
        `checkd(cycles.bound, 7'd5)
      end
    end
`endif

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
