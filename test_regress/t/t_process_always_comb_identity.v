// DESCRIPTION: Verilator: Independent always_comb process identities persist
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  logic trigger_a = 1'b0;
  logic trigger_b = 1'b0;
  process active_process_a;
  process active_process_b;
  process first_process_a;
  process first_process_b;
  process second_process_a;
  process second_process_b;
  process::state inside_status_a;
  process::state inside_status_b;

  // Retain each branch's captured handle so the test can compare both activations.
  /* verilator lint_off LATCH */
  always_comb begin : comb_a
    process current_process;

    current_process = process::self();
    active_process_a = current_process;
    inside_status_a = current_process.status();
    if (trigger_a) begin
      second_process_a = current_process;
    end else begin
      first_process_a = current_process;
    end
  end

  always_comb begin : comb_b
    process current_process;

    current_process = process::self();
    active_process_b = current_process;
    inside_status_b = current_process.status();
    if (trigger_b) begin
      second_process_b = current_process;
    end else begin
      first_process_b = current_process;
    end
  end
  /* verilator lint_on LATCH */

  initial begin
    #1;
    `checkd(first_process_a == null, 0)
    `checkd(first_process_b == null, 0)
    `checkd(second_process_a == null, 1)
    `checkd(second_process_b == null, 1)
    `checkd(active_process_a == first_process_a, 1)
    `checkd(active_process_b == first_process_b, 1)
    `checkd(inside_status_a, process::RUNNING)
    `checkd(inside_status_b, process::RUNNING)
    `checkd(first_process_a == first_process_b, 0)
    `checkd(first_process_a.status(), process::WAITING)
    `checkd(first_process_b.status(), process::WAITING)

    trigger_a = 1'b1;
    trigger_b = 1'b1;
    #1;
    `checkd(second_process_a == null, 0)
    `checkd(second_process_b == null, 0)
    `checkd(active_process_a == second_process_a, 1)
    `checkd(active_process_b == second_process_b, 1)
    `checkd(inside_status_a, process::RUNNING)
    `checkd(inside_status_b, process::RUNNING)
    `checkd(second_process_a == second_process_b, 0)
    `checkd(first_process_a == second_process_a, 1)
    `checkd(first_process_b == second_process_b, 1)
    `checkd(first_process_a.status(), process::WAITING)
    `checkd(first_process_b.status(), process::WAITING)
    `checkd(second_process_a.status(), process::WAITING)
    `checkd(second_process_b.status(), process::WAITING)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #10 `stop;
endmodule
