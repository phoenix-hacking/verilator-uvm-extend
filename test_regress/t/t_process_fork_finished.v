// DESCRIPTION: Verilator: Forked process status at join completion
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  process joined_process;
  process joined_any_process;
  process parent_process;
  process::state joined_status;
  process::state joined_any_status;

  initial begin
    parent_process = process::self();

    fork
      begin
      end
    join
    `checkd(parent_process.status(), process::RUNNING)

    fork
      begin
      end
    join_any
    `checkd(parent_process.status(), process::RUNNING)

    fork
      begin
        joined_process = process::self();
        #1;
      end
    join
    joined_status = joined_process.status();

    fork
      begin
        joined_any_process = process::self();
        #1;
      end
    join_any
    joined_any_status = joined_any_process.status();

    // Yield so both child coroutines can fully unwind before checking their final state.
    #0;
    `checkd(joined_status, process::FINISHED)
    `checkd(joined_any_status, process::FINISHED)
    `checkd(joined_process.status(), process::FINISHED)
    `checkd(joined_any_process.status(), process::FINISHED)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #100 `stop;
endmodule
