// DESCRIPTION: Verilator: Constraint foreach does not drive user state variables
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off DECLFILENAME

class foreach_state;
  rand int values[3];
  int bound;
  constraint values_c {foreach (values[index]) values[index] == bound + index;}
endclass

module t;
  foreach_state item;
  initial begin
    item = new();
    if (item.randomize() != 1) $stop;
    $write("%p\n", item.values);
    $finish;
  end
endmodule
