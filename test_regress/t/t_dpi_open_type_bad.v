// DESCRIPTION: Verilator: Type and dimension matching for DPI open arrays
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  import "DPI-C" function void consume(input int values[]);
  import "DPI-C" function void consume_rows(input int values[][3]);
  int scalar;
  real reals[];
  byte bytes[$];
  int unsigned unsigned_values[];
  integer four_state[];
  int two_dimensions[][];
  int associative[int];
  real fixed_reals[3];
  int wrong_rows[][2];
  initial begin
    consume(scalar);
    consume(reals);
    consume(bytes);
    consume(unsigned_values);
    consume(four_state);
    consume(two_dimensions);
    consume(associative);
    consume(fixed_reals);
    consume_rows(wrong_rows);
  end
endmodule
