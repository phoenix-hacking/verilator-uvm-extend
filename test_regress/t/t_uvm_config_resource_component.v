// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM config/resource DB and component-flow acceptance
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename

// verilator lint_off DECLFILENAME

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

interface config_resource_if;
  logic [7:0] token = 8'h00;
endinterface

module t;
  import uvm_pkg::*;

  config_resource_if active_bus();
  config_resource_if passive_bus();

  class component_cfg extends uvm_object;
    `uvm_object_utils(component_cfg)

    virtual config_resource_if vif;
    uvm_active_passive_enum active_mode;
    logic [7:0] drive_value;
    logic [7:0] expected_value;

    function new(string name = "component_cfg");
      super.new(name);
    endfunction
  endclass

  class resource_driver extends uvm_component;
    `uvm_component_utils(resource_driver)

    component_cfg cfg;
    bit configured;
    bit drove;
    bit connect_seen;
    bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(component_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "driver did not receive its typed config object")
      if (cfg == null || cfg.vif == null)
        `uvm_fatal("NOCFG", "driver received a null config object or VIF")
      configured = 1'b1;
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      connect_seen = 1'b1;
    endfunction

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      #1;
      cfg.vif.token = cfg.drive_value;
      drove = 1'b1;
      #2;
      phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      report_seen = 1'b1;
    endfunction
  endclass

  class resource_monitor extends uvm_component;
    `uvm_component_utils(resource_monitor)

    component_cfg cfg;
    bit configured;
    bit sampled;
    logic [7:0] observed;
    int depth_value;
    bit recency_exists;
    int recency_value;
    bit unmatched_exists;
    int initial_resource_value;
    bit isolated_resource_found;
    int isolated_resource_value;
    int updated_resource_value;
    bit connect_seen;
    bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(component_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "monitor did not receive its typed config object")
      if (cfg == null || cfg.vif == null)
        `uvm_fatal("NOCFG", "monitor received a null config object or VIF")
      if (!uvm_config_db#(int)::get(this, "", "depth_value", depth_value))
        `uvm_fatal("CONFIG", "hierarchical depth setting was not found")
      recency_exists = uvm_config_db#(int)::exists(this, "", "recency_value");
      if (recency_exists
          && !uvm_config_db#(int)::get(this, "", "recency_value", recency_value))
        `uvm_fatal("CONFIG", "exists succeeded but get failed for recency_value")
      unmatched_exists = uvm_config_db#(int)::exists(this, "", "unmatched_only");
      if (!uvm_resource_db#(int)::read_by_name(
              get_full_name(), "shared_resource", initial_resource_value, this))
        `uvm_fatal("RESOURCE", "shared resource was not visible")
      isolated_resource_found = uvm_resource_db#(int)::read_by_name(
          get_full_name(), "isolated_resource", isolated_resource_value, this);
      configured = 1'b1;
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      connect_seen = 1'b1;
    endfunction

    virtual task run_phase(uvm_phase phase);
      #2;
      observed = cfg.vif.token;
      sampled = 1'b1;
    endtask

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      report_seen = 1'b1;
    endfunction
  endclass

  class resource_agent extends uvm_agent;
    `uvm_component_utils(resource_agent)

    component_cfg cfg;
    resource_driver driver;
    resource_monitor monitor;
    bit connect_seen;
    bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(component_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "agent did not receive its typed config object")
      if (cfg == null)
        `uvm_fatal("NOCFG", "agent received a null config object")
      is_active = cfg.active_mode;
      uvm_config_db#(component_cfg)::set(this, "monitor", "cfg", cfg);
      monitor = resource_monitor::type_id::create("monitor", this);
      if (get_is_active() == UVM_ACTIVE) begin
        uvm_config_db#(component_cfg)::set(this, "driver", "cfg", cfg);
        driver = resource_driver::type_id::create("driver", this);
      end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (monitor == null || !monitor.connect_seen)
        `uvm_fatal("PHASEORDER", "agent connect preceded monitor connect")
      if (get_is_active() == UVM_ACTIVE
          && (driver == null || !driver.connect_seen))
        `uvm_fatal("PHASEORDER", "active-agent connect preceded driver connect")
      connect_seen = 1'b1;
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      if (monitor == null || !monitor.report_seen)
        `uvm_fatal("PHASEORDER", "agent report preceded monitor report")
      if (get_is_active() == UVM_ACTIVE
          && (driver == null || !driver.report_seen))
        `uvm_fatal("PHASEORDER", "active-agent report preceded driver report")
      report_seen = 1'b1;
    endfunction
  endclass

  class resource_env extends uvm_env;
    `uvm_component_utils(resource_env)

    component_cfg active_cfg;
    component_cfg passive_cfg;
    resource_agent active_agent;
    resource_agent passive_agent;
    bit connect_seen;
    bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(component_cfg)::get(this, "active_agent", "cfg", active_cfg))
        `uvm_fatal("NOCFG", "environment did not retrieve the active config handle")
      if (!uvm_config_db#(component_cfg)::get(this, "passive_agent", "cfg", passive_cfg))
        `uvm_fatal("NOCFG", "environment did not retrieve the passive config handle")
      uvm_config_db#(int)::set(this, "*", "depth_value", 202);
      active_agent = resource_agent::type_id::create("active_agent", this);
      passive_agent = resource_agent::type_id::create("passive_agent", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (active_agent == null || passive_agent == null
          || !active_agent.connect_seen || !passive_agent.connect_seen)
        `uvm_fatal("PHASEORDER", "environment connect preceded agent connect")
      connect_seen = 1'b1;
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      if (!active_agent.report_seen || !passive_agent.report_seen)
        `uvm_fatal("PHASEORDER", "environment report preceded agent report")
      report_seen = 1'b1;
    endfunction
  endclass

  class config_resource_test extends uvm_test;
    `uvm_component_utils(config_resource_test)

    resource_env env;
    int runtime_value;
    bit connect_seen;
    bit check_seen;
    bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      uvm_config_db#(int)::set(this, "env.active_agent.*", "recency_value", 301);
      uvm_config_db#(int)::set(this, "env.active_agent.*", "recency_value", 302);
      env = resource_env::type_id::create("env", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (env == null || !env.connect_seen)
        `uvm_fatal("PHASEORDER", "test connect preceded environment connect")
      connect_seen = 1'b1;
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
      int resource_value;
      int prior_runtime_value;
      super.start_of_simulation_phase(phase);

      if (!uvm_config_db#(int)::get(
              env.active_agent.monitor, "", "runtime_value", prior_runtime_value)
          || prior_runtime_value != 401)
        `uvm_fatal("PRECEDENCE", "build-time runtime baseline was not selected")
      uvm_config_db#(int)::set(
          env.active_agent.monitor, "", "runtime_value", 402);
      if (!uvm_config_db#(int)::exists(
              env.active_agent.monitor, "", "runtime_value"))
        `uvm_fatal("CONFIG", "runtime setting does not exist")
      if (!uvm_config_db#(int)::get(
              env.active_agent.monitor, "", "runtime_value", runtime_value))
        `uvm_fatal("CONFIG", "runtime setting could not be read")

      if (!uvm_resource_db#(int)::write_by_name(
              env.active_agent.monitor.get_full_name(),
              "shared_resource", 44, this))
        `uvm_fatal("RESOURCE", "write_by_name failed")
      if (!uvm_resource_db#(int)::read_by_name(
              env.active_agent.monitor.get_full_name(),
              "shared_resource", resource_value, this))
        `uvm_fatal("RESOURCE", "updated resource could not be read")
      env.active_agent.monitor.updated_resource_value = resource_value;
    endfunction

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (!connect_seen)
        `uvm_fatal("PHASEORDER", "connect phase sentinel did not fire")
      if (env == null || env.active_cfg == null || env.passive_cfg == null
          || env.active_agent == null || env.passive_agent == null
          || env.active_agent.monitor == null || env.passive_agent.monitor == null)
        `uvm_fatal("TOPOLOGY", "required environment/agent/monitor handle is null")
      if (env.active_agent.get_is_active() != UVM_ACTIVE
          || env.active_agent.driver == null)
        `uvm_fatal("ACTIVE", "active agent did not construct its driver")
      if (env.passive_agent.get_is_active() != UVM_PASSIVE
          || env.passive_agent.driver != null)
        `uvm_fatal("PASSIVE", "passive agent constructed a driver")
      if (env.active_cfg != env.active_agent.cfg
          || env.active_cfg != env.active_agent.driver.cfg
          || env.active_cfg != env.active_agent.monitor.cfg)
        `uvm_fatal("IDENTITY", "active config-object handle identity was not preserved")
      if (env.passive_cfg != env.passive_agent.cfg
          || env.passive_cfg != env.passive_agent.monitor.cfg)
        `uvm_fatal("IDENTITY", "passive config-object handle identity was not preserved")
      if (!env.active_agent.driver.configured
          || !env.active_agent.monitor.configured
          || !env.passive_agent.monitor.configured)
        `uvm_fatal("CONFIG", "typed config propagation did not complete")
      if (env.active_agent.monitor.depth_value != 101
          || env.passive_agent.monitor.depth_value != 101)
        `uvm_fatal("PRECEDENCE", "higher build-level config did not win")
      if (!env.active_agent.monitor.recency_exists
          || env.active_agent.monitor.recency_value != 302)
        `uvm_fatal("RECENCY", "same-depth last setting did not win")
      if (env.passive_agent.monitor.recency_exists)
        `uvm_fatal("SCOPE", "active-only recency setting leaked to passive scope")
      if (env.active_agent.monitor.unmatched_exists
          || env.passive_agent.monitor.unmatched_exists)
        `uvm_fatal("SCOPE", "unmatched config path leaked into a live component")
      if (runtime_value != 402)
        `uvm_fatal("PRECEDENCE", "runtime low-level config did not win")
      if (env.active_agent.monitor.initial_resource_value != 22)
        `uvm_fatal("RESOURCE", "name override did not beat later normal write")
      if (env.passive_agent.monitor.initial_resource_value != 11)
        `uvm_fatal("RESOURCE", "resource wildcard scope did not reach passive monitor")
      if (env.active_agent.monitor.updated_resource_value != 44)
        `uvm_fatal("RESOURCE", "write_by_name update was not visible")
      if (env.active_agent.monitor.isolated_resource_found)
        `uvm_fatal("RESOURCE", $sformatf(
            "isolated active resource leaked with value %0d",
            env.active_agent.monitor.isolated_resource_value))
      if (env.passive_agent.monitor.isolated_resource_found)
        `uvm_fatal("RESOURCE", $sformatf(
            "isolated passive resource leaked with value %0d",
            env.passive_agent.monitor.isolated_resource_value))
      if (!env.active_agent.driver.drove
          || !env.active_agent.monitor.sampled
          || !env.passive_agent.monitor.sampled)
        `uvm_fatal("VIF", "config-object VIF flow did not execute")
      if (env.active_agent.monitor.observed != env.active_cfg.expected_value
          || env.passive_agent.monitor.observed != env.passive_cfg.expected_value)
        `uvm_fatal("VIF", "monitor observed an incorrect VIF value")
      check_seen = 1'b1;
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      if (!env.report_seen)
        `uvm_fatal("PHASEORDER", "test report preceded environment report")
      if (!check_seen)
        `uvm_fatal("PHASEORDER", "report phase ran without check phase")
      report_seen = 1'b1;
    endfunction
  endclass

  component_cfg active_cfg_h;
  component_cfg passive_cfg_h;
  bit numeric_direct_fixed;
  bit numeric_direct_xfail;

  initial begin
    uvm_resource_pool pool;
    uvm_resource#(int) numeric_high;
    uvm_resource#(int) numeric_low;
    uvm_resource#(int) numeric_selected;
    uvm_resource_types::rsrc_q_t numeric_matches;
    int numeric_value;
    uvm_component top_component;
    config_resource_test top_test;
    uvm_report_server report_server;

    active_cfg_h = new("active_cfg");
    active_cfg_h.vif = active_bus;
    active_cfg_h.active_mode = UVM_ACTIVE;
    active_cfg_h.drive_value = 8'h5a;
    active_cfg_h.expected_value = 8'h5a;

    passive_bus.token = 8'h3c;
    passive_cfg_h = new("passive_cfg");
    passive_cfg_h.vif = passive_bus;
    passive_cfg_h.active_mode = UVM_PASSIVE;
    passive_cfg_h.drive_value = 8'h00;
    passive_cfg_h.expected_value = 8'h3c;

    uvm_config_db#(component_cfg)::set(
        null, "uvm_test_top.env.active_agent", "cfg", active_cfg_h);
    uvm_config_db#(component_cfg)::set(
        null, "uvm_test_top.env.passive_agent", "cfg", passive_cfg_h);
    uvm_config_db#(int)::set(null, "uvm_test_top.env.*", "depth_value", 101);
    uvm_config_db#(int)::set(
        null, "uvm_test_top.env.active_agent.monitor", "runtime_value", 401);
    uvm_config_db#(int)::set(
        null, "uvm_test_top.env.unmatched.*", "unmatched_only", 999);

    uvm_resource_db#(int)::set(
        "uvm_test_top.env.*", "shared_resource", 11);
    uvm_resource_db#(int)::set_override(
        "uvm_test_top.env.active_agent.*", "shared_resource", 22);
    uvm_resource_db#(int)::set(
        "uvm_test_top.env.active_agent.*", "shared_resource", 33);
    uvm_resource_db#(int)::set(
        "uvm_test_top.other.*", "isolated_resource", 77);

    pool = uvm_resource_pool::get();
    numeric_low = new("numeric_precedence", "uvm_test_top.env");
    numeric_low.write(100);
    pool.set(numeric_low);
    numeric_low.precedence = 100;
    numeric_high = new("numeric_precedence", "uvm_test_top.env");
    numeric_high.write(200);
    pool.set(numeric_high);
    numeric_high.precedence = 200;
    numeric_matches = pool.lookup_name(
        "uvm_test_top.env", "numeric_precedence",
        uvm_resource#(int)::get_type(), 0);
    numeric_selected = uvm_resource#(int)::get_highest_precedence(numeric_matches);
    if (numeric_selected == null || numeric_selected.read() != 200)
      $fatal(1, "portable highest-precedence resource lookup failed");
    if (!uvm_resource_db#(int)::read_by_name(
            "uvm_test_top.env", "numeric_precedence", numeric_value))
      $fatal(1, "direct numeric resource lookup failed");
    if (numeric_value == 200)
      numeric_direct_fixed = 1'b1;
    else if (numeric_value == 100) begin
      numeric_direct_xfail = 1'b1;
      $write("** UVM RESOURCE NUMERIC DIRECT XFAIL (ACCELLERA 2020.3.1) **\n");
    end else
      $fatal(1, "direct numeric resource lookup returned an unknown value");

    uvm_root::get().set_finish_on_completion(1'b0);
    run_test("config_resource_test");

    top_component = uvm_root::get().find("uvm_test_top");
    if (!$cast(top_test, top_component) || top_test == null)
      $fatal(1, "could not recover the completed UVM test");
    if (!top_test.check_seen || !top_test.report_seen)
      $fatal(1, "mandatory check/report sentinels did not fire");
    if (top_test.env.active_cfg != active_cfg_h
        || top_test.env.passive_cfg != passive_cfg_h)
      $fatal(1, "module-to-environment config handle identity was not preserved");
    if (!(numeric_direct_fixed ^ numeric_direct_xfail))
      $fatal(1, "numeric direct-path disposition was not exclusive");

    report_server = uvm_report_server::get_server();
    `checkd(report_server.get_severity_count(UVM_ERROR), 0)
    `checkd(report_server.get_severity_count(UVM_FATAL), 0)
    $write("** UVM CONFIG RESOURCE COMPONENT PASSED **\n");
    $finish;
  end

  initial #100 `stop;  // timeout
endmodule
