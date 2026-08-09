// DESCRIPTION: Verilator: Named activation cancellation-aware scheduler suspension
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  initial begin
    #1;
    $finish;
  end
endmodule
