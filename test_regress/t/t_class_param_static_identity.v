// DESCRIPTION: Verilator: Class parameter/localparam static initialization and specialization identity
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d (%s !== %s)\n", `__FILE__,`__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while(0);
// verilog_format: on

module t;

  class init_box #(
      parameter int P = 13
  );
    localparam int LP = P + 9;

    function int next_parameter();
      static int value = P;
      value = value + 1;
      return value;
    endfunction

    function int next_localparam();
      static int value = LP;
      value = value + 1;
      return value;
    endfunction
  endclass

  class identity_box #(
      parameter int P = 0
  );
    function int next_count();
      static int count = 0;
      count = count + 1;
      return count;
    endfunction

    function int parameter_value();
      return P;
    endfunction
  endclass

  typedef init_box#(.P(13)) init13_t;
  typedef identity_box#(.P(11)) identity11_t;
  typedef identity_box#(.P(23)) identity23_t;

  initial begin
    automatic init13_t init_a;
    automatic init13_t init_b;
    automatic identity11_t identity11_a;
    automatic identity11_t identity11_b;
    automatic identity23_t identity23_a;
    automatic int got;

    init_a = new;
    init_b = new;
    identity11_a = new;
    identity11_b = new;
    identity23_a = new;

    got = init_a.next_parameter();
    `checkd(got, 14);
    got = init_b.next_parameter();
    `checkd(got, 15);
    got = init_a.next_localparam();
    `checkd(got, 23);
    got = init_b.next_localparam();
    `checkd(got, 24);

    got = identity11_a.next_count();
    `checkd(got, 1);
    got = identity11_b.next_count();
    `checkd(got, 2);
    got = identity23_a.next_count();
    `checkd(got, 1);
    got = identity11_a.parameter_value();
    `checkd(got, 11);
    got = identity23_a.parameter_value();
    `checkd(got, 23);

    $write("*-* CLASS PARAM STATIC IDENTITY PASSED *-*\n");
    $finish;
  end
endmodule
