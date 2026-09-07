// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  typedef bit [14:0] entries_t[int];

  class SelectionTest;
    entries_t fixed_arrays[3:1];
    entries_t dynamic_arrays[];
    entries_t queue_arrays[$];
    entries_t assoc_arrays[int];
    rand bit [1:0] index;

    function entries_t make_entries(input bit [1:0] count);
      entries_t result;
      for (int k = 0; k < int'(count); ++k) result[k] = 0;
      return result;
    endfunction

    // The selected size still depends on a random index.
    constraint c_size {
      fixed_arrays[index].size() == 2;
      dynamic_arrays[int'(index)].num() == 2;
      queue_arrays[int'(index)].size() == 2;
      assoc_arrays[int'(index)].num() == 2;
      make_entries(index).size() == 2;
    }
  endclass

  initial begin
    automatic SelectionTest obj = new;
    int result;
    result = obj.randomize();
    $finish;
  end
endmodule
