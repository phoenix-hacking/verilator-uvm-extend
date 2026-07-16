// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  class rng_probe;
    rand bit value;
  endclass

  process parent_process;
  process child_process;
  process grandchild_process;
  process rng_child_process;
  bit child_side_effect;
  bit grandchild_side_effect;
  bit rng_owner_resumed;

  task automatic run_process_tree();
    parent_process = process::self();
    fork
      begin
        child_process = process::self();
        #20 child_side_effect = 1'b1;
      end
      begin
        fork
          begin
            grandchild_process = process::self();
            #30 grandchild_side_effect = 1'b1;
          end
        join
      end
    join
  endtask

  task automatic run_rng_child();
    fork
      begin
        rng_child_process = process::self();
        #100;
      end
    join
    rng_owner_resumed = 1'b1;
  endtask

  initial begin
    process killer_process;
    rng_probe probe;
    string rng_before;
    string rng_after;

    killer_process = process::self();
    fork
      run_process_tree();
    join_none

    wait (parent_process != null);
    wait (child_process != null);
    wait (grandchild_process != null);
    #1;

    parent_process.kill();
    parent_process.await();

    // Wait beyond both delayed assignments. Killing a process must terminate
    // all of its subprocesses, including descendants of a forked child.
    #40;
    `checkd(child_side_effect, 0)
    `checkd(grandchild_side_effect, 0)
    `checkd(parent_process.status(), process::KILLED)
    `checkd(child_process.status(), process::KILLED)
    `checkd(grandchild_process.status(), process::KILLED)

    fork
      run_rng_child();
    join_none
    wait (rng_child_process != null);

    killer_process.srandom(100);
    rng_before = killer_process.get_randstate();

    // Killing the child synchronously resumes its non-killed owner through
    // fork-sync. The nested resume must restore this killer's process context.
    rng_child_process.kill();
    `checkd(rng_owner_resumed, 1)

    probe = new;
    `checkd(probe.randomize(), 1)
    rng_after = killer_process.get_randstate();
    if (rng_before == rng_after) begin
      $write("%%Error: process RNG context was not restored after recursive kill\n");
      $stop;
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #100 $stop;  // timeout
endmodule
