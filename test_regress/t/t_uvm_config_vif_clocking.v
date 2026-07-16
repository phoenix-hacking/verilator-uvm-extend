// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM config DB virtual-interface clocking flow
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename

// verilator lint_off DECLFILENAME
// The clocking-block members are consumed through typed virtual modports.
// verilator lint_off UNUSEDSIGNAL

interface config_vif_if (
    input logic clk
);
  logic valid = 1'b0;
  logic [6:0] data = '0;

  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output valid;
    output data;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step output #0;
    input valid;
    input data;
  endclocking

  modport driver_mp(clocking driver_cb);
  modport monitor_mp(clocking monitor_cb);
endinterface

module t;
  import uvm_pkg::*;

  logic clk;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  config_vif_if bus (.clk(clk));

  class vif_driver extends uvm_component;
    `uvm_component_utils(vif_driver)

    virtual config_vif_if.driver_mp vif;
    bit configured;
    int drives;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual config_vif_if.driver_mp)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "driver virtual interface was not configured")
      configured = 1'b1;
    endfunction

    task drive(logic [6:0] value);
      vif.driver_cb.valid <= 1'b1;
      vif.driver_cb.data <= value;
      drives++;
    endtask

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);

      @(vif.driver_cb);
      drive(7'h13);
      @(vif.driver_cb);
      drive(7'h2d);
      @(vif.driver_cb);
      drive(7'h5b);

      // The monitor's input clocking block samples the third transfer before
      // this output clocking block deasserts valid on the same clock edge.
      @(vif.driver_cb);
      vif.driver_cb.valid <= 1'b0;
      vif.driver_cb.data <= '0;

      // Leave another complete clock for the monitor task and UVM scheduler
      // to settle before ending the run phase.
      @(vif.driver_cb);
      phase.drop_objection(this);
    endtask
  endclass

  class vif_monitor extends uvm_component;
    `uvm_component_utils(vif_monitor)

    virtual config_vif_if.monitor_mp vif;
    bit configured;
    int edges;
    int samples;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual config_vif_if.monitor_mp)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "monitor virtual interface was not configured")
      configured = 1'b1;
    endfunction

    virtual task run_phase(uvm_phase phase);
      while (edges < 5) begin
        @(vif.monitor_cb);
        edges++;
        case (edges)
          1: begin
            if (vif.monitor_cb.valid || vif.monitor_cb.data != '0)
              `uvm_fatal("SAMPLE", "clocking input did not preserve the initial value")
          end
          2: begin
            if (!vif.monitor_cb.valid || vif.monitor_cb.data != 7'h13)
              `uvm_fatal("SAMPLE", "first clocking sample was incorrect")
            samples++;
          end
          3: begin
            if (!vif.monitor_cb.valid || vif.monitor_cb.data != 7'h2d)
              `uvm_fatal("SAMPLE", "second clocking sample was incorrect")
            samples++;
          end
          4: begin
            if (!vif.monitor_cb.valid || vif.monitor_cb.data != 7'h5b)
              `uvm_fatal("SAMPLE", "third clocking sample was incorrect")
            samples++;
          end
          5: begin
            if (vif.monitor_cb.valid || vif.monitor_cb.data != '0)
              `uvm_fatal("SAMPLE", "clocking input did not observe the deasserted value")
          end
          default: `uvm_fatal("SAMPLE", "unexpected clocking event")
        endcase
      end
    endtask
  endclass

  class vif_env extends uvm_env;
    `uvm_component_utils(vif_env)

    vif_driver driver;
    vif_monitor monitor;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      driver = vif_driver::type_id::create("driver", this);
      monitor = vif_monitor::type_id::create("monitor", this);
    endfunction
  endclass

  class vif_test extends uvm_test;
    `uvm_component_utils(vif_test)

    vif_env env;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = vif_env::type_id::create("env", this);
    endfunction

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (!env.driver.configured || !env.monitor.configured)
        `uvm_fatal("CONFIG", "virtual-interface config DB propagation did not complete")
      if (env.driver.drives != 3)
        `uvm_fatal("DRIVE", "driver did not issue all three transfers")
      if (env.monitor.samples != 3)
        `uvm_fatal("SAMPLE", "monitor did not sample all three transfers")
      if (env.monitor.edges != 5)
        `uvm_fatal("SAMPLE", "monitor did not observe all five clocking events")
    endfunction
  endclass

  initial begin
    uvm_report_server report_server;

    uvm_config_db#(virtual config_vif_if.driver_mp)::set(
        null, "uvm_test_top.env.driver", "vif", bus.driver_mp);
    uvm_config_db#(virtual config_vif_if.monitor_mp)::set(
        null, "uvm_test_top.env.monitor", "vif", bus.monitor_mp);
    uvm_root::get().set_finish_on_completion(1'b0);
    run_test("vif_test");

    report_server = uvm_report_server::get_server();
    if (report_server.get_severity_count(UVM_ERROR) != 0
        || report_server.get_severity_count(UVM_FATAL) != 0)
      $fatal(1, "UVM report server recorded errors or fatals");
    $write("** UVM CONFIG VIF CLOCKING PASSED **\n");
    $finish;
  end

  initial begin
    #100;
    $fatal(1, "UVM virtual-interface clocking test timed out");
  end
endmodule
