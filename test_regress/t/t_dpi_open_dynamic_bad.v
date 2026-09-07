// DESCRIPTION: Verilator: Reject dynamic actuals to DPI output open arrays
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  import "DPI-C" function void invalid_output(output int values[]);
  int dynamic_values[];
  int queue_values[$];
  initial begin
    dynamic_values = new[3];
    queue_values = '{1, 2, 3};
    invalid_output(dynamic_values);
    invalid_output(queue_values);
  end
endmodule
