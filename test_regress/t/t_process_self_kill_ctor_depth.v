// DESCRIPTION: Verilator: Self-kill process boundaries survive deep block splitting
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  class killer;
    function new(bit should_kill, ref process killed_process,
                 ref bit constructor_started, ref bit constructor_fell_through);
      if (should_kill) begin
        if (!constructor_started) begin
          if (!constructor_fell_through) begin
            killed_process = process::self();
            constructor_started = 1'b1;
            killed_process.kill();
            constructor_fell_through = 1'b1;
          end
        end
      end
    endfunction
  endclass

  killer original_object;
  killer assigned_object;
  process killed_process;
  bit constructor_started;
  bit constructor_fell_through;
  bit assignment_fell_through;

  initial begin
    original_object = new(0, killed_process, constructor_started,
                          constructor_fell_through);
    assigned_object = original_object;
    assigned_object = new(1, killed_process, constructor_started,
                          constructor_fell_through);
    assignment_fell_through = 1'b1;
  end

  final begin
    `checkd(constructor_started, 1)
    `checkd(constructor_fell_through, 0)
    `checkd(assignment_fell_through, 0)
    `checkd(killed_process == null, 0)
    `checkd(killed_process.status(), process::KILLED)
    `checkd(original_object == null, 0)
    `checkd(assigned_object == original_object, 1)
    $write("*-* All Finished *-*\n");
  end
endmodule
