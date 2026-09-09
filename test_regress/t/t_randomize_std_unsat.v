// DESCRIPTION: Verilator: Failed scope randomization retains argument values
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class scope_operations;
  static function int pick_values(ref bit [6:0] value, ref bit [64:0] wide_value,
                                  input int requested);
    return std::randomize(value, wide_value) with {int'(value) == requested;};
  endfunction
  static function int solve_aliases(ref bit [30:0] first, ref bit [30:0] second);
    return std::randomize(first, second) with {1 == 0;};
  endfunction
  static function int fixed_alias(ref bit [14:0] first, ref bit [14:0] data[3:1]);
    bit [14:0] previous_value = first;
    int result = std::randomize(first, data) with {1 == 0;};
    `checkd(first, previous_value)
    return result;
  endfunction
  static function int dynamic_alias(ref bit [6:0] first, ref bit [6:0] data[]);
    bit [6:0] previous_value = first;
    int result = std::randomize(first, data) with {1 == 0;};
    `checkd(first, previous_value)
    return result;
  endfunction
endclass

module t;
  typedef bit [6:0] small_queue_t[$];

  initial begin
    bit [6:0] value;
    bit [30:0] free_value;
    bit [64:0] wide_value;
    bit [14:0] down[3:1];
    bit [14:0] up[-1:1];
    bit [6:0] dynamic_values[];
    bit [30:0] queue_values[$];
    bit [64:0] associative_values[string];
    small_queue_t nested_values[2:1];
    int requested;
    int result;

    for (int attempt = 0; attempt < 4; ++attempt) begin
      value = 7'(23 + attempt);
      free_value = 31'(12345 + attempt);
      wide_value = 65'h1_01234567_89abcdef + 65'(attempt);
      requested = 200 + attempt;
      result = std::randomize(value, free_value, wide_value) with {int'(value) == requested;};
      `checkd(result, 0)
      `checkd(value, 7'(23 + attempt))
      `checkd(free_value, 31'(12345 + attempt))
      `checkd(wide_value, 65'h1_01234567_89abcdef + 65'(attempt))
      requested = 5 + attempt;
      result = std::randomize(value, free_value, wide_value) with {int'(value) == requested;};
      `checkd(result, 1)
      `checkd(value, 7'(requested))
    end

    // Distinct formal arguments may alias the same actual variable.
    free_value = 31'h1234567;
    result = scope_operations::solve_aliases(free_value, free_value);
    `checkd(result, 0)
    `checkd(free_value, 31'h1234567)

    // The helper must remain callable from static class methods.
    value = 7'd17;
    wide_value = 65'h1_abcdef01_23456789;
    result = scope_operations::pick_values(value, wide_value, 200);
    `checkd(result, 0)
    `checkd(value, 7'd17)
    `checkd(wide_value, 65'h1_abcdef01_23456789)
    result = scope_operations::pick_values(value, wide_value, 9);
    `checkd(result, 1)
    `checkd(value, 7'd9)

    foreach (down[i]) down[i] = 15'(i + 20);
    foreach (up[i]) up[i] = 15'(i + 30);
    dynamic_values = new[2];
    foreach (dynamic_values[i]) dynamic_values[i] = 7'(i + 40);
    queue_values.push_back(31'd51);
    queue_values.push_back(31'd52);
    associative_values["one"] = 65'h1_13579bdf_2468ace0;
    associative_values["two"] = 65'h0_abcdef01_23456789;
    requested = 200;
    result = std::randomize(
        value, down, up, dynamic_values, queue_values, associative_values
    ) with {
      int'(value) == requested;
      foreach (dynamic_values[i]) dynamic_values[i] == 7'd11;
    };
    `checkd(result, 0)
    `checkd(value, 7'd9)
    foreach (down[i]) `checkd(down[i], 15'(i + 20))
    foreach (up[i]) `checkd(up[i], 15'(i + 30))
    `checkd(dynamic_values.size(), 2)
    foreach (dynamic_values[i]) `checkd(dynamic_values[i], 7'(i + 40))
    `checkd(queue_values.size(), 2)
    `checkd(queue_values[0], 31'd51)
    `checkd(queue_values[1], 31'd52)
    `checkd(associative_values.size(), 2)
    `checkd(associative_values["one"], 65'h1_13579bdf_2468ace0)
    `checkd(associative_values["two"], 65'h0_abcdef01_23456789)
    result = scope_operations::fixed_alias(down[1], down);
    `checkd(result, 0)
    foreach (down[i]) `checkd(down[i], 15'(i + 20))
    result = scope_operations::dynamic_alias(dynamic_values[0], dynamic_values);
    `checkd(result, 0)
    foreach (dynamic_values[i]) `checkd(dynamic_values[i], 7'(i + 40))
    requested = 13;
    result = std::randomize(
        value, dynamic_values
    ) with {
      int'(value) == requested;
      foreach (dynamic_values[i]) dynamic_values[i] == 7'd11;
    };
    `checkd(result, 1)
    `checkd(value, 7'd13)
    `checkd(dynamic_values.size(), 2)
    foreach (dynamic_values[i]) `checkd(dynamic_values[i], 7'd11)

    nested_values[1].push_back(7'd71);
    nested_values[2].push_back(7'd72);
    requested = 200;
    result = std::randomize(value, nested_values) with {int'(value) == requested;};
    `checkd(result, 0)
    `checkd(nested_values[1].size(), 1)
    `checkd(nested_values[2].size(), 1)
    `checkd(nested_values[1][0], 7'd71)
    `checkd(nested_values[2][0], 7'd72)

    result = std::randomize() with {1 == 0;};
    `checkd(result, 0)
    result = std::randomize() with {1 == 1;};
    `checkd(result, 1)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
