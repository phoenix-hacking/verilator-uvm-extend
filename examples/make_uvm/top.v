// DESCRIPTION: Verilator Example: Self-checking source-tree UVM test
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

`include "uvm_macros.svh"

module top;
  import uvm_pkg::*;

  logic [31:0] observed  /*verilator public_flat_rw*/ = 0;
  bit test_passed;

  class example_test extends uvm_test;
    `uvm_component_utils(example_test)

    int unsigned completed;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      int unsigned expected;
`ifndef UVM_NO_DPI
      uvm_hdl_data_t value_unused_upper;
`endif
      phase.raise_objection(this);
      for (int unsigned i = 0; i < 8; i++) begin
        expected = (i + 1) * 17;
        observed = expected;
        #1;
        if (observed != expected) `uvm_fatal("EXAMPLE_VALUE", "Timed value check failed")
`ifndef UVM_NO_DPI
        if (uvm_hdl_read("top.observed", value_unused_upper) != 1)
          `uvm_fatal("EXAMPLE_DPI", "HDL read failed")
        // HDL reads define only the bits belonging to the selected signal.
        if (value_unused_upper[31:0] != expected) `uvm_fatal("EXAMPLE_DPI", "HDL value mismatch")
`endif
        completed++;
        $display("UVM_EXAMPLE_ITEM index=%0d value=%0d", i, observed);
      end
      phase.drop_objection(this);
    endtask

    virtual function void check_phase(uvm_phase phase);
      uvm_report_server server = uvm_report_server::get_server();
      super.check_phase(phase);
      if (server.get_severity_count(UVM_ERROR) != 0 || server.get_severity_count(UVM_FATAL) != 0)
        `uvm_fatal("EXAMPLE_REPORT", "UVM reported an error")
      if (completed != 8) `uvm_fatal("EXAMPLE_COUNT", "Eight checked operations are required")
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      test_passed = 1;
    endfunction
  endclass

  initial run_test("example_test");

  // UVM's default fatal action calls $finish, which alone exits successfully.
  final begin
    uvm_report_server server;
    server = uvm_report_server::get_server();
    if (!test_passed || server.get_severity_count(
            UVM_ERROR
        ) != 0 || server.get_severity_count(
            UVM_FATAL
        ) != 0)
      $fatal(1, "UVM example did not complete successfully");
`ifdef UVM_NO_DPI
    $display("UVM_EXAMPLE_PASSED operations=8 dpi=0");
`else
    $display("UVM_EXAMPLE_PASSED operations=8 dpi=1");
`endif
  end
endmodule
