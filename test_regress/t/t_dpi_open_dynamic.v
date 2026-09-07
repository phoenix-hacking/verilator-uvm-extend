// DESCRIPTION: Verilator: Dynamic and queue actual arguments to DPI open arrays
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  import "DPI-C" function int dpi_dynamic_read(
    input int count,
    input byte unsigned values[]
  );
  import "DPI-C" function void dpi_dynamic_write(inout byte unsigned values[]);
  import "DPI-C" function void dpi_dynamic_wide(inout bit [64:0] values[]);
  import "DPI-C" function void dpi_dynamic_rows(input int values[][]);
  import "DPI-C" function void dpi_dynamic_columns(input int values[][]);
  import "DPI-C" function void dpi_dynamic_real(inout real values[]);
  import "DPI-C" function chandle dpi_dynamic_handle(input int index);
  import "DPI-C" function void dpi_dynamic_handles(inout chandle values[]);
  import "DPI-C" function void dpi_dynamic_strings(inout string values[]);
  import "DPI-C" function void dpi_dynamic_equivalent(input int values[]);
  import "DPI-C" function void dpi_dynamic_sized_outer(input int values[3][]);
  import "DPI-C" function void dpi_dynamic_sized_inner(inout int values[][3]);

  typedef byte unsigned byte_t;
  typedef int row_t[3:1];
  typedef int column_t[$];
  typedef bit signed [31:0] int_bits_t;
  typedef struct packed signed {
    bit [15:0] hi;
    bit [15:0] lo;
  } int_struct_t;
  typedef enum int {
    ZERO,
    ONE,
    TWO
  } enum_t;

  class holder;
    byte_t values[];
    function void check(int count);
      values = new[count];
      foreach (values[i]) values[i] = 8'(13 * i + 7);
      `checkd(dpi_dynamic_read(count, values), count)
      dpi_dynamic_write(values);
      foreach (values[i]) `checkd(values[i], 8'(13 * i + 8))
    endfunction
  endclass

  byte_t bytes[];
  byte_t queue[$];
  byte_t bounded[$:16];
  bit [64:0] wide[];
  row_t rows[];
  column_t columns[2:4];
  column_t sized_columns[2:4];
  int_bits_t packed_ints[];
  int_struct_t struct_ints[];
  enum_t enum_ints[];
  real reals[];
  chandle handles[];
  chandle fixed_handles[7];
  string strings[];
  string fixed_strings[2:4];
  real fixed_reals[7];
  holder item;

  initial begin
    int lengths[4];
    if ($test$plusargs("DPI_BAD_OUTER")) begin
      rows = new[2];
      dpi_dynamic_sized_outer(rows);
      `stop;
    end
    if ($test$plusargs("DPI_BAD_INNER")) begin
      foreach (sized_columns[i]) for (int j = 0; j < i; j++) sized_columns[i].push_back(j);
      dpi_dynamic_sized_inner(sized_columns);
      `stop;
    end
    lengths = '{0, 1, 17, 513};
    item = new;
    foreach (lengths[n]) begin
      bytes = new[lengths[n]];
      queue.delete();
      foreach (bytes[i]) begin
        bytes[i] = 8'(13 * i + 7);
        queue.push_back(bytes[i]);
      end
      `checkd(dpi_dynamic_read(lengths[n], bytes), lengths[n])
      `checkd(dpi_dynamic_read(lengths[n], queue), lengths[n])
      dpi_dynamic_write(bytes);
      dpi_dynamic_write(queue);
      foreach (bytes[i]) begin
        `checkd(bytes[i], 8'(13 * i + 8))
        `checkd(queue[i], bytes[i])
      end
      item.check(lengths[n]);
    end
    // Reuse after shrinking and deleting, including the empty-queue bounds.
    bytes = new[1];
    bytes[0] = 7;
    `checkd(dpi_dynamic_read(1, bytes), 1)
    bytes.delete();
    queue.delete();
    `checkd(dpi_dynamic_read(0, bytes), 0)
    `checkd(dpi_dynamic_read(0, queue), 0)
    for (int i = 0; i < 17; i++) bounded.push_back(8'(13 * i + 7));
    `checkd(dpi_dynamic_read(17, bounded), 17)
    dpi_dynamic_write(bounded);
    foreach (bounded[i]) `checkd(bounded[i], 8'(13 * i + 8))

    wide = new[17];
    foreach (wide[i]) wide[i] = 65'h1_12345678_abcdef00 + 65'(i);
    dpi_dynamic_wide(wide);
    foreach (wide[i]) `checkd(wide[i], (65'h1_12345678_abcdef00 + 65'(i)) ^ 65'h1_00000001_80000000)

    rows = new[3];
    foreach (rows[i, j]) rows[i][j] = i * 100 + j;
    dpi_dynamic_rows(rows);
    dpi_dynamic_sized_outer(rows);
    foreach (sized_columns[i]) for (int j = 0; j < 3; j++) sized_columns[i].push_back(i * 100 + j);
    dpi_dynamic_sized_inner(sized_columns);
    foreach (sized_columns[i]) begin
      `checkd(sized_columns[i].size(), 3)
      for (int j = 0; j < 3; j++) `checkd(sized_columns[i][j], i * 100 + j + 1)
    end
    foreach (columns[i]) for (int j = 0; j < i - 1; j++) columns[i].push_back(i * 100 + j);
    dpi_dynamic_columns(columns);

    packed_ints = new[3];
    struct_ints = new[3];
    enum_ints = new[3];
    foreach (packed_ints[i]) begin
      packed_ints[i] = int_bits_t'(i);
      struct_ints[i] = int_struct_t'(i);
      enum_ints[i] = enum_t'(i);
    end
    dpi_dynamic_equivalent(packed_ints);
    dpi_dynamic_equivalent(struct_ints);
    dpi_dynamic_equivalent(enum_ints);

    reals = new[7];
    handles = new[7];
    foreach (reals[i]) begin
      reals[i] = real'(i) + 0.5;
      handles[i] = dpi_dynamic_handle(i % 2);
    end
    dpi_dynamic_real(reals);
    handles[0] = null;
    dpi_dynamic_handles(handles);
    foreach (reals[i]) begin
      if (reals[i] != real'(i) + 1.5) `stop;
      if (handles[i] != dpi_dynamic_handle((i + 1) % 2)) `stop;
    end
    foreach (fixed_reals[i]) fixed_reals[i] = real'(i) + 0.5;
    dpi_dynamic_real(fixed_reals);
    foreach (fixed_reals[i]) if (fixed_reals[i] != real'(i) + 1.5) `stop;
    foreach (fixed_handles[i]) fixed_handles[i] = dpi_dynamic_handle(i % 2);
    fixed_handles[0] = null;
    dpi_dynamic_handles(fixed_handles);
    foreach (fixed_handles[i]) if (fixed_handles[i] != dpi_dynamic_handle((i + 1) % 2)) `stop;
    strings = new[3];
    foreach (strings[i]) strings[i] = $sformatf("value_%0d", i);
    foreach (fixed_strings[i]) fixed_strings[i] = $sformatf("value_%0d", i - 2);
    dpi_dynamic_strings(strings);
    dpi_dynamic_strings(fixed_strings);
    // C swaps pointers to the original strings; all values must be copied before writeback.
    foreach (strings[i]) if (strings[i] != $sformatf("value_%0d", (i + 1) % 3)) `stop;
    foreach (fixed_strings[i]) if (fixed_strings[i] != $sformatf("value_%0d", (i - 1) % 3)) `stop;
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
