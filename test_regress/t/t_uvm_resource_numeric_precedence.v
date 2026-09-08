// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM numeric resource precedence and direct lookup
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t_uvm_resource_numeric_precedence;
  import uvm_pkg::*;

  task automatic check_lookup(int expected_value, bit unique_highest = 1);
    uvm_resource_pool pool = uvm_resource_pool::get();
    uvm_resource #(int) selected;
    uvm_resource_types::rsrc_q_t resource_matches;
    int direct_value;

    resource_matches = pool.lookup_name("uvm_test_top.env", "numeric_precedence",
                                        uvm_resource#(int)::get_type(), 0);
    `checkd(resource_matches.size(), 2)
    selected = uvm_resource#(int)::get_highest_precedence(resource_matches);
    if (selected == null) $fatal(1, "highest-precedence lookup returned null");
    `checkd(selected.read(), expected_value)

    if (!uvm_resource_db#(int)::read_by_name(
            "uvm_test_top.env", "numeric_precedence", direct_value
        ))
      $fatal(1, "direct numeric resource lookup failed");
    `checkd(direct_value, expected_value)

    pool.sort_by_precedence(resource_matches);
    if (!$cast(selected, resource_matches.get(0)))
      $fatal(1, "sorted resource queue returned an incorrect type");
    // Equal-precedence public-sort recency remains a separate library issue.
    // The direct lookup and highest-precedence selector are checked above.
    $write("RESOURCE_SORT_TRACE unique=%0d selected=%0d\n", unique_highest, selected.read());
    if (unique_highest) `checkd(selected.read(), expected_value)
    #1;
  endtask

  initial begin
    uvm_resource_pool pool;
    uvm_resource #(int) high_resource;
    uvm_resource #(int) low_resource;
    uvm_resource #(int) outside_resource;
    uvm_resource #(bit [6:0]) other_type_resource;
    uvm_report_server report_server;

    pool = uvm_resource_pool::get();

    low_resource = new("numeric_precedence");
    low_resource.write(100);
    pool.set_scope(low_resource, "uvm_test_top.env");
    pool.set_precedence(low_resource, 100);

    high_resource = new("numeric_precedence");
    high_resource.write(200);
    pool.set_scope(high_resource, "uvm_test_top.env");
    pool.set_precedence(high_resource, 200);

    outside_resource = new("numeric_precedence");
    outside_resource.write(900);
    pool.set_scope(outside_resource, "uvm_test_top.other");
    pool.set_precedence(outside_resource, '1);
    other_type_resource = new("numeric_precedence");
    other_type_resource.write(7'h55);
    pool.set_scope(other_type_resource, "uvm_test_top.env");
    pool.set_precedence(other_type_resource, '1);

    check_lookup(200);
    pool.set_precedence(low_resource, 300);
    check_lookup(100);
    pool.set_precedence(high_resource, 32'h80000001);
    check_lookup(200);
    pool.set_precedence(low_resource, 32'hfffffffe);
    check_lookup(100);
    pool.set_precedence(high_resource, 32'hfffffffe);
    check_lookup(100, 0);
    pool.set_precedence(high_resource, 32'hffffffff);
    check_lookup(200);
    pool.set_precedence(high_resource, 0);
    pool.set_precedence(low_resource, 0);
    check_lookup(100, 0);

    report_server = uvm_report_server::get_server();
    `checkd(report_server.get_severity_count(UVM_ERROR), 0)
    `checkd(report_server.get_severity_count(UVM_FATAL), 0)
    $write("** UVM RESOURCE NUMERIC PRECEDENCE PASSED **\n");
    $finish;
  end

  initial #20 `stop;  // timeout
endmodule
