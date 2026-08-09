// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM numeric resource precedence and portable lookup
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

  initial begin
    uvm_resource_pool pool;
    uvm_resource#(int) high_resource;
    uvm_resource#(int) low_resource;
    uvm_resource#(int) portable_resource;
    uvm_resource_types::rsrc_q_t matches;
    uvm_report_server report_server;
    int direct_value;
    bit direct_fixed;
    bit direct_xfail;

    pool = uvm_resource_pool::get();

    high_resource = new("numeric_precedence", "uvm_test_top.env");
    high_resource.write(200);
    high_resource.precedence = 200;
    pool.set(high_resource);

    low_resource = new("numeric_precedence", "uvm_test_top.env");
    low_resource.write(100);
    low_resource.precedence = 100;
    pool.set(low_resource);

    matches = pool.lookup_name(
        "uvm_test_top.env", "numeric_precedence",
        uvm_resource#(int)::get_type(), 0);
    `checkd(matches.size(), 2)

    portable_resource = uvm_resource#(int)::get_highest_precedence(matches);
    if (portable_resource == null)
      $fatal(1, "portable highest-precedence lookup returned null")
    `checkd(portable_resource.read(), 200)

    if (!uvm_resource_db#(int)::read_by_name(
            "uvm_test_top.env", "numeric_precedence", direct_value))
      $fatal(1, "direct numeric resource lookup failed")
    if (direct_value == 200) begin
      direct_fixed = 1'b1;
      $write("** UVM RESOURCE NUMERIC DIRECT FIXED **\n");
    end else if (direct_value == 100) begin
      direct_xfail = 1'b1;
      $write("** UVM RESOURCE NUMERIC DIRECT XFAIL (ACCELLERA 2020.3.1) **\n");
    end else begin
      $fatal(1, "direct numeric resource lookup returned %0d", direct_value);
    end
    if (!(direct_fixed ^ direct_xfail))
      $fatal(1, "numeric direct-path disposition was not exclusive")

    report_server = uvm_report_server::get_server();
    `checkd(report_server.get_severity_count(UVM_ERROR), 0)
    `checkd(report_server.get_severity_count(UVM_FATAL), 0)
    $write("** UVM RESOURCE NUMERIC PRECEDENCE PASSED **\n");
    $finish;
  end

  initial #20 `stop;  // timeout
endmodule
