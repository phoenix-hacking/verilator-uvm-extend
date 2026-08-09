// DESCRIPTION: Verilator: Named sequential activation lifetime and identity
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module named_worker;
  int ticks;

  task automatic run();
    begin : run_body
      forever begin
        #1;
        ticks++;
      end
    end
  endtask
endmodule

class named_worker_class;
  int ticks;

  task automatic run();
    forever begin
      #1;
      ticks++;
    end
  endtask

endclass

class named_virtual_base #(type T = int);
  int ticks;

  virtual task run();
    forever begin
      #1;
      ticks++;
    end
  endtask
endclass

class named_virtual_derived #(type T = int) extends named_virtual_base #(T);
  virtual task run();
    forever begin
      #1;
      ticks++;
    end
  endtask
endclass

module t;
  named_worker worker0();
  named_worker worker1();

  process identity_seen;
  int identity_after;
  int block_started;
  int block_after;
  process detached_process;
  bit detached_started;
  bit ownership_done;
  int fork_branch_after;
  int fork_peer_after;
  int fork_owner_after;
  int nested_fork_branch_after;
  int nested_fork_peer_after;
  int nested_fork_owner_after;
  int nested_fork_outer_after;
  int function_fork_after;
  bit wait_helper_started;
  int wait_helper_after;
  int wait_target_after;
  event block_release;

  task automatic identity_stop();
    disable identity_task;
  endtask

  task automatic identity_task();
    identity_seen = process::self();
    identity_stop();
    identity_after++;
  endtask

  task automatic block_worker(input bit initiator);
    begin : shared_block
      block_started++;
      wait (block_started == 2);
      if (initiator) begin
        disable shared_block;
      end else begin
        @block_release;
      end
      block_after++;
    end
  endtask

  task automatic wait_helper();
    wait_helper_started = 1'b1;
    // verilator lint_off WAITCONST
    wait (0);
    // verilator lint_on WAITCONST
    wait_helper_after++;
  endtask

  task automatic wait_target();
    wait_helper();
    wait_target_after++;
  endtask

  function automatic int function_fork_launch(input bit cancel);
    // Keep a true C++ return type so the fork helper cannot inherit `return {};` from its parent.
    // verilator public
    begin : function_fork_target
      if (cancel) disable function_fork_target;
      fork
        begin
          #1;
          function_fork_after++;
        end
      join_none
      function_fork_launch = 1;
    end
  endfunction

  initial begin
    automatic process caller_process = process::self();
    automatic named_worker_class class_worker0 = new;
    automatic named_worker_class class_worker1 = new;
    automatic named_virtual_derived #(int) virtual_worker = new;
    automatic named_virtual_base #(int) virtual_base = virtual_worker;
    automatic int frozen_ticks;
    automatic int live_ticks;

    // A task call remains part of its caller's process even when the task is disable-addressable.
    identity_task();
    `checkd(identity_seen == caller_process, 1)
    `checkd(identity_after, 0)

    // One activation's in-scope disable reaches every concurrent activation of the same block.
    fork
      block_worker(1'b1);
      block_worker(1'b0);
    join_none
    wait (block_started == 2);
    #1;
    ->block_release;
    #1;
    `checkd(block_after, 0)
    wait fork;

    // Registries are fields of elaborated module instances, not translation-unit globals.
    fork
      worker0.run();
      worker1.run();
    join_none
    #3;
    disable worker0.run;
    #1;
    frozen_ticks = worker0.ticks;
    live_ticks = worker1.ticks;
    #3;
    `checkd(worker0.ticks, frozen_ticks)
    `checkd(worker1.ticks > live_ticks, 1)
    disable worker1.run;
    wait fork;

    // A hierarchical block path keeps only the module-instance receiver when addressing the
    // hoisted registry; lexical task/block path elements are not C++ object scopes.
    fork
      worker0.run();
      worker1.run();
    join_none
    #3;
    disable worker0.run.run_body;
    #1;
    frozen_ticks = worker0.ticks;
    live_ticks = worker1.ticks;
    #3;
    `checkd(worker0.ticks, frozen_ticks)
    `checkd(worker1.ticks > live_ticks, 1)
    disable worker1.run;
    wait fork;

    // The same declaration has independent registry state in each class object.
    fork
      class_worker0.run();
      class_worker1.run();
    join_none
    #3;
    disable class_worker0.run;
    #1;
    frozen_ticks = class_worker0.ticks;
    live_ticks = class_worker1.ticks;
    #3;
    `checkd(class_worker0.ticks, frozen_ticks)
    `checkd(class_worker1.ticks > live_ticks, 1)
    disable class_worker1.run;
    wait fork;

    // Virtual overrides share the root declaration's inherited registry.  Both a base-typed
    // receiver (which dynamically dispatches to the override) and a derived-typed receiver must
    // cancel the active override.
    fork
      virtual_base.run();
    join_none
    #3;
    disable virtual_base.run;
    #1;
    frozen_ticks = virtual_worker.ticks;
    #3;
    `checkd(virtual_worker.ticks, frozen_ticks)
    wait fork;

    fork
      virtual_worker.run();
    join_none
    #3;
    disable virtual_worker.run;
    #1;
    frozen_ticks = virtual_worker.ticks;
    #3;
    `checkd(virtual_worker.ticks, frozen_ticks)
    wait fork;

    // A disable executed by a fork descendant cannot jump directly to its parent's JumpBlock;
    // process/token cancellation unwinds both the children and the suspended owner instead.
    begin : fork_target
      fork
        begin
          #1;
          disable fork_target;
          fork_branch_after++;
        end
        begin
          #5;
          fork_peer_after++;
        end
      join
      fork_owner_after++;
    end
    #1;
    `checkd(fork_branch_after, 0)
    `checkd(fork_peer_after, 0)
    `checkd(fork_owner_after, 0)

    // A real fork branch receives a fresh activation token, while a named block created inside
    // that branch establishes its own token and unwind boundary.
    fork
      begin
        begin : nested_fork_target
          fork
            begin
              #1;
              disable nested_fork_target;
              nested_fork_branch_after++;
            end
            begin
              #5;
              nested_fork_peer_after++;
            end
          join
          nested_fork_owner_after++;
        end
        nested_fork_outer_after++;
      end
    join
    #1;
    `checkd(nested_fork_branch_after, 0)
    `checkd(nested_fork_peer_after, 0)
    `checkd(nested_fork_owner_after, 0)
    `checkd(nested_fork_outer_after, 1)

    // A non-coroutine function may launch a detached coroutine.  Its non-void return context
    // must not leak into the extracted fork helper's cancellation checks.
    `checkd(function_fork_launch(1'b0), 1)
    #2;
    `checkd(function_fork_after, 1)

    // A constant-false wait has no scheduler queue.  Named activation ownership must retain its
    // coroutine so an external disable can discard it and let the sibling wait fork complete.
    fork
      wait_target();
      begin
        wait (wait_helper_started);
        #1;
        disable wait_target;
      end
    join
    `checkd(wait_helper_after, 0)
    `checkd(wait_target_after, 0)

    // Completion removes only named-disable membership.  A join_none child remains independently
    // owned by the source process, so a late disable is a no-op and wait fork still observes it.
    begin : completed_target
      fork
        begin
          detached_process = process::self();
          detached_started = 1'b1;
          // verilator lint_off WAITCONST
          wait (0);
          // verilator lint_on WAITCONST
        end
      join_none
    end
    wait (detached_started);
    #1;
    disable completed_target;
    #1;
    `checkd(detached_process.status(), process::WAITING)
    detached_process.kill();
    wait fork;
    ownership_done = 1'b1;
    `checkd(ownership_done, 1)

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
