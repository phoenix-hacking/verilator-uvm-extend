// DESCRIPTION: Verilator: Covergroup type option initializers must be constant
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  covergroup cg(int weight_arg) with function sample (bit value);
    type_option.weight = weight_arg;
    cp: coverpoint value;
  endgroup
  cg instance_cov;
  initial instance_cov = new(3);
endmodule
