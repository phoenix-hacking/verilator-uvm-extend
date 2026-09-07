// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%p exp=%p\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class StateOnly;
  bit [64:0] value;
  bit [64:0] expected;
  int pre_count;
  int post_count;
  constraint match_c {value == expected;}

  function void pre_randomize();
    ++pre_count;
  endfunction

  function void post_randomize();
    ++post_count;
  endfunction
endclass

class SoftOnly;
  bit [6:0] value;
  bit [6:0] expected;
  constraint match_c {soft value == expected;}
endclass

class Empty;
  bit [30:0] value;
endclass

module t;
  initial begin
    automatic StateOnly obj = new;
    automatic SoftOnly soft_obj = new;
    automatic Empty empty_obj = new;
    bit [64:0] desired;
    int result;
    int old_pre;
    int old_post;

    // A hard state predicate can be unsatisfiable without any rand variables.
    for (int i = 0; i < 8; ++i) begin
      obj.value = 65'h10000000000000001 + 65'(i);
      obj.expected = obj.value;
      old_pre = obj.pre_count;
      old_post = obj.post_count;
      result = obj.randomize();
      `checkd(result, 1);
      `checkd(obj.pre_count, old_pre + 1);
      `checkd(obj.post_count, old_post + 1);
      `checkh(obj.value, obj.expected);

      obj.expected = obj.value + 1;
      result = obj.randomize();
      `checkd(result, 0);
      `checkd(obj.pre_count, old_pre + 2);
      `checkd(obj.post_count, old_post + 1);
      `checkh(obj.value, obj.expected - 1);

      // Check-only calls also evaluate state predicates.
      result = obj.randomize(null);
      `checkd(result, 0);
      obj.expected = obj.value;
      result = obj.randomize(null);
      `checkd(result, 1);

      // Exercise both a completely empty constraint set and inline-only state.
      obj.match_c.constraint_mode(0);
      obj.expected = obj.value + 1;
      result = obj.randomize();
      `checkd(result, 1);
      desired = obj.value;
      result = obj.randomize() with {value == local:: desired;};
      `checkd(result, 1);
      desired = obj.value + 1;
      result = obj.randomize() with {value == local:: desired;};
      `checkd(result, 0);
      `checkh(obj.value, desired - 1);
      obj.match_c.constraint_mode(1);
    end

    // Incompatible soft state predicates are discarded; hard predicates remain.
    soft_obj.value = 7'd37;
    soft_obj.expected = 7'd38;
    repeat (4) begin
      result = soft_obj.randomize();
      `checkd(result, 1);
      result = soft_obj.randomize(null);
      `checkd(result, 1);
      result = soft_obj.randomize() with {value == 7'd38;};
      `checkd(result, 0);
      result = soft_obj.randomize() with {value == 7'd37;};
      `checkd(result, 1);
      `checkd(soft_obj.value, 37);
    end

    // A class with no declared constraints still checks inline predicates.
    empty_obj.value = 31'd1234567;
    result = empty_obj.randomize();
    `checkd(result, 1);
    result = empty_obj.randomize() with {value == 31'd1234567;};
    `checkd(result, 1);
    result = empty_obj.randomize() with {value == 31'd1234568;};
    `checkd(result, 0);
    `checkd(empty_obj.value, 1234567);

    result = std::randomize() with {1;};
    `checkd(result, 1);
    result = std::randomize() with {0;};
    `checkd(result, 0);

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
