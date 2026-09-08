// DESCRIPTION: Verilator: Weighted covergroup instance coverage
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// IEEE 1800-2017 19.11 weights coverage items, not their bin counts.
// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while(0);
`define checkr(gotv,expv) do if ((gotv) != (expv)) begin $write("%%Error: %s:%0d: got=%f exp=%f\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class weighted_fixture;
  covergroup plain_cov with function sample (bit [6:0] opcode, bit [14:0] address);
    option.per_instance = 1;
    cp_op: coverpoint opcode {option.weight = 3; bins zero = {0}; bins high = {127};}
    cp_addr: coverpoint address {option.weight = 1; bins addresses[] = {1, 3, 5, 7};}
  endgroup

  covergroup mixed_cov with function sample (bit [6:0] opcode, bit [14:0] address, bit extra);
    option.per_instance = 1;
    cp_op: coverpoint opcode {bins zero = {0}; bins high = {127};}
    cp_addr: coverpoint address {
      bins one = {1}; bins three = {3}; bins five = {5}; bins seven = {7};
    }
    cp_extra: coverpoint extra {bins zero = {0}; bins one = {1};}
    op_addr: cross cp_op, cp_addr;
  endgroup

  covergroup legacy_cov with function sample (bit [6:0] opcode, bit [14:0] address);
    cp_op: coverpoint opcode {bins zero = {0}; bins high = {127};}
    cp_addr: coverpoint address {bins addresses[] = {1, 3, 5, 7};}
    op_addr: cross cp_op, cp_addr{option.weight = 2;}
  endgroup

  covergroup implicit_cov(int weight_arg) with function sample (bit [6:0] opcode);
    option.weight = weight_arg;
    coverpoint opcode {option.weight = weight_arg; bins zero = {0}; bins high = {127};}
    ignored: coverpoint opcode {ignore_bins all = {[0 : 127]};}
  endgroup

  covergroup empty_cov;
  endgroup

  function new();
    plain_cov = new();
    mixed_cov = new();
    empty_cov = new();
    legacy_cov = new();
    implicit_cov = new(3);
  endfunction

  function void sample (bit [6:0] op, bit [14:0] addr, bit ex);
    plain_cov.sample(op, addr);
    mixed_cov.sample(op, addr, ex);
    legacy_cov.sample(op, addr);
    implicit_cov.sample(op);
  endfunction
endclass

module t;
  weighted_fixture left_cov;
  weighted_fixture right_cov;

  initial begin
    left_cov = new();
    right_cov = new();
    `checkd(left_cov.plain_cov.option.weight, 1)
    `checkd(left_cov.plain_cov.cp_op.option.weight, 3)
    `checkd(left_cov.mixed_cov.cp_extra.option.weight, 1)
    `checkd(left_cov.implicit_cov.option.weight, 3)
    `checkd(left_cov.implicit_cov.opcode.option.weight, 3)
    `checkr(left_cov.plain_cov.get_inst_coverage(), 0.0)
    `checkr(right_cov.plain_cov.get_inst_coverage(), 0.0)

    left_cov.sample(0, 1, 0);
    `checkr(left_cov.plain_cov.get_inst_coverage(), 43.75)
    left_cov.plain_cov.option.weight = 0;
    `checkr(left_cov.plain_cov.get_inst_coverage(), 43.75)
    left_cov.plain_cov.option.weight = 1;
    `checkr(left_cov.mixed_cov.get_inst_coverage(), 34.375)
    `checkr(left_cov.legacy_cov.get_inst_coverage(), 25.0)
    `checkr(left_cov.implicit_cov.get_inst_coverage(), 50.0)
    `checkr(right_cov.plain_cov.get_inst_coverage(), 0.0)
    `checkr(right_cov.mixed_cov.get_inst_coverage(), 0.0)

    left_cov.plain_cov.cp_op.option.weight = 1;
    `checkr(left_cov.plain_cov.get_inst_coverage(), 37.5)
    right_cov.sample(127, 7, 1);
    `checkr(right_cov.plain_cov.get_inst_coverage(), 43.75)
    `checkr(left_cov.plain_cov.get_inst_coverage(), 37.5)

    left_cov.sample(127, 3, 1);
    `checkr(left_cov.plain_cov.get_inst_coverage(), 75.0)
    `checkr(left_cov.mixed_cov.get_inst_coverage(), 68.75)
    `checkr(right_cov.mixed_cov.get_inst_coverage(), 34.375)
    `checkr(left_cov.legacy_cov.get_inst_coverage(), 50.0)
    left_cov.mixed_cov.op_addr.option.weight = 5;
    `checkr(left_cov.mixed_cov.get_inst_coverage(), 46.875)
    `checkr(right_cov.mixed_cov.get_inst_coverage(), 34.375)
    left_cov.mixed_cov.cp_op.option.weight = 0;
    left_cov.mixed_cov.cp_addr.option.weight = 0;
    left_cov.mixed_cov.cp_extra.option.weight = 0;
    `checkr(left_cov.mixed_cov.get_inst_coverage(), 25.0)
    left_cov.mixed_cov.op_addr.option.weight = 0;
    `checkr(left_cov.mixed_cov.get_inst_coverage(), 0.0)
    left_cov.implicit_cov.opcode.option.weight = 0;
    `checkr(left_cov.implicit_cov.get_inst_coverage(), 0.0)

    left_cov.plain_cov.cp_op.option.weight = 0;
    `checkr(left_cov.plain_cov.get_inst_coverage(), 50.0)
    left_cov.plain_cov.cp_addr.option.weight = 0;
    `checkr(left_cov.plain_cov.get_inst_coverage(), 0.0)
    left_cov.plain_cov.option.weight = 0;
    `checkr(left_cov.plain_cov.get_inst_coverage(), 100.0)
    left_cov.plain_cov.option.weight = 1;
    left_cov.plain_cov.cp_op.option.weight = 3;
    left_cov.plain_cov.cp_addr.option.weight = 1;
    `checkr(left_cov.plain_cov.get_inst_coverage(), 87.5)

    `checkr(left_cov.empty_cov.get_inst_coverage(), 0.0)
    left_cov.empty_cov.option.weight = 0;
    `checkr(left_cov.empty_cov.get_inst_coverage(), 100.0)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
