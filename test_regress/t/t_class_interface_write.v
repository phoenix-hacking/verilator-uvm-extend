// DESCRIPTION: Verilator: Class writes must trigger interface combinational logic
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0)
// verilog_format: on

interface class_bus;
  bit [14:0] address;
  bit write;
  bit error;
  bit [14:0] decoded;
endinterface

package class_write_pkg;
  bit [6:0] data;
endpackage

module t (
`ifdef CLASS_WRITE_NOTIMING
    input bit clk
`endif
);
`ifndef CLASS_WRITE_NOTIMING
  bit clk;
  always #5 clk = !clk;
`endif
  class_bus bus ();
  bit [32:0] wide_value;
  // Keep these combinational outputs observable instead of inlining their
  // expressions into the class's checks before scheduling.
  bit [32:0] wide_decoded  /* verilator public_flat_rd */;
  bit [14:0] words[3:1];
  bit [14:0] total;
  bit [6:0] package_decoded  /* verilator public_flat_rd */;
  string label_text;
  int label_length  /* verilator public_flat_rd */;

  always_comb begin
    bus.error = bus.address[14:12] != 1 || !bus.write;
    bus.decoded = bus.address ^ 15'h1234;
    wide_decoded = wide_value ^ 33'h1abcdef01;
    total = words[1] + words[2] + words[3];
    package_decoded = class_write_pkg::data ^ 7'h35;
    label_length = label_text.len();
  end

  class driver;
    bit [14:0] expected_words[3:1];
    // Helper functions do not suspend, and still need to notify RTL readers.
    virtual function void drive(bit [14:0] address, int index);
      bus.address = address;
      bus.write = 1;
      wide_value = {index[0], address, address, 2'b11};
      words[1+index%3] = address;
      expected_words[1+index%3] = address;
      class_write_pkg::data = 7'(index);
      label_text = {label_text, "x"};
    endfunction
    function void check_values(bit [14:0] address, int index);
      `checkh(bus.error, 0);
      `checkh(bus.decoded, address ^ 15'h1234);
      `checkh(wide_decoded, {index[0], address, address, 2'b11} ^ 33'h1abcdef01);
      `checkh(total, 15'(expected_words[1] + expected_words[2] + expected_words[3]));
      `checkh(package_decoded, 7'(index) ^ 7'h35);
      `checkh(label_length, index + 1);
    endfunction
    function void idle();
      bus.write = 0;
    endfunction
`ifndef CLASS_WRITE_NOTIMING
    virtual task run();
      for (int i = 0; i < 17; i++) begin
        bit [14:0] address = 15'h1000 | (15'(i) * 15'd13);
        @(negedge clk);
        drive(address, i);
        @(posedge clk);
        check_values(address, i);
        @(negedge clk);
        idle();
        @(posedge clk);
        `checkh(bus.error, 1);
      end
    endtask
`endif
  endclass

`ifdef CLASS_WRITE_NOTIMING
  driver d = new;
  int tick;
  bit [14:0] address;
  always @(negedge clk) begin
    if (tick % 2 == 0) begin
      address = 15'h1000 | (15'(tick / 2) * 15'd13);
      d.drive(address, tick / 2);
    end
    else d.idle();
    tick++;
  end
  always @(posedge clk) begin
    if (tick % 2 == 1) d.check_values(address, tick / 2);
    else if (tick > 0) begin
      `checkh(bus.error, 1);
      if (tick == 34) begin
        $write("*-* All Finished *-*\n");
        $finish;
      end
    end
  end
`else
  initial begin
    driver d;
    d = new;
    d.run();
    $write("*-* All Finished *-*\n");
    $finish;
  end
  initial begin
    #10000;
    `stop;
  end
`endif
endmodule
