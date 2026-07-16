// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  process self_process;
  bit after_kill;

  initial begin
    fork
      begin
        self_process = process::self();
        self_process.kill();

        // This fork branch has no timing control. TransformForks still emits
        // it as a coroutine, and self-kill must take the co_return path.
        after_kill = 1'b1;
      end
    join_none

    #1;
    `checkd(after_kill, 0)
    `checkd(self_process.status(), process::KILLED)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #20 $stop;  // timeout
endmodule
