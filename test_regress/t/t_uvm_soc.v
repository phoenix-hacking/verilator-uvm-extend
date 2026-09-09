// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM synthetic SoC CSR, DMA, memory, interrupt and reset flow
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

`include "t_uvm_soc_bus.vh"
`include "t_uvm_soc_rtl.vh"

module t;
  import uvm_pkg::*;
  bit csr_clk;
  bit dma_clk;
  always #5 csr_clk = !csr_clk;
  always #7 dma_clk = !dma_clk;
  soc_apb_if csr (csr_clk);
  soc_axi_if mem (dma_clk);
  wire irq;
  assign csr.irq = irq;
  always @(negedge csr_clk)
    if ($test$plusargs("APB_PROTOCOL_TRACE"))
      $display("SOC_IRQ_SAMPLE %0t %0d %0d", $time, csr.reset_n, irq);
  assign mem.reset_n = csr.reset_n;
  soc_dma dut (
      csr,
      mem,
      irq
  );
  soc_memory ram (mem);
`ifndef UVM_NO_DPI
  import "DPI-C" pure function int soc_reference_copy(
    int source,
    int destination,
    int length,
    int index,
    int corrupt
  );
`endif

  class soc_item extends uvm_sequence_item;
    `uvm_object_utils(soc_item)
    bit write;
    bit [8:0] addr;
    bit [31:0] data;
    bit [3:0] strb;
    bit error;
    int channel;  // 0 CSR, 1 DMA memory, 2 reset, 3 IRQ transition
    function new(string name = "soc_item");
      super.new(name);
    endfunction
  endclass

  class soc_driver extends uvm_driver #(soc_item);
    `uvm_component_utils(soc_driver)
    virtual soc_apb_if.driver_mp vif;
    time last_clock;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task tick();
      @(vif.driver_cb);
      last_clock = $time;
    endtask
    virtual task run_phase(uvm_phase phase);
      forever begin
        soc_item req, rsp;
        seq_item_port.get_next_item(req);
        if ($time != last_clock) tick();
        rsp = soc_item::type_id::create("response");
        rsp.set_id_info(req);
        vif.driver_cb.sel <= 1;
        vif.driver_cb.enable <= 0;
        vif.driver_cb.addr <= 8'(req.addr);
        vif.driver_cb.write <= req.write;
        vif.driver_cb.wdata <= req.data;
        vif.driver_cb.strb <= req.write ? req.strb : 0;
        tick();
        vif.driver_cb.enable <= 1;
        do tick(); while (!vif.driver_cb.ready);
        rsp.addr = req.addr;
        rsp.write = req.write;
        rsp.strb = req.strb;
        rsp.error = vif.driver_cb.error;
        rsp.data = req.write ? req.data : vif.driver_cb.rdata;
        vif.driver_cb.sel <= 0;
        vif.driver_cb.enable <= 0;
        seq_item_port.item_done(rsp);
      end
    endtask
  endclass

  class soc_monitor extends uvm_component;
    `uvm_component_utils(soc_monitor)
    uvm_analysis_port #(soc_item) observed;
    virtual soc_apb_if.monitor_mp cvif;
    virtual soc_axi_if.monitor_mp mvif;
    int epochs;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      observed = new("observed", this);
    endfunction
    task observe_csr();
      bit in_reset = 0;
      bit previous_irq = 0;
      forever begin
        soc_item item;
        @(cvif.monitor_cb);
        if (!cvif.monitor_cb.reset_n) begin
          if (!in_reset) begin
            item = new("reset");
            item.channel = 2;
            observed.write(item);
            epochs++;
            $display("SOC_RESET %0d", epochs);
          end
          in_reset = 1;
          previous_irq = 0;
        end
        else begin
          in_reset = 0;
          if (cvif.monitor_cb.sel && cvif.monitor_cb.enable && cvif.monitor_cb.ready) begin
            item = new("csr");
            item.addr = 9'(cvif.monitor_cb.addr);
            item.write = cvif.monitor_cb.write;
            item.strb = cvif.monitor_cb.strb;
            item.error = cvif.monitor_cb.error;
            item.data = item.write ? cvif.monitor_cb.wdata : cvif.monitor_cb.rdata;
            observed.write(item);
            $display("SOC_CSR %0d %0d %0h %08h %0h %0d", epochs, item.write, item.addr, item.data,
                     item.strb, item.error);
          end
          if (cvif.monitor_cb.irq != previous_irq) begin
            item = new("irq");
            item.channel = 3;
            item.data = 32'(cvif.monitor_cb.irq);
            observed.write(item);
            $display("SOC_IRQ %0d %0d", epochs, cvif.monitor_cb.irq);
            previous_irq = cvif.monitor_cb.irq;
          end
        end
      end
    endtask
    task observe_memory();
      bit have_address = 0;
      bit have_data = 0;
      bit have_read = 0;
      bit [8:0] address, read_address;
      bit [31:0] data;
      bit [3:0] strobes;
      forever begin
        soc_item item;
        @(mvif.monitor_cb);
        if (!mvif.monitor_cb.reset_n) begin
          have_address = 0;
          have_data = 0;
          have_read = 0;
        end
        else begin
          if (mvif.monitor_cb.awvalid && mvif.monitor_cb.awready) begin
            if (have_address) `uvm_fatal("SOC_AXI", "duplicate write address")
            address = mvif.monitor_cb.awaddr;
            have_address = 1;
          end
          if (mvif.monitor_cb.wvalid && mvif.monitor_cb.wready) begin
            if (have_data) `uvm_fatal("SOC_AXI", "duplicate write data")
            data = mvif.monitor_cb.wdata;
            strobes = mvif.monitor_cb.wstrb;
            have_data = 1;
          end
          if (mvif.monitor_cb.bvalid && mvif.monitor_cb.bready) begin
            if (!have_address || !have_data) `uvm_fatal("SOC_AXI", "unpaired write response")
            item = new("write");
            item.channel = 1;
            item.write = 1;
            item.addr = address;
            item.data = data;
            item.strb = strobes;
            item.error = mvif.monitor_cb.bresp != 0;
            observed.write(item);
            $display("SOC_DMA %0d W %0h %08h %0h", epochs, address, data, strobes);
            have_address = 0;
            have_data = 0;
          end
          if (mvif.monitor_cb.arvalid && mvif.monitor_cb.arready) begin
            if (have_read) `uvm_fatal("SOC_AXI", "duplicate read address")
            read_address = mvif.monitor_cb.araddr;
            have_read = 1;
          end
          if (mvif.monitor_cb.rvalid && mvif.monitor_cb.rready) begin
            if (!have_read) `uvm_fatal("SOC_AXI", "unpaired read response")
            item = new("read");
            item.channel = 1;
            item.addr = read_address;
            item.data = mvif.monitor_cb.rdata;
            item.error = mvif.monitor_cb.rresp != 0;
            observed.write(item);
            $display("SOC_DMA %0d R %0h %08h 0", epochs, read_address, item.data);
            have_read = 0;
          end
        end
      end
    endtask
    virtual task run_phase(uvm_phase phase);
      fork
        observe_csr();
        observe_memory();
      join
    endtask
  endclass

  class soc_scoreboard extends uvm_subscriber #(soc_item);
    `uvm_component_utils(soc_scoreboard)
    bit [7:0] expected[512];
    int source, destination, length;
    int reads, writes, total_reads, total_writes, resets, irqs;
    bit active;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void reset_model();
      foreach (expected[i]) expected[i] = 8'((37 * i) ^ (i / 4) ^ 90);
      reads = 0;
      writes = 0;
      active = 0;
      resets++;
    endfunction
    function void command(int src, int dst, int count);
      source = src;
      destination = dst;
      length = count;
      reads = 0;
      writes = 0;
      active = 1;
    endfunction
    virtual function void write(soc_item item);
      if (item.channel == 2) reset_model();
      else if (item.channel == 3) begin
        if (item.data[0] && (!active || writes != length))
          `uvm_fatal("SOC_IRQ", "interrupt asserted before DMA completion")
        irqs++;
      end
      else if (item.channel == 1) begin
        int address;
        bit [31:0] value;
        if (!active || item.error) `uvm_fatal("SOC_SCOREBOARD", "unexpected memory transaction")
        if (!item.write) begin
          address = (source + reads) & ~3;
          value = 0;
          for (int lane = 0; lane < 4; lane++) value[lane*8+:8] = expected[address+lane];
          if (reads != writes || reads >= length || int'(item.addr) != address || item.data != value)
            `uvm_fatal("SOC_SCOREBOARD", "DMA read differs from independent memory model")
          reads++;
          total_reads++;
        end
        else begin
          address = destination + writes;
          if (reads != writes+1 || writes >= length || int'(item.addr) != (address & ~3)
              || item.strb != (4'b1 << (address % 4))
              || 8'(item.data >> (8*(address % 4))) != expected[source+writes])
            `uvm_fatal("SOC_SCOREBOARD", "DMA write differs from independent byte-copy model")
          expected[address] = expected[source+writes];
          writes++;
          total_writes++;
        end
      end
    endfunction
  endclass

  class soc_coverage extends uvm_subscriber #(soc_item);
    `uvm_component_utils(soc_coverage)
    int observations;
    covergroup transfers with function sample (int channel, bit wr, bit error, bit [3:0] mask);
      option.per_instance = 1;
      channel_kind: coverpoint channel {bins kinds[] = {[0 : 3]};}
      direction: coverpoint wr iff (channel < 2);
      response: coverpoint error iff (channel == 0);
      byte_lane: coverpoint mask iff (channel == 1 && wr) {bins lanes[] = {1, 2, 4, 8};}
    endgroup
    function new(string name, uvm_component parent);
      super.new(name, parent);
      transfers = new;
    endfunction
    virtual function void write(soc_item item);
      transfers.sample(item.channel, item.write, item.error, item.strb);
      observations++;
    endfunction
  endclass

  class soc_adapter extends uvm_reg_adapter;
    `uvm_object_utils(soc_adapter)
    function new(string name = "soc_adapter");
      super.new(name);
      supports_byte_enable = 1;
      provides_responses = 1;
    endfunction
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
      soc_item item = new("register");
      item.addr = 9'(rw.addr);
      item.write = rw.kind == UVM_WRITE;
      item.data = 32'(rw.data);
      item.strb = item.write ? 4'(rw.byte_en) : 0;
      return item;
    endfunction
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
      soc_item item;
      if (!$cast(item, bus_item)) `uvm_fatal("SOC_RAL", "invalid register response")
      rw.addr = uvm_reg_addr_t'(item.addr);
      rw.kind = item.write ? UVM_WRITE : UVM_READ;
      rw.data = uvm_reg_data_t'(item.data);
      rw.byte_en = uvm_reg_byte_en_t'(item.strb);
      rw.n_bits = 32;
      rw.status = item.error ? UVM_NOT_OK : UVM_IS_OK;
    endfunction
  endclass

  class soc_register extends uvm_reg;
    `uvm_object_utils(soc_register)
    uvm_reg_field value;
    function new(string name = "soc_register");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    function void build(string access_kind, bit is_volatile);
      value = uvm_reg_field::type_id::create("value");
      value.configure(this, 32, 0, access_kind, is_volatile, 0, 1, 0, 0);
    endfunction
  endclass

  class soc_registers extends uvm_reg_block;
    `uvm_object_utils(soc_registers)
    soc_register words[7];
    function new(string name = "soc_registers");
      super.new(name, UVM_NO_COVERAGE);
    endfunction
    function void build();
      default_map = create_map("csr", 0, 4, UVM_LITTLE_ENDIAN, 1);
      foreach (words[i]) begin
        words[i] = soc_register::type_id::create($sformatf("word_%0d", i));
        words[i].configure(this);
        words[i].build(i == 4 ? "RO" : i == 6 ? "W1C" : "RW", i == 3 || i == 4 || i == 6);
        default_map.add_reg(words[i], uvm_reg_addr_t'(4 * i), i == 4 ? "RO" : "RW");
      end
      lock_model();
      reset();
    endfunction
  endclass

  class soc_raw_sequence extends uvm_sequence #(soc_item);
    `uvm_object_utils(soc_raw_sequence)
    soc_item request, response;
    function new(string name = "soc_raw_sequence");
      super.new(name);
    endfunction
    virtual task body();
      start_item(request);
      finish_item(request);
      get_response(response);
    endtask
  endclass

  class soc_test extends uvm_test;
    `uvm_component_utils(soc_test)
    soc_driver driver;
    uvm_sequencer #(soc_item) sequencer;
    soc_monitor monitor;
    soc_scoreboard scoreboard;
    soc_coverage coverage;
    soc_adapter adapter;
    soc_registers registers;
    int completed, canceled, dpi_checks;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      driver = soc_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer#(soc_item)::type_id::create("sequencer", this);
      monitor = soc_monitor::type_id::create("monitor", this);
      scoreboard = soc_scoreboard::type_id::create("scoreboard", this);
      coverage = soc_coverage::type_id::create("coverage", this);
      adapter = soc_adapter::type_id::create("adapter");
      registers = soc_registers::type_id::create("registers");
      registers.build();
      driver.vif = csr;
      monitor.cvif = csr;
      monitor.mvif = mem;
    endfunction
    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      monitor.observed.connect(scoreboard.analysis_export);
      monitor.observed.connect(coverage.analysis_export);
      registers.default_map.set_sequencer(sequencer, adapter);
      registers.default_map.set_auto_predict(1);
    endfunction
    task put(int index, int unsigned value);
      uvm_status_e status;
      registers.words[index].write(status, uvm_reg_data_t'(value), UVM_FRONTDOOR);
      if (status != UVM_IS_OK) `uvm_fatal("SOC_RAL", "register write failed")
    endtask
    task get(int index, output int unsigned value);
      uvm_status_e status;
      uvm_reg_data_t actual;
      registers.words[index].read(status, actual, UVM_FRONTDOOR);
      if (status != UVM_IS_OK) `uvm_fatal("SOC_RAL", "register read failed")
      value = 32'(actual);
    endtask
    task reset_hardware();
      @(negedge csr_clk);
      csr.reset_n = 0;
      repeat (5) @(negedge csr_clk);
      registers.reset();
      csr.reset_n = 1;
      repeat (3) @(negedge csr_clk);
      if (irq) `uvm_fatal("SOC_RESET", "interrupt survived reset")
    endtask
    task check_memory(int src, int dst, int count);
      for (int i = 0; i < 512; i++) begin
        bit [7:0] expected;
        int reference;
        int original = (i >= dst && i < dst + count) ? src + i - dst : i;
        expected = 8'(37 * original) ^ 8'(original / 4) ^ 8'd90;
        if (ram.storage[i] != expected || scoreboard.expected[i] != expected)
          `uvm_fatal("SOC_MEMORY", $sformatf(
                     "memory[%0d] got=%0h expected=%0h", i, ram.storage[i], expected))
`ifndef UVM_NO_DPI
        reference = soc_reference_copy(src, dst, count, i, $test$plusargs("SOC_CORRUPT_REFERENCE"));
        if (reference != int'(expected))
          `uvm_fatal("SOC_DPI", $sformatf(
                     "C memory[%0d] got=%0d expected=%0d", i, reference, expected))
        dpi_checks++;
`endif
        $display("SOC_MEMORY %0d %0d %02h", monitor.epochs, i, ram.storage[i]);
      end
    endtask
    task start_command(int src, int dst, int count, bit enable_irq);
      int unsigned value;
      scoreboard.command(src, dst, count);
      put(0, 32'(src));
      put(1, 32'(dst));
      put(2, 32'(count));
      put(5, 32'(enable_irq));
      get(0, value);
      if (value != 32'(src)) `uvm_fatal("SOC_RAL", "source readback mismatch")
      get(1, value);
      if (value != 32'(dst)) `uvm_fatal("SOC_RAL", "destination readback mismatch")
      get(2, value);
      if (value != 32'(count)) `uvm_fatal("SOC_RAL", "length readback mismatch")
      $display("SOC_COMMAND %0d %0d %0d %0d %0d", monitor.epochs, src, dst, count, enable_irq);
      put(3, 1);
    endtask
    task complete_command(int src, int dst, int count, bit enable_irq);
      int unsigned status = 0;
      int polls = 0;
      while (status != 2 && polls < 2000) begin
        get(4, status);
        polls++;
      end
      if (status != 2 || scoreboard.reads != count || scoreboard.writes != count)
        `uvm_fatal("SOC_COMPLETE", "DMA completion or byte counts are incorrect")
      #1;
      if (irq != enable_irq) `uvm_fatal("SOC_IRQ", "completion interrupt or mask is incorrect")
      if (!enable_irq) begin
        put(5, 1);
        #1;
        if (!irq) `uvm_fatal("SOC_IRQ", "unmasking pending completion did not raise IRQ")
      end
      put(6, 1);
      #1;
      if (irq) `uvm_fatal("SOC_IRQ", "write-one clear did not remove IRQ")
      get(4, status);
      if (status != 0) `uvm_fatal("SOC_IRQ", "completion state did not clear")
      scoreboard.active = 0;
      check_memory(src, dst, count);
      completed++;
      $display("SOC_COMPLETE %0d %0d", monitor.epochs, count);
    endtask
    virtual task run_phase(uvm_phase phase);
      int jobs = 4;
      int counts[4] = '{1, 7, 16, 31};
      soc_raw_sequence bad;
      phase.raise_objection(this);
      void'($value$plusargs("SOC_JOBS=%d", jobs));
      if (jobs < 4 || jobs > 64) `uvm_fatal("SOC_CONFIG", "SOC_JOBS must be 4 through 64")
      for (int job = 0; job < jobs; job++) begin
        int src = 4 * int'($urandom_range(0, 15)) + job % 4;
        int dst = 256 + 4 * int'($urandom_range(0, 31)) + (3 - job % 4);
        reset_hardware();
        start_command(src, dst, counts[job%4], 1'(job % 2));
        complete_command(src, dst, counts[job%4], 1'(job % 2));
      end
      // Reset an active transfer after independently observed completed writes.
      reset_hardware();
      start_command(3, 321, 63, 1);
      wait (scoreboard.writes >= 3);
      @(negedge csr_clk);
      $display("SOC_CANCEL %0d %0d", monitor.epochs, scoreboard.writes);
      csr.reset_n = 0;
      canceled++;
      repeat (5) @(negedge csr_clk);
      registers.reset();
      csr.reset_n = 1;
      repeat (20) @(negedge csr_clk);
      if (scoreboard.total_writes == 0 || scoreboard.writes != 0 || irq)
        `uvm_fatal("SOC_RESET", "old DMA work or interrupt survived reset")
      check_memory(0, 256, 0);
      start_command(11, 279, 7, 1);
      complete_command(11, 279, 7, 1);
      // An invalid CSR access must report an error without changing memory.
      bad = soc_raw_sequence::type_id::create("invalid_csr");
      bad.request = new("request");
      bad.request.addr = 28;
      bad.start(sequencer);
      if (!bad.response.error) `uvm_fatal("SOC_CSR_ERROR", "invalid CSR did not report an error")
      repeat (2) @(negedge csr_clk);
      if (completed != jobs + 1 || canceled != 1 || scoreboard.irqs != 2 * completed)
        `uvm_fatal("SOC_COUNTS", "completion, cancellation or IRQ edge count mismatch")
      if (coverage.transfers.get_inst_coverage() != 100.0)
        `uvm_fatal("SOC_COVERAGE", "required bus/reset/IRQ/error/byte-lane bins missing")
      $display(
          "SOC_SUMMARY jobs=%0d canceled=%0d reads=%0d writes=%0d irq_edges=%0d dpi=%0d coverage=%0.1f",
          completed, canceled, scoreboard.total_reads, scoreboard.total_writes, scoreboard.irqs,
          dpi_checks, coverage.transfers.get_inst_coverage());
      phase.drop_objection(this);
    endtask
  endclass

  initial begin
    uvm_report_server reports;
    uvm_root::get().set_finish_on_completion(0);
    run_test("soc_test");
    reports = uvm_report_server::get_server();
    if (reports.get_severity_count(UVM_ERROR) != 0 || reports.get_severity_count(UVM_FATAL) != 0)
      $fatal(1, "SoC environment reported errors");
    $display("** UVM SOC PASSED **");
    $finish;
  end
  initial begin
    #10000000;
    $fatal(1, "SOC simulation timed out");
  end
endmodule
