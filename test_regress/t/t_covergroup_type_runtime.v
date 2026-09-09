// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  // Select the covergroup runtime in the generated model makefile.
  covergroup cg with function sample(bit value);
    cp: coverpoint value;
  endgroup
endmodule
