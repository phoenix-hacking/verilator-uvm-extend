// DESCRIPTION: Verilator: Persistent process identity for process-aware always_comb
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off LATCH
// verilator lint_off UNUSEDSIGNAL

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  logic stimulus = 1'b0;
  int context_token;
  int neighbor_random;
  bit first_seen;
  bit second_seen;
  bit first_rng_unchanged_after_first;
  process first_process;
  process second_process;
  process::state first_inside_status;
  process::state second_inside_status;
  string first_rng_after_body;
  string second_rng_after_body;

  // An always_comb is one persistent SystemVerilog process.  It runs once at time zero and then
  // waits on its implicit sensitivity before the second activation below.
  always_comb begin : tracked_process
    process current_process;

    current_process = process::self();
    if (!stimulus) begin
      first_seen = 1'b1;
      first_process = current_process;
      first_inside_status = current_process.status();
      current_process.srandom(32'h1357_0001);
      first_rng_after_body = current_process.get_randstate();
      context_token = 1;
    end else begin
      second_seen = 1'b1;
      second_process = current_process;
      second_inside_status = current_process.status();
      current_process.srandom(32'h1357_0002);
      second_rng_after_body = current_process.get_randstate();
      context_token = 2;
    end
  end

  // Reading context_token orders this separate process after tracked_process.  Its random call
  // must not consume the tracked process's RNG after that process returns to its implicit wait.
  always_comb begin : neighboring_process
    if (context_token != 0) neighbor_random = $urandom;
  end

  initial begin
    #1;
    first_rng_unchanged_after_first =
        first_process.get_randstate() == first_rng_after_body;
    stimulus = 1'b1;
    #1;

    // Check only after the second trigger so a broken implementation still demonstrates that it
    // allocates two distinct process handles instead of failing after the first activation.
    `checkd(first_seen, 1)
    `checkd(second_seen, 1)
    `checkd(first_process == null, 0)
    `checkd(second_process == null, 0)
    $write("identity=%0d first_status=%0d second_status=%0d first_rng_unchanged=%0d second_rng_unchanged=%0d\n",
           first_process == second_process, first_process.status(), second_process.status(),
           first_rng_unchanged_after_first,
           second_process.get_randstate() == second_rng_after_body);
    `checkd(first_inside_status, process::RUNNING)
    `checkd(second_inside_status, process::RUNNING)
    `checkd(first_process == second_process, 1)
    `checkd(first_process.status(), process::WAITING)
    `checkd(second_process.status(), process::WAITING)
    `checkd(first_rng_unchanged_after_first, 1)
    `checkd(second_process.get_randstate() == second_rng_after_body, 1)

    // Keep neighboring_process and its random call observable to the optimizer.
    $write("*-* All Finished *-* neighbor=%0d\n", neighbor_random);
    $finish;
  end

  initial #10 `stop;
endmodule
