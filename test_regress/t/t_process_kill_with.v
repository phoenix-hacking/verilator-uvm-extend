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
    process caller;
  endclass

  class entry;
    key_state state;
    string name;
    function new(key_state state, string name);
      this.state = state;
      this.name = name;
    endfunction
    virtual function string get_name();
      if (state.request_kill) begin
        state.caller = process::self();
        state.caller.kill();
      end
      return name;
    endfunction
  endclass

  class sorter;
    key_state state;
    entry entries[$];
    bit after_sort;
    bit after_delay;
    function new(bit request_kill);
      state = new;
      state.request_kill = request_kill;
      for (int i = 0; i < 7; i++) begin
        entry value = new(state, $sformatf("entry_%0d", 6 - i));
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
  endclass

  initial begin
    sorter normal_sort;
    sorter canceled_sort;
    normal_sort = new(0);
    canceled_sort = new(1);
    fork
      normal_sort.run();
      canceled_sort.run();
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
    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #20 `stop;
endmodule
