// DESCRIPTION: Verilator: Disable fork during zero-time fork launch
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  bit plain_disable_started;
  int plain_winner;
  int plain_entry_after_disable;
  int plain_late;
  int plain_after;
  time plain_parent_time;

  int child_disable_after;
  int child_sibling_late;
  int child_parent_after;
  time child_parent_time;

  bit join_disable_started;
  int join_disable_entries;
  int join_disabler_after;
  int join_entry_after_disable;
  int join_zero_entry_after_disable;
  int join_late;
  int join_parent_after;
  time join_parent_time;

  bit any_disable_started;
  int any_disable_entries;
  int any_disabler_after;
  int any_entry_after_disable;
  int any_zero_entry_after_disable;
  int any_late;
  int any_parent_after;
  time any_parent_time;

  bit none_disable_started;
  int none_disable_entries;
  int none_disabler_after;
  int none_entry_after_disable;
  int none_zero_entry_after_disable;
  int none_late;
  int none_parent_after;
  time none_parent_time;

  // Parent-side disable fork kills every still-running child process.
  initial begin
    fork
      begin
        plain_winner++;
      end
      begin
        if (plain_disable_started) plain_entry_after_disable++;
        #1;
        plain_late++;
      end
    join_any
    plain_disable_started = 1'b1;
    disable fork;
    plain_after++;
    plain_parent_time = $time;
  end

  // Child-side disable fork does not kill a sibling process.
  initial begin
    fork
      begin
        disable fork;
        child_disable_after++;
      end
      begin
        #1;
        child_sibling_late++;
      end
    join
    child_parent_after++;
    child_parent_time = $time;
  end

  initial begin
    fork : named_join
      begin
        join_disable_entries++;
        join_disable_started = 1'b1;
        disable named_join;
        join_disabler_after++;
      end
      begin
        if (join_disable_started) join_entry_after_disable++;
        #1;
        join_late++;
      end
      begin
        if (join_disable_started) join_zero_entry_after_disable++;
      end
    join
    join_parent_after++;
    join_parent_time = $time;
  end

  initial begin
    fork : named_any
      begin
        any_disable_entries++;
        any_disable_started = 1'b1;
        disable named_any;
        any_disabler_after++;
      end
      begin
        if (any_disable_started) any_entry_after_disable++;
        #1;
        any_late++;
      end
      begin
        if (any_disable_started) any_zero_entry_after_disable++;
      end
    join_any
    any_parent_after++;
    any_parent_time = $time;
  end

  initial begin
    fork : named_none
      begin
        none_disable_entries++;
        none_disable_started = 1'b1;
        disable named_none;
        none_disabler_after++;
      end
      begin
        if (none_disable_started) none_entry_after_disable++;
        #1;
        none_late++;
      end
      begin
        if (none_disable_started) none_zero_entry_after_disable++;
      end
    join_none
    none_parent_after++;
    none_parent_time = $time;
  end

  initial begin
    #2;
    `checkd(plain_winner, 1)
    `checkd(plain_entry_after_disable, 0)
    `checkd(plain_late, 0)
    `checkd(plain_after, 1)
    `checkd(plain_parent_time, 0)

    `checkd(child_disable_after, 1)
    `checkd(child_sibling_late, 1)
    `checkd(child_parent_after, 1)
    `checkd(child_parent_time, 1)

    `checkd(join_disable_entries, 1)
    `checkd(join_disabler_after, 0)
    `checkd(join_entry_after_disable, 0)
    `checkd(join_zero_entry_after_disable, 0)
    `checkd(join_late, 0)
    `checkd(join_parent_after, 1)
    `checkd(join_parent_time, 0)

    `checkd(any_disable_entries, 1)
    `checkd(any_disabler_after, 0)
    `checkd(any_entry_after_disable, 0)
    `checkd(any_zero_entry_after_disable, 0)
    `checkd(any_late, 0)
    `checkd(any_parent_after, 1)
    `checkd(any_parent_time, 0)

    `checkd(none_disable_entries, 1)
    `checkd(none_disabler_after, 0)
    `checkd(none_entry_after_disable, 0)
    `checkd(none_zero_entry_after_disable, 0)
    `checkd(none_late, 0)
    `checkd(none_parent_after, 1)
    `checkd(none_parent_time, 0)

    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial #20 `stop;  // timeout
endmodule
