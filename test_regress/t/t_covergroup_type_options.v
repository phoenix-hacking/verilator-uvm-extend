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

module t;
  covergroup merged_cov with function sample(bit value);
    type_option.merge_instances = 1;
    type_option.comment = "declared";
    point: coverpoint value {bins low = {0}; bins high = {1};}
  endgroup
  covergroup own_cov with function sample(bit value);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    point: coverpoint value {bins low = {0}; bins high = {1};}
  endgroup
  covergroup threshold_cov with function sample(bit value);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    point: coverpoint value {option.at_least = 2; bins low = {0}; bins high = {1};}
  endgroup
  merged_cov left_cov, right_cov, later_cov;
  own_cov left_own, right_own;
  threshold_cov left_threshold, right_threshold;
  int covered, total;
  real measured;

  function automatic void copy_type_options(ref type(merged_cov::type_option) destination,
                                             input type(merged_cov::type_option) source);
    destination = source;
  endfunction

  initial begin
    `checkd(merged_cov::type_option.weight, 1)
    `checkd(merged_cov::type_option.goal, 100)
    `checkd(merged_cov::type_option.merge_instances, 1)
    `checkd(merged_cov::type_option.comment, "declared")
    merged_cov::type_option.comment = "before construction";
    merged_cov::type_option.merge_instances = 0;
    merged_cov::type_option.weight = 0;
    `checkr(merged_cov::get_coverage(), 100.0)
    merged_cov::type_option.weight = 7;
    `checkr(merged_cov::get_coverage(), 0.0)
    left_cov = new();
    right_cov = new();
    `checkd(left_cov.type_option.comment, "before construction")
    `checkd(right_cov.type_option.merge_instances, 0)
    `checkd(right_cov.type_option.weight, 7)
    left_cov.sample(0);
    right_cov.sample(1);
    `checkr(merged_cov::get_coverage(), 50.0)
    `checkr(left_cov.get_inst_coverage(), 50.0)
    right_cov.type_option.merge_instances = 1;
    `checkd(left_cov.type_option.merge_instances, 1)
    measured = merged_cov::get_coverage(covered, total);
    `checkr(measured, 100.0)
    `checkd(covered, 2)
    `checkd(total, 2)
    `checkr(left_cov.get_inst_coverage(), 100.0)
    measured = left_cov.get_inst_coverage(covered, total);
    `checkr(measured, 100.0)
    `checkd(covered, 2)
    `checkd(total, 2)
    `checkr(right_cov.get_inst_coverage(), 100.0)
    later_cov = new();
    `checkd(later_cov.type_option.comment, "before construction")
    `checkr(later_cov.get_inst_coverage(), 100.0)
    merged_cov::type_option.merge_instances = 0;
    `checkr(later_cov.get_inst_coverage(), 0.0)
    left_own = new();
    right_own = new();
    left_own.sample(0);
    right_own.sample(1);
    `checkr(own_cov::get_coverage(), 100.0)
    `checkr(left_own.get_inst_coverage(), 50.0)
    `checkr(right_own.get_inst_coverage(), 50.0)
    measured = right_own.get_inst_coverage(covered, total);
    `checkr(measured, 50.0)
    `checkd(covered, 1)
    `checkd(total, 2)
    copy_type_options(own_cov::type_option, merged_cov::type_option);
    `checkd(own_cov::type_option.comment, "before construction")
    `checkd(own_cov::type_option.weight, 7)
    `checkr(own_cov::get_coverage(), 50.0)
    own_cov::type_option = merged_cov::type_option;
    own_cov::type_option.merge_instances = 1;
    `checkd(merged_cov::type_option.merge_instances, 0)
    `checkr(own_cov::get_coverage(), 100.0)
    left_threshold = new();
    right_threshold = new();
    left_threshold.sample(0);
    `checkr(threshold_cov::get_coverage(), 0.0)
    right_threshold.sample(0);
    `checkr(threshold_cov::get_coverage(), 50.0)
    `checkr(left_threshold.get_inst_coverage(), 0.0)
    left_threshold.sample(1);
    right_threshold.sample(1);
    measured = threshold_cov::get_coverage(covered, total);
    `checkr(measured, 100.0)
    `checkd(covered, 2)
    `checkd(total, 2)
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
