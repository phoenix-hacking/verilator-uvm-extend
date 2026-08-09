// DESCRIPTION: Verilator: Object-qualified named-task disable diagnostics
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

class worker_c;
  task run();
  endtask
endclass

module t;
  initial begin
    automatic worker_c worker = new;
    automatic int scalar = 0;
    disable worker.missing;
    disable scalar.missing;
  end
endmodule
