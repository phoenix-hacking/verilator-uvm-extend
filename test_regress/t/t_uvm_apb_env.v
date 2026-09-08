// -*- Verilog -*-
// DESCRIPTION: Verilator: Active/passive UVM APB environment with clocking and reset
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename.
// APB transfer oracles: Arm IHI 0024D sections 3.1-3.4 and 4.1.

interface apb_if (
    input logic clk
);
  logic reset_n = 0;
  logic sel = 0;
  logic enable = 0;
  logic write = 0;
  logic [7:0] addr = 0;
  logic [31:0] wdata = 0;
  logic [3:0] strb = 0;
  logic ready;
  logic error;
  logic [31:0] rdata;

  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output reset_n, sel, enable, write, addr, wdata, strb;
    input ready, error, rdata;
  endclocking
  clocking monitor_cb @(posedge clk);
    default input #1step output #0;
    input reset_n, sel, enable, write, addr, wdata, strb, ready, error, rdata;
  endclocking
  modport driver_mp(clocking driver_cb);
  modport monitor_mp(clocking monitor_cb);

  function automatic void protocol_error(string rule);
    // The driver requires a success sentinel on every positive run and this
    // exact assertion marker on each deliberately corrupted negative run.
    $display("APB_ASSERTION %s", rule);
    $finish;
  endfunction

  // Setup lasts one cycle; request fields persist through a stalled access.
  assert property (@(posedge clk) disable iff (!reset_n)
                   sel && !enable |=> sel && enable
                   && $stable(
      {addr, write, wdata, strb}
  ))
  else protocol_error("setup");
  assert property (@(posedge clk) disable iff (!reset_n)
                   sel && enable && !ready |=> sel && enable
                   && $stable(
      {addr, write, wdata, strb}
  ))
  else protocol_error("wait");
  assert property (@(posedge clk) disable iff (!reset_n) enable |-> sel)
  else protocol_error("select");
  assert property (@(posedge clk) disable iff (!reset_n) sel && !write |-> strb == 0)
  else protocol_error("strobe");
endinterface

