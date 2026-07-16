// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2023 Antmicro Ltd
// SPDX-License-Identifier: CC0-1.0

module t;
  std::process proc;
  logic clk = 0;
  logic b = 0;

  always #1 clk = ~clk;

  task kill_me_after_1ns();
    fork
      #1 proc.kill();
    join_none
  endtask

  // This watchdog must not be a child of proc: process::kill() terminates the
  // target process and all of its subprocesses.
  initial begin
    #4;
    $write("*-* All Finished *-*\n");
    $finish;
  end

  always @(posedge clk) begin
    if (!b) begin
      proc = std::process::self();
      kill_me_after_1ns();
      b = 1;
    end
    else begin
      $stop;
    end
  end
endmodule
