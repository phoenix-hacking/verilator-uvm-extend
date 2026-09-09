// -*- Verilog -*-
// DESCRIPTION: Verilator: Full UVM HDL backdoor integration with clocked RTL
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

interface backdoor_bus (
    input bit clk
);
  bit enable;
  bit corrupt;
  bit write_memory;
  bit [30:0] data;
  bit [64:0] wide_data;
  int row = 2;
  int column = 7;
  logic [30:0] observed;
  logic [30:0] reflected;
  logic [64:0] memory_word;
endinterface

module backdoor_dut (
    backdoor_bus bus
);
  logic [34:4] state  /*verilator public*/  /*verilator forceable*/;
  wire [30:0] reflected  /*verilator public*/  /*verilator forceable*/;
  logic [66:2] memory[2:4][7:6]  /*verilator public*/;

  assign bus.observed = state;
  assign reflected = state ^ 31'h13579bdf;
  assign bus.reflected = reflected;
  assign bus.memory_word = memory[bus.row][bus.column];

  always @(posedge bus.clk) begin
    if (bus.enable) state <= bus.data ^ 31'(bus.corrupt);
    if (bus.write_memory) memory[bus.row][bus.column] <= bus.wide_data;
  end
endmodule

module t;
  import uvm_pkg::*;

  bit clk;
  always #5 clk = ~clk;
  backdoor_bus bus (clk);
  backdoor_dut dut (bus);

  class backdoor_test extends uvm_test;
    `uvm_component_utils(backdoor_test)
    virtual backdoor_bus vif;
    int reads;
    int deposits;
    int forces;
    int releases;
    int cycles;
    bit checked;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual backdoor_bus)::get(this, "", "vif", vif))
        `uvm_fatal("HDL_BACKDOOR", "missing DUT interface")
    endfunction

    function void check_value(string operation, logic [64:0] got, logic [64:0] expected);
      if (got !== expected)
        `uvm_fatal("HDL_BACKDOOR", $sformatf(
                   "%s value mismatch got=%h expected=%h", operation, got, expected))
    endfunction

    function void read_value(string path, logic [64:0] expected, int width);
      uvm_hdl_data_t value = '0;
      uvm_hdl_data_t mask = '1 >> (UVM_HDL_MAX_WIDTH - width);
      `checkd(uvm_hdl_read(path, value), 1)
      if ((value & mask) !== uvm_hdl_data_t'(expected))
        `uvm_fatal("HDL_BACKDOOR", $sformatf(
                   "%s value mismatch got=%h expected=%h", path, value & mask, expected))
      reads++;
    endfunction

    task clock_value(bit [30:0] value);
      @(negedge vif.clk);
      vif.enable = 1;
      vif.data = value;
      @(posedge vif.clk);
      #1;  // Observe the immediately following NBA result.
      cycles++;
    endtask

    virtual task run_phase(uvm_phase phase);
      bit [30:0] value;
      bit [30:0] deposited;
      bit [30:0] forced_value;
      uvm_hdl_data_t released_value_unused_upper;
      phase.raise_objection(this);
      vif.corrupt = $test$plusargs("BACKDOOR_CORRUPT_DUT");
      `checkd(uvm_hdl_check_path("t.dut.state"), 1)
      `checkd(uvm_hdl_check_path("$root.t.dut.state"), 1)
      `checkd(uvm_hdl_check_path("t.dut.reflected"), 1)
      `checkd(uvm_hdl_check_path("t.dut.missing"), 0)

      for (int iteration = 0; iteration < 8; iteration++) begin
        value = 31'h1020304 ^ (31'(iteration) * 31'h1020305);
        clock_value(value);
        read_value("t.dut.state", 65'(value), 31);
        check_value("clocked RTL", 65'(vif.observed), 65'(value));
        read_value("t.dut.reflected", 65'(value ^ 31'h13579bdf), 31);

        // Deposit reaches the RTL and lasts until the next procedural assignment.
        deposited = value ^ 31'h2468ace;
        `checkd(uvm_hdl_deposit("t.dut.state", uvm_hdl_data_t'(deposited)), 1)
        deposits++;
        read_value("t.dut.state", 65'(deposited), 31);
        #1;
        check_value("deposited RTL", 65'(vif.observed), 65'(deposited));
        check_value("deposited reflection", 65'(vif.reflected), 65'(deposited ^ 31'h13579bdf));
        clock_value(value + 1);
        read_value("t.dut.state", 65'(value + 1), 31);

        // A force holds through multiple changing clocked assignments.
        forced_value = value ^ 31'h555aaaa;
        `checkd(uvm_hdl_force("t.dut.state", uvm_hdl_data_t'(forced_value)), 1)
        forces++;
        for (int offset = 2; offset < 5; offset++) begin
          clock_value(value + 31'(offset));
          read_value("t.dut.state", 65'(forced_value), 31);
          check_value("forced RTL", 65'(vif.observed), 65'(forced_value));
        end
        released_value_unused_upper = '0;
        `checkd(uvm_hdl_release_and_read("t.dut.state", released_value_unused_upper), 1)
        releases++;
        check_value("released variable", 65'(released_value_unused_upper[30:0]), 65'(forced_value));
        clock_value(value + 5);
        read_value("t.dut.state", 65'(value + 5), 31);

        // A continuously driven wire resumes its driver after release.
        `checkd(uvm_hdl_force("t.dut.reflected", uvm_hdl_data_t'(deposited)), 1)
        forces++;
        read_value("t.dut.reflected", 65'(deposited), 31);
        clock_value(value + 6);
        read_value("t.dut.reflected", 65'(deposited), 31);
        `checkd(uvm_hdl_release("t.dut.reflected"), 1)
        releases++;
        #1;
        read_value("t.dut.reflected", 65'(31'((value + 6) ^ 31'h13579bdf)), 31);
        check_value("released wire", 65'(vif.reflected), 65'(31'((value + 6) ^ 31'h13579bdf)));
      end

      // Every word crosses two packed word boundaries and has nonzero indices.
      // Read back all earlier words after each deposit to detect aliasing.
      for (int row = 2; row <= 4; row++) begin
        for (int column = 7; column >= 6; column--) begin
          string path = $sformatf("t.dut.memory[%0d][%0d]", row, column);
          bit [64:0] wide = {1'b1, 32'(row * 113 + column), 32'(row + column * 131)};
          bit [64:0] deposited_wide = wide ^ 65'h0abcdef0123456789;
          @(negedge vif.clk);
          vif.enable = 0;
          vif.row = row;
          vif.column = column;
          vif.wide_data = wide;
          vif.write_memory = 1;
          @(posedge vif.clk);
          #1;
          cycles++;
          `checkd(uvm_hdl_check_path(path), 1)
          read_value(path, wide, 65);
          vif.write_memory = 0;
          `checkd(uvm_hdl_deposit(path, uvm_hdl_data_t'(deposited_wide)), 1)
          deposits++;
          #1;
          check_value("deposited memory", vif.memory_word, wide ^ 65'h0abcdef0123456789);
          for (int check_row = 2; check_row <= row; check_row++) begin
            for (int check_column = 7; check_column >= 6; check_column--) begin
              bit [64:0] expected;
              if (check_row == row && check_column < column) continue;
              expected = {1'b1, 32'(check_row * 113 + check_column),
                          32'(check_row + check_column * 131)} ^ 65'h0abcdef0123456789;
              read_value($sformatf("t.dut.memory[%0d][%0d]", check_row, check_column), expected,
                         65);
            end
          end
        end
      end
      phase.drop_objection(this);
    endtask

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      `checkd(reads, 115)
      `checkd(deposits, 14)
      `checkd(forces, 16)
      `checkd(releases, 16)
      `checkd(cycles, 62)
      checked = 1;
    endfunction
  endclass

  initial begin
    uvm_component component;
    backdoor_test completed;
    uvm_report_server reports;
    uvm_config_db#(virtual backdoor_bus)::set(null, "uvm_test_top", "vif", bus);
    uvm_root::get().set_finish_on_completion(0);
    run_test("backdoor_test");
    component = uvm_root::get().find("uvm_test_top");
    if (!$cast(completed, component) || completed == null || !completed.checked)
      $fatal(1, "backdoor check phase did not complete");
    reports = uvm_report_server::get_server();
    `checkd(reports.get_severity_count(UVM_ERROR), 0)
    `checkd(reports.get_severity_count(UVM_FATAL), 0)
    $display("** UVM HDL BACKDOOR PASSED **");
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
