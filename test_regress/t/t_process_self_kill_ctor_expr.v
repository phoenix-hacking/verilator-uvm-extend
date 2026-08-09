// DESCRIPTION: Verilator: Self-kill in constructor expression contexts
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: got=%0d exp=%0d\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while (0);
// verilog_format: on

module t;
  class killer;
    function new(bit should_kill, ref process killed_process,
                 ref bit constructor_started, ref bit constructor_fell_through);
      if (should_kill) begin
        killed_process = process::self();
        constructor_started = 1'b1;
        killed_process.kill();
        constructor_fell_through = 1'b1;
      end
    endfunction
  endclass

  class holder;
    killer value;
  endclass

  killer sentinel;

  process declaration_process;
  bit declaration_started;
  bit declaration_ctor_fell_through;
  bit declaration_fell_through;

  killer array_value[2];
  process array_process;
  bit array_started;
  bit array_ctor_fell_through;
  bit array_assignment_fell_through;

  holder member_holder;
  process member_process;
  bit member_started;
  bit member_ctor_fell_through;
  bit member_assignment_fell_through;

  initial begin
    sentinel = new(0, array_process, array_started, array_ctor_fell_through);
    fork
      begin
        automatic killer declaration_value
            = new(1, declaration_process, declaration_started,
                  declaration_ctor_fell_through);
        declaration_fell_through = declaration_value != null;
      end
      begin
        array_value[1] = sentinel;
        array_value[1] = new(1, array_process, array_started, array_ctor_fell_through);
        array_assignment_fell_through = 1'b1;
      end
      begin
        member_holder = new;
        member_holder.value = sentinel;
        member_holder.value
            = new(1, member_process, member_started, member_ctor_fell_through);
        member_assignment_fell_through = 1'b1;
      end
    join_none
  end

  final begin
    `checkd(declaration_started, 1)
    `checkd(declaration_ctor_fell_through, 0)
    `checkd(declaration_fell_through, 0)
    `checkd(declaration_process.status(), process::KILLED)

    `checkd(array_started, 1)
    `checkd(array_ctor_fell_through, 0)
    `checkd(array_assignment_fell_through, 0)
    `checkd(array_process.status(), process::KILLED)
    `checkd(array_value[1] == sentinel, 1)

    `checkd(member_started, 1)
    `checkd(member_ctor_fell_through, 0)
    `checkd(member_assignment_fell_through, 0)
    `checkd(member_process.status(), process::KILLED)
    `checkd(member_holder.value == sentinel, 1)
    $write("*-* All Finished *-*\n");
  end
endmodule
