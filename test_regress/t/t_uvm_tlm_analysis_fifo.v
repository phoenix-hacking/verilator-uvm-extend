// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM TLM analysis fanout, hierarchy, and FIFO flow
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

module t;
  import uvm_pkg::*;

  class tlm_item extends uvm_object;
    `uvm_object_utils(tlm_item)

    int item_id;
    int payload;

    function new(string name = "tlm_item");
      super.new(name);
    endfunction
  endclass

  class tlm_audit;
    static tlm_item sent[3];
    static int predictor_last_id;

    static function void reset();
      predictor_last_id = -1;
      foreach (sent[i]) sent[i] = null;
    endfunction

    static function void require_original(tlm_item item, string consumer);
      if (item == null)
        $fatal(1, "%s received a null item", consumer);
      if (item.item_id < 0 || item.item_id >= 3)
        $fatal(1, "%s received out-of-range item %0d", consumer, item.item_id);
      if (sent[item.item_id] == null || item != sent[item.item_id])
        $fatal(1, "%s did not receive the original broadcast handle", consumer);
      if (item.payload != 10 + item.item_id)
        $fatal(1, "%s observed a mutated payload", consumer);
    endfunction
  endclass

  class tlm_producer extends uvm_component;
    `uvm_component_utils(tlm_producer)

    uvm_analysis_port#(tlm_item) analysis_port;
    int writes;
    int intact_after_write;
    time first_write_time;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
      analysis_port = new("analysis_port", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      for (int i = 0; i < 3; i++) begin
        tlm_item item;
        item = tlm_item::type_id::create($sformatf("item_%0d", i));
        item.item_id = i;
        item.payload = 10 + i;
        tlm_audit::sent[i] = item;
        if (i == 0) first_write_time = $time;
        else if ($time != first_write_time)
          `uvm_fatal("ZEROTIME", "analysis writes did not occur in one time slot")
        analysis_port.write(item);
        if (item.item_id != i || item.payload != 10 + i)
          `uvm_fatal("MUTATION", "an analysis subscriber mutated the broadcast item")
        intact_after_write++;
        writes++;
      end
      #3;
      phase.drop_objection(this);
    endtask
  endclass

  class tlm_direct_sink extends uvm_subscriber#(tlm_item);
    `uvm_component_utils(tlm_direct_sink)

    int writes;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void write(tlm_item item);
      tlm_audit::require_original(item, "direct_sink");
      if (item.item_id != writes)
        `uvm_fatal("ORDER", "direct sink received items out of order")
      writes++;
    endfunction
  endclass

  class tlm_scoreboard extends uvm_subscriber#(tlm_item);
    `uvm_component_utils(tlm_scoreboard)

    int writes;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void write(tlm_item predicted);
      if (predicted == null)
        `uvm_fatal("PREDICT", "scoreboard received a null prediction")
      if (predicted.item_id != writes
          || tlm_audit::predictor_last_id != predicted.item_id)
        `uvm_fatal("ORDER", "scoreboard ran before or out of order with predictor")
      if (predicted.payload != 110 + predicted.item_id)
        `uvm_fatal("PREDICT", "scoreboard received an incorrect prediction")
      writes++;
    endfunction
  endclass

  class tlm_predictor extends uvm_subscriber#(tlm_item);
    `uvm_component_utils(tlm_predictor)

    uvm_analysis_port#(tlm_item) predicted_port;
    int writes;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
      predicted_port = new("predicted_port", this);
    endfunction

    virtual function void write(tlm_item item);
      tlm_item predicted;
      tlm_audit::require_original(item, "hierarchical_predictor");
      if (item.item_id != writes)
        `uvm_fatal("ORDER", "predictor received items out of order")
      predicted = tlm_item::type_id::create($sformatf("predicted_%0d", item.item_id));
      predicted.item_id = item.item_id;
      predicted.payload = item.payload + 100;
      tlm_audit::predictor_last_id = item.item_id;
      predicted_port.write(predicted);
      if (item.payload != 10 + item.item_id)
        `uvm_fatal("MUTATION", "predictor mutated its input item")
      writes++;
    endfunction
  endclass

  class tlm_analysis_bridge extends uvm_component;
    `uvm_component_utils(tlm_analysis_bridge)

    uvm_analysis_export#(tlm_item) analysis_export;
    tlm_predictor predictor;
    bit connect_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
      analysis_export = new("analysis_export", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      predictor = tlm_predictor::type_id::create("predictor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      analysis_export.connect(predictor.analysis_export);
      connect_seen = 1'b1;
    endfunction
  endclass

  class tlm_fifo_collector extends uvm_component;
    `uvm_component_utils(tlm_fifo_collector)

    uvm_tlm_analysis_fifo#(tlm_item) fifo;
    bit started;
    bit done;
    int gets;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      started = 1'b1;
      for (int i = 0; i < 3; i++) begin
        tlm_item item;
        fifo.get(item);
        tlm_audit::require_original(item, "analysis_fifo");
        if (item.item_id != i)
          `uvm_fatal("FIFO", "analysis FIFO did not preserve order")
        gets++;
      end
      done = 1'b1;
    endtask
  endclass

  class tlm_blocked_getter extends uvm_component;
    `uvm_component_utils(tlm_blocked_getter)

    uvm_tlm_analysis_fifo#(tlm_item) fifo;
    bit started;
    bit returned;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      tlm_item item;
      started = 1'b1;
      fifo.get(item);
      returned = 1'b1;
      `uvm_fatal("TEARDOWN", "blocked empty-FIFO get returned")
    endtask
  endclass

  class tlm_env extends uvm_env;
    `uvm_component_utils(tlm_env)

    tlm_producer producer;
    tlm_direct_sink direct_sink;
    tlm_analysis_bridge bridge;
    tlm_scoreboard scoreboard;
    uvm_tlm_analysis_fifo#(tlm_item) analysis_fifo;
    uvm_tlm_analysis_fifo#(tlm_item) empty_fifo;
    tlm_fifo_collector collector;
    tlm_blocked_getter blocker;
    bit connect_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      producer = tlm_producer::type_id::create("producer", this);
      direct_sink = tlm_direct_sink::type_id::create("direct_sink", this);
      bridge = tlm_analysis_bridge::type_id::create("bridge", this);
      scoreboard = tlm_scoreboard::type_id::create("scoreboard", this);
      analysis_fifo = new("analysis_fifo", this);
      empty_fifo = new("empty_fifo", this);
      collector = tlm_fifo_collector::type_id::create("collector", this);
      blocker = tlm_blocked_getter::type_id::create("blocker", this);
      collector.fifo = analysis_fifo;
      blocker.fifo = empty_fifo;
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      producer.analysis_port.connect(direct_sink.analysis_export);
      producer.analysis_port.connect(bridge.analysis_export);
      producer.analysis_port.connect(analysis_fifo.analysis_export);
      bridge.predictor.predicted_port.connect(scoreboard.analysis_export);
      if (!bridge.connect_seen)
        `uvm_fatal("PHASEORDER", "environment connect preceded bridge connect")
      connect_seen = 1'b1;
    endfunction
  endclass

  class tlm_test extends uvm_test;
    `uvm_component_utils(tlm_test)

    tlm_env env;
    bit connect_seen;
    bit check_seen;
    bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = tlm_env::type_id::create("env", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (env == null || !env.connect_seen)
        `uvm_fatal("PHASEORDER", "test connect preceded environment connect")
      connect_seen = 1'b1;
    endfunction

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (!connect_seen)
        `uvm_fatal("PHASEORDER", "connect phase sentinel did not fire")
      if (env.producer.analysis_port.size() != 3)
        `uvm_fatal("FANOUT", "producer did not resolve exactly three consumers")
      if (env.producer.writes != 3 || env.producer.intact_after_write != 3)
        `uvm_fatal("PRODUCER", "producer did not complete three intact writes")
      if (env.direct_sink.writes != 3
          || env.bridge.predictor.writes != 3
          || env.scoreboard.writes != 3)
        `uvm_fatal("ANALYSIS", "analysis consumer counts were incomplete")
      if (!env.collector.started || !env.collector.done || env.collector.gets != 3)
        `uvm_fatal("FIFO", "analysis FIFO collector did not complete in order")
      if (!env.blocker.started || env.blocker.returned)
        `uvm_fatal("TEARDOWN", "blocked-get teardown precondition was not preserved")
      if (env.analysis_fifo.used() != 0 || !env.analysis_fifo.is_empty())
        `uvm_fatal("FIFO", "analysis FIFO was not empty after collection")
      if (tlm_audit::predictor_last_id != 2)
        `uvm_fatal("ORDER", "predictor/scoreboard chain did not reach the final item")
      check_seen = 1'b1;
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      if (!check_seen)
        `uvm_fatal("PHASEORDER", "report phase ran without check phase")
      report_seen = 1'b1;
    endfunction
  endclass

  initial begin
    uvm_component top_component;
    tlm_test top_test;
    uvm_report_server report_server;
    tlm_item recovery_item;
    tlm_item recovered_item;

    tlm_audit::reset();
    uvm_root::get().set_finish_on_completion(1'b0);
    run_test("tlm_test");

    top_component = uvm_root::get().find("uvm_test_top");
    if (!$cast(top_test, top_component) || top_test == null)
      $fatal(1, "could not recover the completed UVM TLM test");
    if (!top_test.check_seen || !top_test.report_seen)
      $fatal(1, "mandatory check/report sentinels did not fire");
    if (top_test.env.blocker.returned)
      $fatal(1, "blocked empty-FIFO get survived run-phase teardown");

    recovery_item = new("recovery_item");
    recovery_item.item_id = 99;
    recovery_item.payload = 199;
    top_test.env.empty_fifo.write(recovery_item);
    if (!top_test.env.empty_fifo.can_get())
      $fatal(1, "killed blocked-get registration was not reclaimed");
    if (!top_test.env.empty_fifo.try_get(recovered_item)
        || recovered_item != recovery_item)
      $fatal(1, "empty FIFO was not reusable after blocked-get teardown");

    #5;
    if (top_test.env.blocker.returned)
      $fatal(1, "blocked empty-FIFO get resumed after phase teardown");

    report_server = uvm_report_server::get_server();
    `checkd(report_server.get_severity_count(UVM_ERROR), 0)
    `checkd(report_server.get_severity_count(UVM_FATAL), 0)
    $write("** UVM TLM ANALYSIS FIFO PASSED **\n");
    $finish;
  end

  initial #100 `stop;  // timeout
endmodule
