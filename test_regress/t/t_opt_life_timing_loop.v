// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2025-2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%t %%Error: %s:%0d:  got=%0d exp=%0d\n", $time, `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;

  class CounterTest;
    int completed;

    task tick(int operation);
      #1;
      `checkd(operation, completed);
      completed++;
    endtask

    task nested_loops(int loops);
      int operation = 0;
      bit [6:0] narrow = 7'h23;
      logic [62:0] wide_count = 63'h1234_5678_9abc_def;
      completed = 0;
      for (int outer = 0; outer < loops; outer++) begin
        for (int inner = 0; inner < 3; inner++) begin
          tick(operation);
          operation++;
          narrow += 7'd3;
          wide_count += 63'd5;
        end
      end
      `checkd(operation, loops * 3);
      `checkd(completed, loops * 3);
      `checkd(narrow, 7'h23 + 7'(loops * 9));
      `checkd(wide_count, 63'h1234_5678_9abc_def + 63'(loops * 15));
    endtask

    task block_loop(int loops);
      int operation = 0;
      completed = 0;
      begin : outer_block
        for (int inner = 0; inner < loops; inner++) begin
          tick(operation);
          operation++;
        end
        if (loops != 0) disable outer_block;
        `stop;
      end
      `checkd(operation, loops);
      `checkd(completed, loops);
    endtask

    task loop_block(int loops);
      int operation = 0;
      completed = 0;
      for (int outer = 0; outer < loops; outer++) begin : inner_block
        tick(operation);
        operation++;
        if (loops != 0) disable inner_block;
        `stop;
      end
      `checkd(operation, loops);
      `checkd(completed, loops);
    endtask

    task nested_blocks(int loops);
      int operation = 0;
      completed = 0;
      begin : outer_block
        begin : inner_block
          tick(operation);
          operation++;
          if (loops != 0) disable inner_block;
          `stop;
        end
        if (loops != 0) disable outer_block;
        `stop;
      end
      `checkd(operation, 1);
      `checkd(completed, 1);
    endtask

    function void observe(logic [62:0] value_seen, logic [62:0] expected);
      `checkd(value_seen, expected);
    endfunction

    task preserve_read(int loops);
      logic [62:0] token = 63'h1234_5678_9abc_def;
      for (int outer = 0; outer < loops; outer++) begin
        for (int inner = 0; inner < 3; inner++) begin
          #1;
          observe(token, 63'h1234_5678_9abc_def);
        end
      end
      // The later write must not erase the value consumed before suspension.
      token = '1;
      observe(token, '1);
    endtask
  endclass

  bit nested_tests_done;
  initial begin
    CounterTest counter_test;
    counter_test = new;
    for (int loops = 2; loops < 5; loops++) begin
      counter_test.nested_loops(loops);
      counter_test.block_loop(loops);
      counter_test.loop_block(loops);
      counter_test.nested_blocks(loops);
      counter_test.preserve_read(loops);
    end
    nested_tests_done = 1;
  end

  bit clk = 0;
  always #10 clk = ~clk;

  // Case A
  bit [3:0] cnt_A = 0;
  task task_A();
    $display("%t %m enter", $time);
    cnt_A = 0;
    repeat (2) @(posedge clk);
    for (int i = 0; i < 8; i++) begin : loop
      $display("%t %m inc %d", $time, i);
      ++cnt_A;
      repeat (2) @(posedge clk);
    end
    $display("%t %m inc final", $time);
    ++cnt_A;
    repeat (2) @(posedge clk);
    $display("%t %m exit", $time);
  endtask

  // Case B - Same, with 'repeat' unrolled
  bit [3:0] cnt_B = 0;
  task task_B();
    $display("%t %m enter", $time);
    cnt_B = 0;
    @(posedge clk);
    @(posedge clk);
    for (int i = 0; i < 8; i++) begin : loop
      ++cnt_B;
      @(posedge clk);
      @(posedge clk);
    end
    $display("%t %m inc final", $time);
    ++cnt_B;
    @(posedge clk);
    @(posedge clk);
    $display("%t %m exit", $time);
  endtask

  initial begin
    task_A();
    $display("%t taks_A return 1", $time);
    task_A();
    $display("%t taks_A return 2", $time);
  end

  initial begin
    task_B();
    $display("%t taks_B return 1", $time);
    task_B();
    $display("%t taks_B return 2", $time);

    #100;
    wait (nested_tests_done);
    $write("*-* All Finished *-*\n");
    $finish;
  end

  always_ff @(posedge clk) begin
    #1 `checkd(cnt_A, cnt_B);
  end

endmodule
