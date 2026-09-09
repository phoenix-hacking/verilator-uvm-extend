// DESCRIPTION: Verilator: Invalid element indices into dynamic DPI open arrays
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  import "DPI-C" function void dpi_dynamic_oob(
    input int values[][],
    input int empty_values[]
  );
  typedef int column_t[$];
  column_t columns[2:4];
  int empty_values[];
  initial begin
    foreach (columns[i]) for (int j = 0; j < i - 1; j++) columns[i].push_back(i * 100 + j);
    dpi_dynamic_oob(columns, empty_values);
    foreach (columns[i]) if (columns[i].size() != i - 1) $stop;
    if (empty_values.size() != 0) $stop;
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