// Sixteen byte-addressed RW registers. Errors leave registers unchanged; this
// behavior is the fixture's register contract, not an APB requirement.
module apb_regs (
    apb_if bus
);
  logic [31:0] words[16];
  int unsigned remaining;
  bit corrupt;

  initial corrupt = $test$plusargs("APB_CORRUPT_DUT");
  assign bus.ready = bus.sel && bus.enable && remaining == 0;
  assign bus.error = bus.ready && (bus.addr >= 64 || bus.addr[1:0] != 0);
  assign bus.rdata = (bus.addr < 64 ? words[bus.addr[5:2]] : 32'hbad0bad0)
                    ^ (corrupt ? 32'h1 : 32'h0);

  always @(posedge bus.clk or negedge bus.reset_n) begin
    if (!bus.reset_n) begin
      for (int i = 0; i < 16; i++) words[i] <= 32'ha5000000 + 32'(i);
      remaining <= 0;
    end
    else if (bus.sel && !bus.enable) begin
      remaining <= 32'(bus.addr[5:2]) % 3;
    end
    else if (bus.sel && bus.enable) begin
      if (remaining != 0) remaining <= remaining - 1;
      else if (bus.write && !bus.error)
        for (int i = 0; i < 4; i++)
        if (bus.strb[i]) words[bus.addr[5:2]][i*8+:8] <= bus.wdata[i*8+:8];
    end
  end
endmodule

module t;
  import uvm_pkg::*;
  bit clk;
  always #5 clk = !clk;
  apb_if bus (clk);
  apb_regs dut (bus);

  class apb_item extends uvm_sequence_item;
    `uvm_object_utils(apb_item)
    bit write;
    bit [7:0] addr;
    bit [31:0] data;
    bit [3:0] strb;
    bit error;
    bit reset;
    bit abort_transfer;
    int unsigned waits;
    function new(string name = "apb_item");
      super.new(name);
    endfunction
  endclass

  class apb_config extends uvm_object;
    `uvm_object_utils(apb_config)
    uvm_active_passive_enum mode = UVM_ACTIVE;
    virtual apb_if.driver_mp driver_vif;
    virtual apb_if.monitor_mp monitor_vif;
    function new(string name = "apb_config");
      super.new(name);
    endfunction
  endclass

  class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)
    virtual apb_if.driver_mp vif;
    int completed;
    int aborted;
    int aligned_requests;
    int immediate_requests;
    time last_clock;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task tick();
      @(vif.driver_cb);
      last_clock = $time;
    endtask
    task reset_bus();
      vif.driver_cb.reset_n <= 0;
      vif.driver_cb.sel <= 0;
      vif.driver_cb.enable <= 0;
      repeat (2) tick();
      vif.driver_cb.reset_n <= 1;
      tick();
    endtask
    virtual task run_phase(uvm_phase phase);
      tick();
      reset_bus();
      forever begin
        apb_item req;
        apb_item rsp;
        seq_item_port.get_next_item(req);
        // An off-edge clocking output drive is scheduled for the next clock.
        // Align first so setup and enable cannot both be driven on that edge.
        // Requests arriving on the completion edge can still run back-to-back.
        if ($time != last_clock) begin
          tick();
          aligned_requests++;
        end
        else immediate_requests++;
        rsp = apb_item::type_id::create("response");
        rsp.set_id_info(req);
        rsp.addr = req.addr;
        rsp.write = req.write;
        rsp.strb = req.strb;
        vif.driver_cb.sel <= 1;
        vif.driver_cb.enable <= 0;
        vif.driver_cb.addr <= req.addr;
        vif.driver_cb.write <= req.write;
        vif.driver_cb.wdata <= req.data;
        vif.driver_cb.strb <= req.write ? req.strb : 4'b0;
        if ($test$plusargs("APB_CORRUPT_STROBE")) vif.driver_cb.strb <= 1;
        tick();
        vif.driver_cb.enable <= 1;
        if ($test$plusargs("APB_CORRUPT_SETUP")) vif.driver_cb.addr <= req.addr ^ 8'h04;
        if ($test$plusargs("APB_CORRUPT_SELECT")) vif.driver_cb.sel <= 0;
        do begin
          tick();
          if (!vif.driver_cb.ready) rsp.waits++;
          if (!vif.driver_cb.ready && $test$plusargs("APB_CORRUPT_WAIT"))
            vif.driver_cb.addr <= req.addr ^ 8'h08;
          if (req.abort_transfer) begin
            if (vif.driver_cb.ready)
              `uvm_fatal("APB_ABORT", "reset injection did not interrupt a stalled access")
            reset_bus();
            rsp.abort_transfer = 1;
            aborted++;
            break;
          end
        end while (!vif.driver_cb.ready);
        if (!rsp.abort_transfer) begin
          rsp.error = vif.driver_cb.error;
          rsp.data = req.write ? req.data : vif.driver_cb.rdata;
          completed++;
          $display("APB_TRACE %0d %0h %0h %0h %0d %0d", req.write, req.addr, rsp.data,
                   req.write ? req.strb : 4'b0, rsp.error, rsp.waits);
        end
        vif.driver_cb.sel <= 0;
        vif.driver_cb.enable <= 0;
        seq_item_port.item_done(rsp);
        // A new item may start immediately, preserving PSEL across transfers.
      end
    endtask
  endclass

  class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    virtual apb_if.monitor_mp vif;
    uvm_analysis_port #(apb_item) observed;
    int completed;
    int aborted;
    int resets;
    int back_to_back;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      observed = new("observed", this);
    endfunction
    virtual task run_phase(uvm_phase phase);
      apb_item pending;
      bit in_reset;
      bit previous_complete;
      forever begin
        @(vif.monitor_cb);
        if (!vif.monitor_cb.reset_n) begin
          if (pending != null) aborted++;
          pending = null;
          if (!in_reset) begin
            apb_item item = apb_item::type_id::create("reset");
            item.reset = 1;
            observed.write(item);
            resets++;
          end
          in_reset = 1;
          previous_complete = 0;
        end
        else begin
          in_reset = 0;
          if (vif.monitor_cb.sel && !vif.monitor_cb.enable) begin
            if (pending != null) begin
              `uvm_fatal("APB_PROTOCOL", "setup interrupted an incomplete transfer")
              return;
            end
            if (previous_complete) back_to_back++;
            pending = apb_item::type_id::create("observed");
            pending.addr = vif.monitor_cb.addr;
            pending.write = vif.monitor_cb.write;
            pending.data = vif.monitor_cb.wdata;
            pending.strb = vif.monitor_cb.strb;
          end
          else if (vif.monitor_cb.sel && vif.monitor_cb.enable) begin
            if (pending == null) begin
              `uvm_fatal("APB_PROTOCOL", "access was not preceded by setup")
              return;
            end
            if ({pending.addr, pending.write, pending.data, pending.strb}
                !== {vif.monitor_cb.addr, vif.monitor_cb.write,
                     vif.monitor_cb.wdata, vif.monitor_cb.strb}) begin
              `uvm_fatal("APB_PROTOCOL", "request changed before transfer completion")
              return;
            end
            if (!vif.monitor_cb.ready) pending.waits++;
            else begin
              pending.error = vif.monitor_cb.error;
              if (!pending.write) pending.data = vif.monitor_cb.rdata;
              observed.write(pending);
              pending = null;
              completed++;
            end
          end
          else if (pending != null || vif.monitor_cb.enable) begin
            `uvm_fatal("APB_PROTOCOL", "request was withdrawn without reset or completion")
            return;
          end
          previous_complete = vif.monitor_cb.sel && vif.monitor_cb.enable && vif.monitor_cb.ready;
        end
      end
    endtask
  endclass

  class apb_scoreboard extends uvm_subscriber #(apb_item);
    `uvm_component_utils(apb_scoreboard)
    bit [31:0] model[16];
    int completed;
    int errors;
    int reads;
    int writes;
    int resets;
    bit [31:0] digest;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void write(apb_item item);
      if (item.reset) begin
        foreach (model[i]) model[i] = {24'ha50000, 8'(i)};
        resets++;
        return;
      end
      if (item.error != (item.addr >= 64 || item.addr % 4 != 0))
        `uvm_fatal("APB_SCOREBOARD", "incorrect error response")
      if (item.waits != (int'(item.addr) / 4) % 16 % 3)
        `uvm_fatal("APB_SCOREBOARD", "transfer wait count differs from peripheral contract")
      completed++;
      if (item.error) errors++;
      else if (item.write) begin
        bit [31:0] mask;
        for (int i = 0; i < 4; i++) if (item.strb[i]) mask |= 32'hff << (8 * i);
        model[item.addr/4] = (model[item.addr/4] & ~mask) | (item.data & mask);
        writes++;
      end
      else begin
        if (item.data !== model[item.addr/4])
          `uvm_fatal("APB_SCOREBOARD", $sformatf(
                     "read mismatch addr=%0h got=%0h expected=%0h",
                     item.addr,
                     item.data,
                     model[item.addr/4]
                     ))
        reads++;
      end
      digest = {digest[26:0], digest[31:27]} ^ item.data ^ {24'b0, item.addr};
    endfunction
  endclass

  class apb_coverage extends uvm_subscriber #(apb_item);
    `uvm_component_utils(apb_coverage)
    covergroup transfers with function sample (bit wr, bit err, int unsigned delay_cycles);
      direction: coverpoint wr;
      response: coverpoint err;
      wait_states: coverpoint delay_cycles {bins delays[] = {[0 : 2]};}
    endgroup
    function new(string name, uvm_component parent);
      super.new(name, parent);
      transfers = new;
    endfunction
    virtual function void write(apb_item item);
      if (!item.reset) transfers.sample(item.write, item.error, item.waits);
    endfunction
  endclass

  class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)
    apb_config cfg;
    apb_driver driver;
    uvm_sequencer #(apb_item) sequencer;
    apb_monitor monitor;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(apb_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("APB_CONFIG", "missing agent configuration")
      monitor = apb_monitor::type_id::create("monitor", this);
      monitor.vif = cfg.monitor_vif;
      if (cfg.mode == UVM_ACTIVE) begin
        driver = apb_driver::type_id::create("driver", this);
        driver.vif = cfg.driver_vif;
        sequencer = new("sequencer", this);
      end
    endfunction
    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (cfg.mode == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class apb_sequence extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_sequence)
    int completed;
    function new(string name = "apb_sequence");
      super.new(name);
    endfunction
    task transfer(bit wr, bit [7:0] address, bit [31:0] data = 0, bit [3:0] strobe = 15,
                  bit abort_transfer = 0);
      apb_item req = apb_item::type_id::create("request");
      apb_item rsp;
      req.write = wr;
      req.addr = address;
      req.data = data;
      req.strb = strobe;
      req.abort_transfer = abort_transfer;
      start_item(req);
      finish_item(req);
      get_response(rsp);
      if (rsp.abort_transfer != abort_transfer)
        `uvm_fatal("APB_RESPONSE", "incorrect reset cancellation response")
      if (!abort_transfer) begin
        if (rsp.error != (address >= 64 || address % 4 != 0))
          `uvm_fatal("APB_RESPONSE", "driver returned incorrect response status")
        completed++;
      end
    endtask
    virtual task body();
      for (int i = 0; i < 16; i++) transfer(0, 8'(i * 4));
      for (int i = 0; i < 16; i++) begin
        transfer(1, 8'(i * 4), $urandom);
        transfer(1, 8'(i * 4), $urandom, 4'(i));
        transfer(0, 8'(i * 4));
      end
      transfer(1, 8'h80, 32'hdeadbeef);
      transfer(0, 8'h80);
      transfer(1, 8'h03, 32'h12345678);
      transfer(0, 8'h03);
      // Verify rejected writes preserved every register before reset can mask
      // an unintended side effect.
      for (int i = 0; i < 16; i++) transfer(0, 8'(i * 4));
      transfer(1, 8'h08, 32'hbadbad00, 15, 1);
      for (int i = 0; i < 16; i++) transfer(0, 8'(i * 4));
      repeat (32) begin
        bit [7:0] address = 8'($urandom_range(0, 15) * 4);
        // Exercise requests arriving between clock edges as well as the read
        // immediately following each write on its completion edge.
        #1;
        transfer(1, address, $urandom, 4'($urandom));
        transfer(0, address);
      end
    endtask
  endclass

  `include "t_uvm_apb_ral.vh"

  class apb_test extends uvm_test;
    `uvm_component_utils(apb_test)
    apb_agent active_agent;
    apb_agent passive_agent;
    apb_scoreboard active_scoreboard;
    apb_scoreboard passive_scoreboard;
    apb_coverage coverage;
    apb_ral_helper ral;
    apb_sequence sequence_h;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      active_agent = apb_agent::type_id::create("active_agent", this);
      passive_agent = apb_agent::type_id::create("passive_agent", this);
      active_scoreboard = apb_scoreboard::type_id::create("active_scoreboard", this);
      passive_scoreboard = apb_scoreboard::type_id::create("passive_scoreboard", this);
      coverage = apb_coverage::type_id::create("coverage", this);
      ral = apb_ral_helper::type_id::create("ral", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      active_agent.monitor.observed.connect(active_scoreboard.analysis_export);
      passive_agent.monitor.observed.connect(passive_scoreboard.analysis_export);
      passive_agent.monitor.observed.connect(coverage.analysis_export);
      ral.attach(active_agent, passive_agent, active_scoreboard, passive_scoreboard);
    endfunction
    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      sequence_h = apb_sequence::type_id::create("sequence_h");
      sequence_h.start(active_agent.sequencer);
      ral.run_checks();
      repeat (3) @(active_agent.cfg.monitor_vif.monitor_cb);
      phase.drop_objection(this);
    endtask
    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (passive_agent.driver != null || passive_agent.sequencer != null)
        `uvm_fatal("APB_PASSIVE", "passive agent instantiated active components")
      if (active_agent.driver.aligned_requests == 0
          || active_agent.driver.immediate_requests == 0
          || active_agent.monitor.back_to_back == 0
          || active_agent.monitor.back_to_back != passive_agent.monitor.back_to_back)
        `uvm_fatal("APB_TIMING", "off-edge alignment and back-to-back transfers were not exercised")
      if (sequence_h.completed != 164 || ral.completed != 2272
          || active_agent.driver.completed != 2436
          || active_agent.monitor.completed != 2436 || passive_agent.monitor.completed != 2436
          || active_scoreboard.completed != 2436 || passive_scoreboard.completed != 2436)
        `uvm_fatal("APB_COUNT",
                   "sequence, driver, monitors and scoreboards did not complete 2436 transfers")
      if (active_agent.driver.aborted != 1 || active_agent.monitor.aborted != 1
          || passive_agent.monitor.aborted != 1 || active_scoreboard.resets != 5
          || passive_scoreboard.resets != 5)
        `uvm_fatal("APB_RESET", "reset did not cancel and recover the stalled transfer")
      if (active_scoreboard.errors != 4 || passive_scoreboard.errors != 4
          || active_scoreboard.reads != 1216 || active_scoreboard.writes != 1216)
        `uvm_fatal("APB_COUNT", "read, write or error totals were incorrect")
      if (active_scoreboard.digest != passive_scoreboard.digest)
        `uvm_fatal("APB_PASSIVE", "passive observations differ from active observations")
      if (coverage.transfers.get_inst_coverage() != 100.0)
        `uvm_fatal("APB_COVERAGE", "direction, response and wait-state bins were not covered")
    endfunction
  endclass

  initial begin
    apb_config active_cfg;
    apb_config passive_cfg;
    uvm_report_server reports;
    active_cfg = apb_config::type_id::create("active_cfg");
    passive_cfg = apb_config::type_id::create("passive_cfg");
    active_cfg.driver_vif = bus.driver_mp;
    active_cfg.monitor_vif = bus.monitor_mp;
    passive_cfg.mode = UVM_PASSIVE;
    passive_cfg.monitor_vif = bus.monitor_mp;
    uvm_config_db#(apb_config)::set(null, "uvm_test_top.active_agent", "cfg", active_cfg);
    uvm_config_db#(apb_config)::set(null, "uvm_test_top.passive_agent", "cfg", passive_cfg);
    uvm_root::get().set_finish_on_completion(0);
    run_test("apb_test");
    reports = uvm_report_server::get_server();
    if (reports.get_severity_count(UVM_ERROR) != 0 || reports.get_severity_count(UVM_FATAL) != 0)
      $fatal(1, "APB environment reported errors");
    $display("** UVM APB ENV PASSED **");
    $finish;
  end
  initial begin
    #1000000;
    $fatal(1, "APB environment timed out");
  end
endmodule
