// DESCRIPTION: Verilator: Interface-class named-task disable diagnostic
//
// This file ONLY is placed under the Creative Commons Public Domain
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

interface class runner_if #(type T = int);
  pure virtual task run(T value);
endclass

class worker_c #(type T = int) implements runner_if #(T);
  virtual task run(T value);
    #100;
  endtask
endclass

module t;
  initial begin
    automatic worker_c #(int) worker = new;
    automatic runner_if #(int) obj = worker;
    fork
      obj.run(42);
      begin
        #1;
        disable obj.run;
      end
    join
  end
endmodule
