// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

class Self;
  typedef Self self_t;
  rand self_t child;
  rand bit [6:0] value;
endclass

typedef class Right;
class Left;
  rand Right child;
  rand bit [30:0] value;
  constraint value_c {value < 100;}
endclass

class Right;
  typedef Left left_t;
  rand left_t child;
  rand bit [64:0] value;
endclass

typedef class Derived;
class Base;
  rand Derived child;
endclass

class Derived extends Base;
  typedef enum bit [6:0] {
    LOW = 3,
    HIGH = 100
  } value_t;
  rand value_t value;
endclass

module t;
  initial begin
    automatic Self self_obj = new;
    automatic Left left_obj = new;
    automatic Base base_obj = new;
    automatic Derived derived_obj = new;
    int result;
    result = self_obj.randomize();
    result = left_obj.randomize();
    result = base_obj.randomize();
    result = derived_obj.randomize();
  end
endmodule
