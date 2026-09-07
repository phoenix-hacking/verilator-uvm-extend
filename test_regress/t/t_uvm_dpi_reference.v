// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM scoreboard with a stateful C DPI reference model
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename
// verilator lint_off DECLFILENAME

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define checks(gotv,expv) do if ((gotv) != (expv)) begin $write("%%Error: %s:%0d:  got=%s exp=%s\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

interface reference_bus (
    input bit clk
);
  bit reset;
  bit valid;
  bit last;
  bit lane;
  bit corrupt;
  byte unsigned data;
  bit [30:0] checksum[2];
endinterface

module reference_dut (
    reference_bus bus
);
  always @(posedge bus.clk) begin
    if (bus.reset) bus.checksum[bus.lane] <= 0;
    else if (bus.valid)
      bus.checksum[bus.lane] <= ((bus.checksum[bus.lane] << 5)
                                + bus.checksum[bus.lane] + 31'(bus.data))
                               ^ 31'(bus.corrupt);
  end
endmodule

module t;
  import uvm_pkg::*;

  import "DPI-C" function chandle dpi_reference_new(input string name);
  import "DPI-C" function string dpi_reference_name(input chandle handle);
  import "DPI-C" function int dpi_reference_reset(input chandle handle);
  import "DPI-C" function int dpi_reference_step(
    input chandle handle,
    input int count,
    input byte unsigned bytes[],
`ifdef DPI_REFERENCE_DYNAMIC
    inout int unsigned expected[]
`else
    output int unsigned expected[]
`endif
  );
  import "DPI-C" function int dpi_reference_delete(input chandle handle);
  import "DPI-C" function int dpi_reference_live();

  bit clk;
  always #5 clk = ~clk;
  reference_bus bus (clk);
  reference_dut dut (bus);

  class observed_packet extends uvm_sequence_item;
    `uvm_object_utils(observed_packet)
    bit reset;
    bit lane;
    byte unsigned bytes[];
    int unsigned results[];

    function new(string name = "observed_packet");
      super.new(name);
    endfunction
  endclass

  class reference_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(reference_scoreboard)
    uvm_analysis_imp #(observed_packet, reference_scoreboard) input_export;
    chandle models[2];
    int packets;
    int samples;
    int resets;
    bit checked;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
      input_export = new("input_export", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      foreach (models[lane]) begin
        string name = $sformatf("model_%0d", lane);
        models[lane] = dpi_reference_new(name);
        if (models[lane] == null) `uvm_fatal("DPI_MODEL", "reference allocation failed")
        `checks(dpi_reference_name(models[lane]), name)
      end
      if (models[0] == models[1]) `uvm_fatal("DPI_MODEL", "reference handles alias")
      `checkd(dpi_reference_live(), 2)
    endfunction

    virtual function void write(observed_packet packet);
`ifdef DPI_REFERENCE_DYNAMIC
      byte unsigned bytes[];
      int unsigned expected[];
`else
      byte unsigned bytes[31];
      int unsigned expected[31];
`endif
      if (packet.reset) begin
        `checkd(dpi_reference_reset(models[packet.lane]), 0)
        `checkd(packet.results.size(), 1)
        `checkd(packet.results[0], 0)
        resets++;
        return;
      end
      if (packet.bytes.size() > 31) `uvm_fatal("DPI_MODEL", "packet exceeds the reference buffer")
`ifdef DPI_REFERENCE_DYNAMIC
      bytes = packet.bytes;
      expected = new[packet.bytes.size()];
`else
      foreach (packet.bytes[i]) bytes[i] = packet.bytes[i];
`endif
      `checkd(packet.results.size(), packet.bytes.size())
      `checkd(dpi_reference_step(models[packet.lane], packet.bytes.size(), bytes, expected),
              packet.bytes.size())
      foreach (packet.results[i]) begin
        if (packet.results[i] != expected[i])
          `uvm_fatal("DPI_SCOREBOARD", $sformatf(
                     "checksum mismatch lane=%0d sample=%0d got=%0d expected=%0d",
                     packet.lane,
                     i,
                     packet.results[i],
                     expected[i]
                     ))
        samples++;
      end
      packets++;
    endfunction

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      `checkd(packets, 24)
      `checkd(samples, 360)
      `checkd(resets, 8)
      foreach (models[lane]) begin
        `checkd(dpi_reference_delete(models[lane]), 0)
        models[lane] = null;
      end
      `checkd(dpi_reference_live(), 0)
      checked = 1;
    endfunction
  endclass

  class reference_monitor extends uvm_monitor;
    `uvm_component_utils(reference_monitor)
    virtual reference_bus vif;
    uvm_analysis_port #(observed_packet) output_port;
    byte unsigned bytes[$];
    int unsigned results[$];

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
      output_port = new("output_port", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        #1;  // Observe the DUT after its nonblocking assignment commits.
        if (vif.reset || vif.valid) begin
          if (vif.reset) begin
            `checkd(bytes.size(), 0)
            results.push_back(int'(vif.checksum[vif.lane]));
          end
          else begin
            bytes.push_back(vif.data);
            results.push_back(int'(vif.checksum[vif.lane]));
          end
          if (vif.reset || vif.last) begin
            observed_packet packet = observed_packet::type_id::create("observed");
            packet.lane = vif.lane;
            packet.reset = vif.reset;
            packet.bytes = bytes;
            packet.results = results;
            output_port.write(packet);
            bytes.delete();
            results.delete();
          end
        end
      end
    endtask
  endclass

  class reference_test extends uvm_test;
    `uvm_component_utils(reference_test)
    virtual reference_bus vif;
    reference_scoreboard scoreboard;
    reference_monitor monitor;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual reference_bus)::get(this, "", "vif", vif))
        `uvm_fatal("DPI_VIF", "missing reference bus")
      scoreboard = reference_scoreboard::type_id::create("scoreboard", this);
      monitor = reference_monitor::type_id::create("monitor", this);
      monitor.vif = vif;
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      monitor.output_port.connect(scoreboard.input_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
      int lengths[3] = '{1, 13, 31};
      phase.raise_objection(this);
      for (int epoch = 0; epoch < 4; epoch++) begin
        for (int lane = 0; lane < 2; lane++) begin
          @(negedge vif.clk);
          vif.lane = 1'(lane);
          vif.reset = 1;
          vif.valid = 0;
          vif.last = 0;
        end
        foreach (lengths[p]) begin
          for (int lane = 0; lane < 2; lane++) begin
            for (int i = 0; i < lengths[p]; i++) begin
              @(negedge vif.clk);
              vif.reset = 0;
              vif.valid = 1;
              vif.lane = 1'(lane);
              vif.last = (i == lengths[p] - 1);
              vif.data = 8'((epoch * 37 + lane * 113 + p * 17 + i * 19) ^ (i << 3));
              vif.corrupt = $test$plusargs("DPI_CORRUPT_DUT") && epoch == 0 && lane == 1 &&
                  p == 1 && i == 3;
            end
          end
        end
      end
      @(negedge vif.clk);
      vif.valid = 0;
      vif.last = 0;
      phase.drop_objection(this);
    endtask
  endclass

  initial begin
    reference_test completed;
    uvm_component component;
    uvm_report_server reports;
    byte unsigned known_bytes[3:5];
    int unsigned known_results[7:5];
`ifdef DPI_REFERENCE_DYNAMIC
    byte unsigned empty_bytes[];
    int unsigned empty_results[];
`endif

    uvm_config_db#(virtual reference_bus)::set(null, "uvm_test_top", "vif", bus);
    uvm_root::get().set_finish_on_completion(0);
    run_test("reference_test");
    component = uvm_root::get().find("uvm_test_top");
    if (!$cast(completed, component) || completed == null || !completed.scoreboard.checked)
      $fatal(1, "scoreboard check phase did not complete");
    reports = uvm_report_server::get_server();
    `checkd(reports.get_severity_count(UVM_ERROR), 0)
    `checkd(reports.get_severity_count(UVM_FATAL), 0)

    // Hand-derived vectors check the C oracle, array direction, and nonzero bounds.
    known_bytes[3] = 1;
    known_bytes[4] = 2;
    known_bytes[5] = 255;
    // Exercise zero-length calls and repeated independent model lifetimes.
    for (int iteration = 0; iteration < 8; iteration++) begin
      string name;
      chandle handle;
      name = $sformatf("recreated_%0d", iteration);
      handle = dpi_reference_new(name);
      if (handle == null) `stop;
      `checks(dpi_reference_name(handle), name)
`ifdef DPI_REFERENCE_DYNAMIC
      `checkd(dpi_reference_step(handle, 0, empty_bytes, empty_results), 0)
`endif
      `checkd(dpi_reference_step(handle, 0, known_bytes, known_results), 0)
      `checkd(dpi_reference_step(handle, 4, known_bytes, known_results), -3)
      `checkd(dpi_reference_step(handle, 3, known_bytes, known_results), 3)
      `checkd(known_results[7], 1)
      `checkd(known_results[6], 35)
      `checkd(known_results[5], 1410)
      `checkd(dpi_reference_live(), 1)
      `checkd(dpi_reference_delete(handle), 0)
      handle = null;
      `checkd(dpi_reference_live(), 0)
    end
    `checkd(dpi_reference_reset(null), -1)
    `checkd(dpi_reference_delete(null), -1)
    `checks(dpi_reference_name(null), "")
    $write("** UVM DPI REFERENCE PASSED **\n");
    $finish;
  end

  initial #10000 `stop;
endmodule
