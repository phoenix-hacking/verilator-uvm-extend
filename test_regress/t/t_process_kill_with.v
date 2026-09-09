// DESCRIPTION: Verilator: Process cancellation in array method with expressions
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define checks(gotv,expv) do if ((gotv) != (expv)) begin $write("%%Error: %s:%0d:  got=%s exp=%s\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  class key_state;
    bit request_kill;
    bit request_disable;
    process caller;
  endclass

  class entry;
    key_state state;
    string name;
    bit [62:0] number;
    function new(key_state state, int index);
      this.state = state;
      this.name = $sformatf("entry_%0d", index);
      this.number = 63'h5a6d_93c7_a5b8_e240 + 63'(index);
    endfunction
    virtual function string get_name();
      if (state.request_kill) begin
        state.caller = process::self();
        state.caller.kill();
      end
      if (state.request_disable) disable t.named_sort;
      return name;
    endfunction
    virtual function bit [62:0] get_number();
      if (state.request_kill) begin
        state.caller = process::self();
        state.caller.kill();
      end
      if (state.request_disable) disable t.named_sort;
      return number;
    endfunction
  endclass

  class sorter;
    key_state state;
    entry entries[$];
    bit after_sort;
    bit after_delay;
    bit after_named;
    bit skip_query;
    time named_return_time;
    bit [62:0] sum = 63'h1357_9bdf_2468_ace0;
    function new(bit request_kill, bit request_disable = 0);
      state = new;
      state.request_kill = request_kill;
      state.request_disable = request_disable;
      for (int i = 0; i < 7; i++) begin
        entry value = new(state, (3 * i + 2) % 7);
        entries.push_back(value);
      end
    endfunction
    task run();
      #1;
      // Reduced from UVM2020.3.2 uvm_phase_hopper::finish_phase.
      entries.sort with (item.get_name());
      after_sort = 1;
      #1;
      after_delay = 1;
    endtask
    function void sort_sync();
      entries.rsort with (item.get_number());
      sum = entries.sum with (item.get_number());
      after_sort = 1;
    endfunction
    task run_numeric();
      #1;
      sort_sync();
      #1;
      after_delay = 1;
    endtask
  endclass

  task automatic named_sort(sorter object, int mode = 0);
    #1;
    case (mode)
      0: object.entries.sort with (item.get_name());
      1: object.sum = object.entries.sum with (item.get_number());
      2:
      if (!object.skip_query && (object.entries.sum with (item.get_number())) != 0)
        object.after_sort = 1;
      3:
      while (!object.after_sort && (object.entries.sum with (item.get_number())) != 0)
        object.after_sort = 1;
      default: `stop;
    endcase
    #1;
    object.after_delay = 1;
  endtask

  initial begin
    sorter normal_sort;
    sorter canceled_sort;
    sorter normal_numeric;
    sorter canceled_numeric;
    sorter normal_named;
    sorter canceled_named;
    sorter skipped_named;
    normal_sort = new(0);
    canceled_sort = new(1);
    normal_numeric = new(0);
    canceled_numeric = new(1);
    normal_named = new(0);
    canceled_named = new(0, 1);
    // A hierarchical disable terminates every active call of the named task.
    // Complete the control call before starting the cancellation case.
    named_sort(normal_named);
    normal_named.after_named = 1;
    normal_named.named_return_time = $time;
    fork
      normal_sort.run();
      canceled_sort.run();
      normal_numeric.run_numeric();
      canceled_numeric.run_numeric();
      begin
        named_sort(canceled_named);
        canceled_named.after_named = 1;
        canceled_named.named_return_time = $time;
      end
    join_none
    #3;
    `checkd(normal_sort.after_sort, 1)
    `checkd(normal_sort.after_delay, 1)
    foreach (normal_sort.entries[i]) `checks(normal_sort.entries[i].name, $sformatf("entry_%0d", i))
    // IEEE 1800-2017 7.12 leaves with-expression side effects unpredictable;
    // 9.7 allows termination at an unspecified time in the current time step.
    // Check cancellation across the delay, not callback counts or partial order.
    `checkd(canceled_sort.after_delay, 0)
    if (canceled_sort.state.caller == null) `stop;
    `checkd(canceled_sort.state.caller.status(), process::KILLED)
    `checkd(normal_numeric.after_sort, 1)
    `checkd(normal_numeric.after_delay, 1)
    foreach (normal_numeric.entries[i])
      `checks(normal_numeric.entries[i].name, $sformatf("entry_%0d", 6 - i))
    `checkd(normal_numeric.sum, 63'(7 * 64'h5a6d_93c7_a5b8_e240 + 21))
    `checkd(canceled_numeric.after_delay, 0)
    if (canceled_numeric.state.caller == null) `stop;
    `checkd(canceled_numeric.state.caller.status(), process::KILLED)
    `checkd(normal_named.after_delay, 1)
    `checkd(normal_named.after_named, 1)
    `checkd(normal_named.named_return_time, 2)
    `checkd(canceled_named.after_delay, 0)
    `checkd(canceled_named.after_named, 1)
    `checkd(canceled_named.named_return_time, 3)
    for (int mode = 1; mode <= 3; mode++) begin
      automatic time start_time = $time;
      normal_named = new(0);
      canceled_named = new(0, 1);
      named_sort(normal_named, mode);
      `checkd($time, start_time + 2)
      `checkd(normal_named.after_delay, 1)
      if (mode == 1) `checkd(normal_named.sum, 63'(7 * 64'h5a6d_93c7_a5b8_e240 + 21))
      else `checkd(normal_named.after_sort, 1)
      named_sort(canceled_named, mode);
      `checkd($time, start_time + 3)
      `checkd(canceled_named.after_delay, 0)
      `checkd(canceled_named.after_sort, 0)
      `checkd(canceled_named.sum, 63'h1357_9bdf_2468_ace0)
    end
    // A skipped condition must not invoke the disabling callback.
    skipped_named = new(0, 1);
    skipped_named.skip_query = 1;
    named_sort(skipped_named, 2);
    `checkd(skipped_named.after_delay, 1)
    `checkd(skipped_named.after_sort, 0)
    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #40 `stop;
endmodule
