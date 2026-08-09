// DESCRIPTION: Verilator: Explicit class-member selects count as member reads and writes
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d (%s !== %s)\n", `__FILE__,`__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while(0);
// verilog_format: on

module t;

  class member_box;
    int read_value = 11;
    int write_value;
    int read_write_value = 31;
    int second_read_value = 41;
  endclass

  initial begin
    automatic member_box obj;
    automatic int got;
    automatic int sum;

    obj = new;
    sum = 0;

    got = obj.read_value;
    `checkd(got, 11);
    sum = sum + got;

    obj.write_value = 21;
    got = obj.write_value;
    `checkd(got, 21);
    sum = sum + got;

    obj.read_write_value = obj.read_write_value + 1;
    got = obj.read_write_value;
    `checkd(got, 32);
    sum = sum + got;

    got = obj.second_read_value;
    `checkd(got, 41);
    sum = sum + got;

    `checkd(sum, 105);
    $write("*-* CLASS MEMBER SELECT USAGE PASSED *-*\n");
    $finish;
  end
endmodule
