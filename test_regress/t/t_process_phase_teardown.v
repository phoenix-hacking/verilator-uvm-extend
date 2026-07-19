// DESCRIPTION: Verilator: UVM-like phase process teardown
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

package phase_teardown_pkg;
  int nba;
  int next_nba;

  task wait_for_nba_region;
    next_nba++;
    nba <= next_nba;
    @(nba);
  endtask

  class phase_state;
    int id;
    bit premature_end;
    process phase_proc;

    function new(int id);
      this.id = id;
    endfunction
  endclass

  class phase_hopper;
    int winners;
    int cleanups;
    int component_returns;
    int killed_status_ok;
    bit master_fell_through;
    bit premature_fell_through;
    bit forever_fell_through;

    // Keeping phase in this task matches the captured class scope in a UVM task phase.
    task component_task(phase_state phase);
      component_returns++;
    endtask

    function void traverse_on(phase_state phase);
      // The child process keeps the master process alive through its parent reference.
      fork
        begin : component_process
          process proc;
          proc = process::self();
          proc.srandom(32'h51a7_0000 ^ phase.id);
          component_task(phase);
        end
      join_none
    endfunction

    task execute_phase(phase_state phase);
      // Save the master process through an SV process wrapper, as uvm_phase does.
      fork : master_phase_process
        begin : master
          phase.phase_proc = process::self();
          traverse_on(phase);

          // verilator lint_off WAITCONST
          wait (0);
          // verilator lint_on WAITCONST
          master_fell_through = 1'b1;
        end
      join_none

      wait_for_nba_region();

      fork : watcher_scope
        begin : watcher_owner
          // Reproduce UVM's join_any race followed by an immediate sibling kill.
          fork : phase_exit_race
            begin : premature_end_watch
              wait (phase.premature_end);
              premature_fell_through = 1'b1;
            end
            begin : nba_winner
              wait_for_nba_region();
              wait_for_nba_region();
              winners++;
            end
            begin : constant_false_watch
              // verilator lint_off WAITCONST
              wait (0);
              // verilator lint_on WAITCONST
              forever_fell_through = 1'b1;
            end
          join_any

          disable fork;
        end
      join
    endtask

    task cleanup_phase(phase_state phase);
      process saved_proc;

      saved_proc = phase.phase_proc;
      if (saved_proc != null) begin
        saved_proc.kill();
        killed_status_ok +=
            (saved_proc.status() == process::KILLED);
        phase.phase_proc = null;
      end
      cleanups++;

      #0;
    endtask

    task process_phase(phase_state phase);
      #0;
      execute_phase(phase);
      #0;
      cleanup_phase(phase);
      #0;
    endtask
  endclass
endpackage

module t;
  import phase_teardown_pkg::*;

  // GCC 11 exposed the lost process reference during teardown at this still-fast stress count.
  localparam int PHASES = 1000;

  phase_hopper hopper;
  int completed;

  initial begin
    hopper = new;

    for (int i = 0; i < PHASES; i++) begin
      phase_state phase;
      phase = new(i);

      fork
        automatic phase_state captured_phase = phase;
        begin : phase_worker
          hopper.process_phase(captured_phase);
          completed++;
        end
      join_none

      wait (completed == (i + 1));
    end

    `checkd($time, 0)
    `checkd(completed, PHASES)
    `checkd(hopper.winners, PHASES)
    `checkd(hopper.cleanups, PHASES)
    `checkd(hopper.component_returns, PHASES)
    `checkd(hopper.killed_status_ok, PHASES)
    `checkd(hopper.master_fell_through, 0)
    `checkd(hopper.premature_fell_through, 0)
    `checkd(hopper.forever_fell_through, 0)

    $write("PHASE_TEARDOWN_SENTINEL phases=%0d winners=%0d cleanups=%0d\n",
           PHASES, hopper.winners, hopper.cleanups);
    $write("*-* All Finished *-*\n");
    // Leave the final killed process graph for model teardown, where the original failure occurred.
    $finish;
  end

  initial #100 `stop;
endmodule
