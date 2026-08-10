// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM sequence/sequencer/driver response and cancellation flow
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

  class flow_item extends uvm_sequence_item;
    `uvm_object_utils(flow_item)

    int item_id;
    int payload;
    int result;

    function new(string name = "flow_item");
      super.new(name);
    endfunction
  endclass

  class flow_audit;
    static flow_item requests[7];
    static int step;
    static int pre_count;
    static int mid_count;
    static int driver_count;
    static int post_count;
    static int response_count;

    static function void reset();
      step = 0;
      pre_count = 0;
      mid_count = 0;
      driver_count = 0;
      post_count = 0;
      response_count = 0;
      foreach (requests[i]) requests[i] = null;
    endfunction

    static function void require_request(flow_item item, int expected_id, string who);
      if (item == null)
        $fatal(1, "%s received a null request", who);
      if (expected_id < 0 || expected_id >= 7 || item.item_id != expected_id)
        $fatal(1, "%s received request %0d, expected %0d", who, item.item_id, expected_id);
      if (requests[expected_id] == null || item != requests[expected_id])
        $fatal(1, "%s did not receive the original request handle", who);
      if (item.payload != 20 + expected_id || item.result != 0)
        $fatal(1, "%s observed a mutated request", who);
    endfunction

    static function void expect_step(int expected_id, int stage, string who);
      int expected_step;
      expected_step = expected_id * 5 + stage;
      if (step != expected_step)
        $fatal(1, "%s was trace step %0d, expected %0d", who, step, expected_step);
      step++;
    endfunction
  endclass

  class flow_sequence extends uvm_sequence#(flow_item);
    `uvm_object_utils(flow_sequence)

    int first_id;
    int count;
    int current_id;
    int completed;

    function new(string name = "flow_sequence");
      super.new(name);
    endfunction

    virtual task pre_do(bit is_item);
      if (!is_item)
        `uvm_fatal("CALLBACK", "pre_do did not identify the sequence item")
      flow_audit::expect_step(current_id, 0, "pre_do");
      flow_audit::pre_count++;
    endtask

    virtual function void mid_do(uvm_sequence_item this_item);
      flow_item item;
      if (!$cast(item, this_item))
        `uvm_fatal("CALLBACK", "mid_do could not cast the request")
      flow_audit::require_request(item, current_id, "mid_do");
      flow_audit::expect_step(current_id, 1, "mid_do");
      flow_audit::mid_count++;
    endfunction

    virtual function void post_do(uvm_sequence_item this_item);
      flow_item item;
      if (!$cast(item, this_item))
        `uvm_fatal("CALLBACK", "post_do could not cast the request")
      flow_audit::require_request(item, current_id, "post_do");
      flow_audit::expect_step(current_id, 3, "post_do");
      flow_audit::post_count++;
    endfunction

    virtual task body();
      for (int offset = 0; offset < count; offset++) begin
        flow_item request;
        flow_item response;
        current_id = first_id + offset;
        request = flow_item::type_id::create($sformatf("request_%0d", current_id));
        request.item_id = current_id;
        request.payload = 20 + current_id;
        request.result = 0;
        flow_audit::requests[current_id] = request;
        start_item(request);
        finish_item(request);
        get_response(response);
        if (response == null || response == request)
          `uvm_fatal("RESPONSE", "sequence received a null or aliased response")
        if (response.item_id != current_id
            || response.payload != request.payload
            || response.result != request.payload * 3)
          `uvm_fatal("RESPONSE", "sequence received an incorrect response")
        flow_audit::expect_step(current_id, 4, "get_response");
        flow_audit::response_count++;
        completed++;
      end
    endtask
  endclass

  class quiet_sequence extends uvm_sequence#(flow_item);
    `uvm_object_utils(quiet_sequence)

    bit entered;
    bit body_returned;
    int heartbeats;

    function new(string name = "quiet_sequence");
      super.new(name);
    endfunction

    virtual task body();
      entered = 1'b1;
      forever begin
        #1;
        heartbeats++;
      end
      body_returned = 1'b1;
    endtask
  endclass

  class flow_driver extends uvm_driver#(flow_item, flow_item);
    `uvm_component_utils(flow_driver)

    int handled;
    bit waiting;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      forever begin
        flow_item request;
        flow_item response;
        waiting = 1'b1;
        seq_item_port.get_next_item(request);
        waiting = 1'b0;
        flow_audit::require_request(request, handled, "driver");
        flow_audit::expect_step(request.item_id, 2, "driver");
        flow_audit::driver_count++;
        response = flow_item::type_id::create(
            $sformatf("response_%0d", request.item_id));
        response.item_id = request.item_id;
        response.payload = request.payload;
        response.result = request.payload * 3;
        response.set_id_info(request);
        seq_item_port.item_done(response);
        handled++;
      end
    endtask
  endclass

  class flow_env extends uvm_env;
    `uvm_component_utils(flow_env)

    uvm_sequencer#(flow_item, flow_item) sequencer;
    flow_driver driver;
    bit connect_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = new("sequencer", this);
      driver = flow_driver::type_id::create("driver", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      connect_seen = 1'b1;
    endfunction
  endclass

  class flow_test extends uvm_test;
    `uvm_component_utils(flow_test)

    flow_env env;
    flow_sequence main_sequence;
    flow_sequence reuse_sequence;
    quiet_sequence killed_sequence;
    quiet_sequence stopped_sequence;
    bit killed_start_returned;
    bit stopped_start_returned;
    int killed_heartbeat_snapshot;
    int stopped_heartbeat_snapshot;
    bit connect_seen;
    bit check_seen;
    bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = flow_env::type_id::create("env", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (env == null || !env.connect_seen)
        `uvm_fatal("PHASEORDER", "test connect preceded environment connect")
      connect_seen = 1'b1;
    endfunction

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);

      main_sequence = flow_sequence::type_id::create("main_sequence");
      main_sequence.first_id = 0;
      main_sequence.count = 6;
      main_sequence.start(env.sequencer);

      killed_sequence = quiet_sequence::type_id::create("killed_sequence");
      fork
        begin
          killed_sequence.start(env.sequencer);
          killed_start_returned = 1'b1;
        end
      join_none
      wait (killed_sequence.entered);
      #2;
      if (killed_sequence.heartbeats == 0)
        `uvm_fatal("KILL", "sequence-kill target never ran")
      killed_sequence.kill();
      wait (killed_start_returned);
      killed_heartbeat_snapshot = killed_sequence.heartbeats;
      #2;
      if (killed_sequence.heartbeats != killed_heartbeat_snapshot)
        `uvm_fatal("KILL", "killed sequence body remained live")

      stopped_sequence = quiet_sequence::type_id::create("stopped_sequence");
      fork
        begin
          stopped_sequence.start(env.sequencer);
          stopped_start_returned = 1'b1;
        end
      join_none
      wait (stopped_sequence.entered);
      #2;
      if (stopped_sequence.heartbeats == 0)
        `uvm_fatal("STOP", "stop_sequences target never ran")
      env.sequencer.stop_sequences();
      wait (stopped_start_returned);
      stopped_heartbeat_snapshot = stopped_sequence.heartbeats;
      #2;
      if (stopped_sequence.heartbeats != stopped_heartbeat_snapshot)
        `uvm_fatal("STOP", "stop_sequences left the sequence body live")

      reuse_sequence = flow_sequence::type_id::create("reuse_sequence");
      reuse_sequence.first_id = 6;
      reuse_sequence.count = 1;
      reuse_sequence.start(env.sequencer);
      #2;

      phase.drop_objection(this);
    endtask

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (!connect_seen)
        `uvm_fatal("PHASEORDER", "connect phase sentinel did not fire")
      if (main_sequence == null || main_sequence.completed != 6)
        `uvm_fatal("SEQUENCE", "six-request main sequence did not complete")
      if (reuse_sequence == null || reuse_sequence.completed != 1)
        `uvm_fatal("REUSE", "sequencer did not complete the post-cancellation request")
      if (!killed_start_returned || !stopped_start_returned)
        `uvm_fatal("CANCEL", "a cancelled sequence start call did not return")
      if (killed_sequence.body_returned || stopped_sequence.body_returned)
        `uvm_fatal("CANCEL", "a cancelled sequence body returned normally")
      if (killed_sequence.get_sequence_state() != UVM_STOPPED
          || stopped_sequence.get_sequence_state() != UVM_STOPPED)
        `uvm_fatal("CANCEL", "cancelled sequence did not enter UVM_STOPPED")
      if (killed_heartbeat_snapshot == 0 || stopped_heartbeat_snapshot == 0)
        `uvm_fatal("CANCEL", "cancellation did not target running bodies")
      if (env.driver.handled != 7 || !env.driver.waiting)
        `uvm_fatal("DRIVER", "driver did not handle seven requests then block cleanly")
      if (flow_audit::step != 35
          || flow_audit::pre_count != 7
          || flow_audit::mid_count != 7
          || flow_audit::driver_count != 7
          || flow_audit::post_count != 7
          || flow_audit::response_count != 7)
        `uvm_fatal("TRACE", "callback/handshake/response trace was incomplete")
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
    flow_test top_test;
    uvm_report_server report_server;
    int handled_at_phase_end;

    flow_audit::reset();
    uvm_root::get().set_finish_on_completion(1'b0);
    run_test("flow_test");

    top_component = uvm_root::get().find("uvm_test_top");
    if (!$cast(top_test, top_component) || top_test == null)
      $fatal(1, "could not recover the completed sequence-flow test");
    if (!top_test.check_seen || !top_test.report_seen)
      $fatal(1, "mandatory check/report sentinels did not fire");
    handled_at_phase_end = top_test.env.driver.handled;
    #5;
    if (top_test.env.driver.handled != handled_at_phase_end
        || !top_test.env.driver.waiting)
      $fatal(1, "driver did not remain quiescent after phase teardown");

    report_server = uvm_report_server::get_server();
    `checkd(report_server.get_severity_count(UVM_ERROR), 0)
    `checkd(report_server.get_severity_count(UVM_FATAL), 0)
    $write("** UVM SEQUENCE DRIVER FLOW PASSED **\n");
    $finish;
  end

  initial #200 `stop;  // timeout
endmodule
