// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2024 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv, expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

package Pkg;
  typedef enum {
    RED = 0,
    GREEN = 1,
    BLUE = 2
  } color_t;

  typedef struct {color_t pixels[32];} line_t;

  typedef struct {line_t line[32];} screen_t;

  typedef struct packed {
    bit [6:0] marker;
    color_t color;
  } packed_line_t;

  typedef struct packed {
    packed_line_t left;
    packed_line_t right;
  } packed_screen_t;

  typedef string label_t;
  typedef chandle handle_t;

  typedef struct {
    color_t color;
    label_t label;
    real scale;
    handle_t handle;
    bit [6:0] marker;
  } sample_t;
endpackage

module t (
    input clk
);
  Pkg::screen_t screen;
  Pkg::line_t rows[3:1];
  Pkg::line_t override_line;
  Pkg::sample_t samples[1:3];
  Pkg::color_t current_color;
  Pkg::packed_line_t packed_override;
  Pkg::packed_screen_t packed_screen;
  bit [6:0] bits;
  logic [6:0] logic_bits;
  int cyc = 0;

  initial begin
    screen = '{default: '0, Pkg::color_t: Pkg::RED};
    $display("%p", screen);
    foreach (screen.line[i])
      foreach (screen.line[i].pixels[j]) `checkd(screen.line[i].pixels[j], Pkg::RED);
  end

  always @(posedge clk) begin
    current_color = Pkg::color_t'(cyc);
    screen = '{default: '1, Pkg::color_t: current_color};
    foreach (screen.line[i])
      foreach (screen.line[i].pixels[j]) `checkd(screen.line[i].pixels[j], current_color);

    override_line = '{pixels: '{default: Pkg::BLUE}};
    // An explicit index takes precedence over recursively applied type keys.
    rows = '{2: override_line, Pkg::color_t: current_color};
    foreach (rows[i])
      foreach (rows[i].pixels[j])
        `checkd(rows[i].pixels[j], i == 2 ? Pkg::BLUE : current_color);

    // A matching aggregate type takes precedence over keys for its fields.
    screen = '{Pkg::line_t: override_line, Pkg::color_t: current_color, default: '1};
    foreach (screen.line[i])
      foreach (screen.line[i].pixels[j]) `checkd(screen.line[i].pixels[j], Pkg::BLUE);

    // A default of the element type assigns the whole element.
    rows = '{default: override_line};
    foreach (rows[i])
      foreach (rows[i].pixels[j]) `checkd(rows[i].pixels[j], Pkg::BLUE);

    packed_screen = '{Pkg::color_t: current_color, default: '1};
    `checkd(packed_screen.left.color, current_color);
    `checkd(packed_screen.right.color, current_color);
    `checkd(packed_screen.left.marker, 7'h7f);
    `checkd(packed_screen.right.marker, 7'h7f);
    packed_override = '{marker: 7'h5a, color: Pkg::BLUE};
    packed_screen = '{Pkg::packed_line_t: packed_override, Pkg::color_t: current_color,
                      default: '1};
    `checkd(packed_screen.left, packed_override);
    `checkd(packed_screen.right, packed_override);

    bits = '{bit: cyc[0], default: 1'b1};
    logic_bits = '{logic: cyc[0], default: 1'b1};
    `checkd(bits, {7{cyc[0]}});
    `checkd(logic_bits, {7{cyc[0]}});

    samples = '{Pkg::color_t: current_color, Pkg::label_t: "enum", real: 0.5 * cyc,
                Pkg::handle_t: null, default: 7'h5a};
    foreach (samples[i]) begin
      `checkd(samples[i].color, current_color);
      `checkd(samples[i].label == "enum", 1'b1);
      `checkd(samples[i].scale == 0.5 * cyc, 1'b1);
      `checkd(samples[i].handle == null, 1'b1);
      `checkd(samples[i].marker, 7'h5a);
    end

    if (++cyc == 3) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
