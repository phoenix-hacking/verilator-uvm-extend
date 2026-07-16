// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM 2020.3.1 phases, objections, and cleanup
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

  class phasing_test extends uvm_test;
    `uvm_component_utils(phasing_test)

    static int phase_step;
    static bit objection_raised;
    static bit objection_dropped;
    static time objection_drop_time;
    static int background_heartbeats;
    static bit delayed_side_effect;
    static bit run_ready_to_end_seen;
    static bit run_ended_seen;
    static bit check_seen;
    static bit report_seen;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void advance_phase(int expected, string phase_name);
      if (phase_step != expected)
        `uvm_fatal("PHASEORDER", $sformatf("%s phase was step %0d, expected %0d", phase_name,
                                           phase_step, expected))
      phase_step++;
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      advance_phase(0, "build");
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      advance_phase(1, "connect");
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      advance_phase(2, "end_of_elaboration");
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
      super.start_of_simulation_phase(phase);
      advance_phase(3, "start_of_simulation");
    endfunction

    task automatic run_background_descendants();
      fork
        begin
          forever begin
            #2;
            background_heartbeats++;
          end
        end
        begin
          #25;
          delayed_side_effect = 1'b1;
        end
      join
    endtask

    virtual task run_phase(uvm_phase phase);
      advance_phase(4, "run");
      phase.raise_objection(this, "exercise run-phase lifetime");
      objection_raised = 1'b1;
      if (phase.get_objection_count(this) != 1)
        `uvm_fatal("OBJECTION", "raise_objection did not establish the component objection")

      fork
        begin
          #10;
          phase.drop_objection(this, "exercise run-phase lifetime");
          objection_dropped = 1'b1;
          objection_drop_time = $time;
        end
        run_background_descendants();
      join

      // UVM must kill this run-phase process tree after the objection drops.
      `uvm_fatal("PHASEKILL", "run_phase returned instead of being killed at phase cleanup")
    endtask

    virtual function void phase_ready_to_end(uvm_phase phase);
      super.phase_ready_to_end(phase);
      if (phase.get_name() == "run") begin
        if (run_ended_seen)
          `uvm_fatal("PHASEORDER", "run ready-to-end callback followed run ended callback")
        run_ready_to_end_seen = 1'b1;
      end
    endfunction

    virtual function void phase_ended(uvm_phase phase);
      super.phase_ended(phase);
      if (phase.get_name() == "run") begin
        if (!run_ready_to_end_seen)
          `uvm_fatal("PHASEORDER", "run ended callback preceded run ready-to-end callback")
        run_ended_seen = 1'b1;
      end
    endfunction

    virtual function void extract_phase(uvm_phase phase);
      super.extract_phase(phase);
      advance_phase(5, "extract");
    endfunction

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      advance_phase(6, "check");
      if (!objection_raised || !objection_dropped)
        `uvm_fatal("OBJECTION", "run phase did not complete its objection lifecycle")
      if (objection_drop_time != 10)
        `uvm_fatal("OBJECTION", $sformatf("run phase ended at %0t, expected 10", objection_drop_time))
      if (!run_ready_to_end_seen || !run_ended_seen)
        `uvm_fatal("PHASEORDER", "run phase did not reach ready-to-end and ended callbacks")
      if (delayed_side_effect)
        `uvm_fatal("PHASEKILL", "delayed run-phase descendant survived cleanup")
      check_seen = 1'b1;
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      advance_phase(7, "report");
      if (!check_seen)
        `uvm_fatal("PHASEORDER", "report phase ran before check phase")
      report_seen = 1'b1;
    endfunction

    virtual function void final_phase(uvm_phase phase);
      super.final_phase(phase);
      advance_phase(8, "final");
      if (!report_seen)
        `uvm_fatal("PHASEORDER", "final phase ran before report phase")
    endfunction
  endclass

  initial begin
    int heartbeats_at_phase_end;
    uvm_report_server report_server;

    uvm_root::get().set_finish_on_completion(1'b0);
    run_test("phasing_test");

    `checkd(phasing_test::phase_step, 9)
    `checkd(phasing_test::report_seen, 1)
    if (phasing_test::background_heartbeats == 0)
      $fatal(1, "run-phase background descendant never executed");
    heartbeats_at_phase_end = phasing_test::background_heartbeats;

    // Advancing beyond both child delays proves cleanup killed descendants,
    // rather than merely allowing check/report to race ahead of them.
    #30;
    `checkd(phasing_test::background_heartbeats, heartbeats_at_phase_end)
    `checkd(phasing_test::delayed_side_effect, 0)

    report_server = uvm_report_server::get_server();
    `checkd(report_server.get_severity_count(UVM_ERROR), 0)
    `checkd(report_server.get_severity_count(UVM_FATAL), 0)
    $write("** UVM CORE PHASING PASSED **\n");
    $finish;
  end

  initial #100 `stop;  // timeout
endmodule
