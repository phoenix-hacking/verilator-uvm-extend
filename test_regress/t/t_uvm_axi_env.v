// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM AXI4-Lite independent channels, backpressure, and reset
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Protocol oracle: Arm IHI 0022H A3.1-A3.3 and B1.1.
// https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf
// One outstanding transaction per direction, with reads and writes concurrent.
// Concurrent requests use different words; same-word read/write ordering is not
// specified by this fixture. The peripheral defines 16 RW words, all byte masks,
// and SLVERR/no modification for out-of-range or unaligned addresses.

interface axi_if (
    input logic clk
);
  logic reset_n = 0;
  logic awvalid = 0;
  logic [7:0] awaddr = 0;
  logic [2:0] awprot = 0;
  logic awready;
  logic wvalid = 0;
  logic [31:0] wdata = 0;
  logic [3:0] wstrb = 0;
  logic wready;
  logic bvalid;
  logic [1:0] bresp;
  logic bready = 0;
  logic arvalid = 0;
  logic [7:0] araddr = 0;
  logic [2:0] arprot = 0;
  logic arready;
  logic rvalid;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic rready = 0;
  bit check_sva;
  bit trace_protocol;

  initial begin
    check_sva = !$test$plusargs("AXI_MONITOR_ONLY");
    trace_protocol = $test$plusargs("AXI_PROTOCOL_TRACE");
  end
  always @(negedge clk)
    if (trace_protocol)
      $display(
          "AXI_SAMPLE %0t %0d %0d %0d %02h %0h %0d %0d %08h %0h %0d %0d %0h %0d %0d %02h %0h %0d %0d %08h %0h",
          $time,
          reset_n,
          awvalid,
          awready,
          awaddr,
          awprot,
          wvalid,
          wready,
          wdata,
          wstrb,
          bvalid,
          bready,
          bresp,
          arvalid,
          arready,
          araddr,
          arprot,
          rvalid,
          rready,
          rdata,
          rresp
      );

  function automatic void protocol_error(string rule);
    $display("AXI_ASSERTION %s time=%0t", rule, $time);
    $fatal(1, "AXI_SVA_%s", rule);
  endfunction
  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output reset_n, awvalid, awaddr, awprot, wvalid, wdata, wstrb, bready;
    output arvalid, araddr, arprot, rready;
    input awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp;
  endclocking
  clocking monitor_cb @(posedge clk);
    default input #1step output #0;
    input reset_n, awvalid, awaddr, awprot, awready, wvalid, wdata, wstrb, wready;
    input bvalid, bresp, bready, arvalid, araddr, arprot, arready;
    input rvalid, rdata, rresp, rready;
  endclocking
  modport driver_mp(clocking driver_cb);
  modport monitor_mp(clocking monitor_cb);

  // Arm IHI 0022H A3.1.2 requires both interfaces to clear VALID during reset.
  assert property (@(posedge clk) disable iff (!check_sva)
                   !reset_n |-> {awvalid, wvalid, bvalid, arvalid, rvalid} == 0)
  else protocol_error("RESET_VALID");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva)
                   awvalid && !awready |=> awvalid && $stable(
      {awaddr, awprot}
  ))
  else protocol_error("AW_STABLE");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva)
                   wvalid && !wready |=> wvalid && $stable(
      {wdata, wstrb}
  ))
  else protocol_error("W_STABLE");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva)
                   bvalid && !bready |=> bvalid && $stable(
      bresp
  ))
  else protocol_error("B_STABLE");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva)
                   arvalid && !arready |=> arvalid && $stable(
      {araddr, arprot}
  ))
  else protocol_error("AR_STABLE");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva)
                   rvalid && !rready |=> rvalid && $stable(
      {rdata, rresp}
  ))
  else protocol_error("R_STABLE");
endinterface

module axi_regs (
    axi_if bus
);
  logic [31:0] words[16];
  bit have_aw;
  bit have_w;
  bit [7:0] address;
  bit [31:0] data;
  bit [3:0] strobe;
  int unsigned cycle;
  bit corrupt_data;
  bit corrupt_protocol;
  bit corrupt_b_payload;
  bit corrupt_b_valid;
  bit corrupt_r_valid;
  bit corrupt_reset_b;
  bit corrupt_reset_r;

  initial begin
    corrupt_data = $test$plusargs("AXI_CORRUPT_DATA");
    corrupt_protocol = $test$plusargs("AXI_CORRUPT_PROTOCOL") ||
        $test$plusargs("AXI_CORRUPT_R_PAYLOAD");
    corrupt_b_payload = $test$plusargs("AXI_CORRUPT_B_PAYLOAD");
    corrupt_b_valid = $test$plusargs("AXI_CORRUPT_B_VALID");
    corrupt_r_valid = $test$plusargs("AXI_CORRUPT_R_VALID");
    corrupt_reset_b = $test$plusargs("AXI_CORRUPT_RESET_B");
    corrupt_reset_r = $test$plusargs("AXI_CORRUPT_RESET_R");
  end
  // READY depends only on local registered state, never a channel input.
  assign bus.awready = !have_aw && !bus.bvalid && cycle % 4 != 1;
  assign bus.wready = !have_w && !bus.bvalid && cycle % 4 != 3;
  assign bus.arready = !bus.rvalid && cycle % 3 != 1;

  always @(posedge bus.clk or negedge bus.reset_n) begin
    if (!bus.reset_n) begin
      for (int i = 0; i < 16; i++) words[i] <= 32'hc7000000 + 32'(i);
      cycle <= 0;
      have_aw <= 0;
      have_w <= 0;
      address <= 0;
      data <= 0;
      strobe <= 0;
      bus.bvalid <= corrupt_reset_b;
      bus.bresp <= 0;
      bus.rvalid <= corrupt_reset_r;
      bus.rdata <= 0;
      bus.rresp <= 0;
    end
    else begin
      cycle <= cycle + 1;
      if (bus.awvalid && bus.awready) begin
        have_aw <= 1;
        address <= bus.awaddr;
      end
      if (bus.wvalid && bus.wready) begin
        have_w <= 1;
        data <= bus.wdata;
        strobe <= bus.wstrb;
      end
      if (have_aw && have_w && !bus.bvalid) begin
        have_aw <= 0;
        have_w <= 0;
        bus.bvalid <= 1;
        bus.bresp <= address >= 64 || address % 4 != 0 ? 2'b10 : 2'b00;
        if (address < 64 && address % 4 == 0)
          for (int lane = 0; lane < 4; lane++)
          if (strobe[lane]) words[address/4][lane*8+:8] <= data[lane*8+:8];
      end
      if (bus.bvalid && bus.bready) bus.bvalid <= 0;
      if (bus.arvalid && bus.arready) begin
        bus.rvalid <= 1;
        bus.rresp <= bus.araddr >= 64 || bus.araddr % 4 != 0 ? 2'b10 : 2'b00;
        bus.rdata <= (bus.araddr < 64 ? words[bus.araddr/4] : 32'hbad0bad0)
                     ^ (corrupt_data ? 32'b1 : 32'b0);
      end
      if (bus.rvalid && bus.rready) bus.rvalid <= 0;
      // Deliberately violate the hold rule only in the causal negative runs.
      if (corrupt_protocol && bus.rvalid && !bus.rready) bus.rdata <= bus.rdata ^ 32'b1;
      if (corrupt_r_valid && bus.rvalid && !bus.rready) bus.rvalid <= 0;
      if (corrupt_b_payload && bus.bvalid && !bus.bready) bus.bresp <= bus.bresp ^ 2'b10;
      if (corrupt_b_valid && bus.bvalid && !bus.bready) bus.bvalid <= 0;
    end
  end
endmodule

module t;
  import uvm_pkg::*;
  bit clk;
  always #5 clk = !clk;
  axi_if bus (clk);
  axi_regs dut (bus);

  class axi_item extends uvm_sequence_item;
    `uvm_object_utils(axi_item)
    bit wr;
    bit rd;
    bit cancel;
    bit reset;
    bit [7:0] addr;
    bit [7:0] read_addr;
    bit [31:0] data;
    bit [31:0] read_data;
    bit [3:0] strb;
    bit [1:0] response;
    bit [1:0] read_response;
    int aw_delay;
    int w_delay;
    int ar_delay;
    int b_delay;
    int r_delay;
    int ordering;
    time aw_accepted_at;
    time w_accepted_at;
    function new(string name = "axi_item");
      super.new(name);
    endfunction
  endclass

  class axi_config extends uvm_object;
    `uvm_object_utils(axi_config)
    uvm_active_passive_enum mode = UVM_ACTIVE;
    virtual axi_if.driver_mp driver_vif;
    virtual axi_if.monitor_mp monitor_vif;
    function new(string name = "axi_config");
      super.new(name);
    endfunction
  endclass

  class axi_driver extends uvm_driver #(axi_item);
    `uvm_component_utils(axi_driver)
    virtual axi_if.driver_mp vif;
    int writes;
    int reads;
    int cancelled;
    time last_clock;
    int aligned_requests;
    int immediate_requests;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task tick();
      @(vif.driver_cb);
      last_clock = $time;
    endtask
    task reset_bus();
      // RAL can request reset between edges. Align before driving reset so
      // all three asserted cycles are visible through the clocking inputs.
      if ($time != last_clock) tick();
      vif.driver_cb.reset_n <= 0;
      vif.driver_cb.awvalid <= 0;
      vif.driver_cb.wvalid <= 0;
      vif.driver_cb.arvalid <= 0;
      vif.driver_cb.bready <= 0;
      vif.driver_cb.rready <= 0;
      if ($test$plusargs("AXI_CORRUPT_RESET_AW")) vif.driver_cb.awvalid <= 1;
      if ($test$plusargs("AXI_CORRUPT_RESET_W")) vif.driver_cb.wvalid <= 1;
      if ($test$plusargs("AXI_CORRUPT_RESET_AR")) vif.driver_cb.arvalid <= 1;
      repeat (3) tick();
      vif.driver_cb.reset_n <= 1;
      tick();
    endtask
    task send_aw(axi_item req);
      repeat (req.aw_delay) tick();
      vif.driver_cb.awaddr <= req.addr;
      vif.driver_cb.awprot <= 0;
      vif.driver_cb.awvalid <= 1;
      do begin
        tick();
        if (!vif.driver_cb.awready) begin
          if ($test$plusargs("AXI_CORRUPT_AW_PAYLOAD")) vif.driver_cb.awaddr <= req.addr ^ 8'h04;
          if ($test$plusargs("AXI_CORRUPT_AW_VALID")) vif.driver_cb.awvalid <= 0;
        end
      end while (!vif.driver_cb.awready);
      req.aw_accepted_at = $time;
      vif.driver_cb.awvalid <= 0;
    endtask
    task send_w(axi_item req);
      repeat (req.w_delay) tick();
      vif.driver_cb.wdata <= req.data;
      vif.driver_cb.wstrb <= req.strb;
      vif.driver_cb.wvalid <= 1;
      do begin
        tick();
        if (!vif.driver_cb.wready) begin
          if ($test$plusargs("AXI_CORRUPT_W_PAYLOAD")) vif.driver_cb.wdata <= req.data ^ 32'b1;
          if ($test$plusargs("AXI_CORRUPT_W_VALID")) vif.driver_cb.wvalid <= 0;
        end
      end while (!vif.driver_cb.wready);
      req.w_accepted_at = $time;
      vif.driver_cb.wvalid <= 0;
    endtask
    task send_ar(axi_item req);
      repeat (req.ar_delay) tick();
      vif.driver_cb.araddr <= req.read_addr;
      vif.driver_cb.arprot <= 0;
      vif.driver_cb.arvalid <= 1;
      do begin
        tick();
        if (!vif.driver_cb.arready) begin
          if ($test$plusargs("AXI_CORRUPT_AR_PAYLOAD"))
            vif.driver_cb.araddr <= req.read_addr ^ 8'h04;
          if ($test$plusargs("AXI_CORRUPT_AR_VALID")) vif.driver_cb.arvalid <= 0;
        end
      end while (!vif.driver_cb.arready);
      vif.driver_cb.arvalid <= 0;
    endtask
    task write_transfer(axi_item req, axi_item rsp);
      fork
        send_aw(req);
        send_w(req);
      join
      do tick(); while (!vif.driver_cb.bvalid);
      repeat (req.b_delay) tick();
      vif.driver_cb.bready <= 1;
      tick();
      rsp.response = vif.driver_cb.bresp;
      if (!vif.driver_cb.bvalid) `uvm_fatal("AXI_DRIVER", "write response was withdrawn")
      vif.driver_cb.bready <= 0;
      writes++;
      rsp.ordering = req.aw_accepted_at < req.w_accepted_at ? 0
                     : (req.aw_accepted_at > req.w_accepted_at ? 1 : 2);
      $display("AXI_TRACE W %0h %0h %0h %0d %0d", req.addr, req.data, req.strb, rsp.response,
               rsp.ordering);
    endtask
    task read_transfer(axi_item req, axi_item rsp);
      send_ar(req);
      do tick(); while (!vif.driver_cb.rvalid);
      repeat (req.r_delay) tick();
      vif.driver_cb.rready <= 1;
      tick();
      rsp.read_response = vif.driver_cb.rresp;
      rsp.read_data = vif.driver_cb.rdata;
      if ($test$plusargs("AXI_CORRUPT_RAL_RESPONSE")) rsp.read_data ^= 32'b1;
      // RAL requests use one direction. Normalize their response just like
      // monitor transactions; combined transport requests retain both results.
      if (!req.wr) begin
        rsp.data = rsp.read_data;
        rsp.response = rsp.read_response;
      end
      if (!vif.driver_cb.rvalid) `uvm_fatal("AXI_DRIVER", "read response was withdrawn")
      vif.driver_cb.rready <= 0;
      reads++;
      $display("AXI_TRACE R %0h %0h 0 %0d 0", req.read_addr, rsp.read_data, rsp.read_response);
    endtask
    virtual task run_phase(uvm_phase phase);
      tick();
      reset_bus();
      forever begin
        axi_item req;
        axi_item rsp;
        seq_item_port.get_next_item(req);
        // A clocking output issued between edges is applied at the next
        // clocking event. Align before asserting VALID so READY at that event
        // cannot be mistaken for a transfer that the DUT has not sampled.
        if ($time != last_clock) begin
          tick();
          aligned_requests++;
        end
        else immediate_requests++;
        rsp = axi_item::type_id::create("response");
        rsp.set_id_info(req);
        rsp.wr = req.wr;
        rsp.rd = req.rd;
        rsp.addr = req.wr ? req.addr : req.read_addr;
        rsp.data = req.data;
        rsp.strb = req.strb;
        if (req.cancel) begin
          // AW is accepted without W, while a separate read waits for RREADY.
          fork
            send_aw(req);
            send_ar(req);
          join
          do tick(); while (!vif.driver_cb.rvalid);
          if (vif.driver_cb.bvalid)
            `uvm_fatal("AXI_CANCEL", "write response preceded its write data")
          reset_bus();
          rsp.cancel = 1;
          cancelled++;
        end
        else begin
          fork
            if (req.wr) write_transfer(req, rsp);
            if (req.rd) read_transfer(req, rsp);
          join
        end
        seq_item_port.item_done(rsp);
      end
    endtask
  endclass

  class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)
    virtual axi_if.monitor_mp vif;
    uvm_analysis_port #(axi_item) observed;
    int reads;
    int writes;
    int resets;
    int reset_cycles;
    int cancelled_aw;
    int cancelled_read;
    int order_counts[3];
    int stalled[5];
    int overlap_cycles;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      observed = new("observed", this);
    endfunction
    virtual task run_phase(uvm_phase phase);
      axi_item wr;
      axi_item rd;
      bit have_aw;
      bit have_w;
      bit in_reset;
      bit prev_stall[5];
      bit [10:0] old_aw;
      bit [35:0] old_w;
      bit [1:0] old_b;
      bit [10:0] old_ar;
      bit [33:0] old_r;
      int cycle_count;
      int aw_cycle;
      int w_cycle;
      if ($test$plusargs("AXI_SVA_ONLY")) return;
      forever begin
        @(vif.monitor_cb);
        cycle_count++;
        if (!vif.monitor_cb.reset_n) begin
          if ({vif.monitor_cb.awvalid, vif.monitor_cb.wvalid, vif.monitor_cb.bvalid,
               vif.monitor_cb.arvalid, vif.monitor_cb.rvalid} !== 0) begin
            `uvm_fatal("AXI_PROTOCOL", "VALID was asserted during reset")
            return;
          end
          reset_cycles++;
          if (!in_reset) begin
            axi_item item = axi_item::type_id::create("reset");
            item.reset = 1;
            if (have_aw) cancelled_aw++;
            if (rd != null) cancelled_read++;
            observed.write(item);
            resets++;
          end
          wr = null;
          rd = null;
          have_aw = 0;
          have_w = 0;
          foreach (prev_stall[i]) prev_stall[i] = 0;
          in_reset = 1;
        end
        else begin
          in_reset = 0;
          if (prev_stall[0] && (!vif.monitor_cb.awvalid
              || {vif.monitor_cb.awaddr, vif.monitor_cb.awprot} !== old_aw))
            `uvm_fatal("AXI_PROTOCOL", "AW payload changed or VALID dropped while stalled")
          if (prev_stall[1] && (!vif.monitor_cb.wvalid
              || {vif.monitor_cb.wdata, vif.monitor_cb.wstrb} !== old_w))
            `uvm_fatal("AXI_PROTOCOL", "W payload changed or VALID dropped while stalled")
          if (prev_stall[2] && (!vif.monitor_cb.bvalid || vif.monitor_cb.bresp !== old_b))
            `uvm_fatal("AXI_PROTOCOL", "B payload changed or VALID dropped while stalled")
          if (prev_stall[3] && (!vif.monitor_cb.arvalid
              || {vif.monitor_cb.araddr, vif.monitor_cb.arprot} !== old_ar))
            `uvm_fatal("AXI_PROTOCOL", "AR payload changed or VALID dropped while stalled")
          if (prev_stall[4] && (!vif.monitor_cb.rvalid
              || {vif.monitor_cb.rdata, vif.monitor_cb.rresp} !== old_r))
            `uvm_fatal("AXI_PROTOCOL", "R payload changed or VALID dropped while stalled")
          prev_stall[0] = vif.monitor_cb.awvalid && !vif.monitor_cb.awready;
          prev_stall[1] = vif.monitor_cb.wvalid && !vif.monitor_cb.wready;
          prev_stall[2] = vif.monitor_cb.bvalid && !vif.monitor_cb.bready;
          prev_stall[3] = vif.monitor_cb.arvalid && !vif.monitor_cb.arready;
          prev_stall[4] = vif.monitor_cb.rvalid && !vif.monitor_cb.rready;
          old_aw = {vif.monitor_cb.awaddr, vif.monitor_cb.awprot};
          old_w = {vif.monitor_cb.wdata, vif.monitor_cb.wstrb};
          old_b = vif.monitor_cb.bresp;
          old_ar = {vif.monitor_cb.araddr, vif.monitor_cb.arprot};
          old_r = {vif.monitor_cb.rdata, vif.monitor_cb.rresp};
          foreach (prev_stall[i]) if (prev_stall[i]) stalled[i]++;

          // Validate response dependencies before accepting this cycle's new
          // addresses or data: AXI responses cannot acknowledge them early.
          if (vif.monitor_cb.bvalid && (!have_aw || !have_w)) begin
            `uvm_fatal("AXI_PROTOCOL", "BVALID preceded accepted AW and W")
            return;
          end
          if (vif.monitor_cb.rvalid && rd == null) begin
            `uvm_fatal("AXI_PROTOCOL", "RVALID preceded accepted AR")
            return;
          end
          if (vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
            wr.response = vif.monitor_cb.bresp;
            wr.ordering = aw_cycle < w_cycle ? 0 : (aw_cycle > w_cycle ? 1 : 2);
            order_counts[wr.ordering]++;
            observed.write(wr);
            writes++;
            wr = null;
            have_aw = 0;
            have_w = 0;
          end
          if (vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
            rd.data = vif.monitor_cb.rdata;
            rd.response = vif.monitor_cb.rresp;
            observed.write(rd);
            reads++;
            rd = null;
          end
          if (vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
            if (have_aw) `uvm_fatal("AXI_PROTOCOL", "multiple outstanding write addresses")
            if (wr == null) wr = axi_item::type_id::create("observed_write");
            wr.wr = 1;
            wr.addr = vif.monitor_cb.awaddr;
            have_aw = 1;
            aw_cycle = cycle_count;
          end
          if (vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
            if (have_w) `uvm_fatal("AXI_PROTOCOL", "multiple outstanding write data beats")
            if (wr == null) wr = axi_item::type_id::create("observed_write");
            wr.wr = 1;
            wr.data = vif.monitor_cb.wdata;
            wr.strb = vif.monitor_cb.wstrb;
            have_w = 1;
            w_cycle = cycle_count;
          end
          if (vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
            if (rd != null) `uvm_fatal("AXI_PROTOCOL", "multiple outstanding read addresses")
            rd = axi_item::type_id::create("observed_read");
            rd.rd = 1;
            rd.addr = vif.monitor_cb.araddr;
          end
          if ((have_aw || have_w) && rd != null) overlap_cycles++;
        end
      end
    endtask
  endclass

  class axi_scoreboard extends uvm_subscriber #(axi_item);
    `uvm_component_utils(axi_scoreboard)
    bit [31:0] model[16];
    int reads;
    int writes;
    int errors;
    int resets;
    bit [31:0] digest;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void write(axi_item item);
      if (item.reset) begin
        foreach (model[i]) model[i] = 32'hc7000000 + 32'(i);
        resets++;
        return;
      end
      if (item.response != (item.addr >= 64 || item.addr % 4 != 0 ? 2'b10 : 2'b00))
        `uvm_fatal("AXI_SCOREBOARD", "incorrect bus response code")
      if (item.wr) writes++;
      else reads++;
      if (item.response != 0) errors++;
      else if (item.wr) begin
        for (int lane = 0; lane < 4; lane++)
        if (item.strb[lane]) model[item.addr/4][lane*8+:8] = item.data[lane*8+:8];
      end
      else if (item.data !== model[item.addr/4])
        `uvm_fatal(
            "AXI_SCOREBOARD", $sformatf(
            "read mismatch addr=%0h got=%0h expected=%0h", item.addr, item.data, model[item.addr/4]
            ))
      digest = {digest[26:0], digest[31:27]} ^ item.data ^ {24'b0, item.addr};
    endfunction
  endclass

  class axi_coverage extends uvm_subscriber #(axi_item);
    `uvm_component_utils(axi_coverage)
    covergroup transfers with function sample (bit wr, bit err, bit [3:0] strobes, int order);
      direction: coverpoint wr;
      response: coverpoint err;
      byte_enables: coverpoint strobes iff (wr) {bins masks[] = {[0 : 15]};}
      channel_order: coverpoint order iff (wr) {bins orders[] = {[0 : 2]};}
      outcome: cross direction, response;
    endgroup
    function new(string name, uvm_component parent);
      super.new(name, parent);
      transfers = new;
    endfunction
    virtual function void write(axi_item item);
      if (!item.reset) transfers.sample(item.wr, item.response != 0, item.strb, item.ordering);
    endfunction
  endclass

  class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)
    axi_config cfg;
    axi_driver driver;
    axi_monitor monitor;
    uvm_sequencer #(axi_item) sequencer;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(axi_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("AXI_CONFIG", "missing agent configuration")
      monitor = axi_monitor::type_id::create("monitor", this);
      monitor.vif = cfg.monitor_vif;
      if (cfg.mode == UVM_ACTIVE) begin
        driver = axi_driver::type_id::create("driver", this);
        driver.vif = cfg.driver_vif;
        sequencer = new("sequencer", this);
      end
    endfunction
    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (cfg.mode == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class axi_sequence extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_sequence)
    int writes;
    int reads;
    int cancelled;
    function new(string name = "axi_sequence");
      super.new(name);
    endfunction
    task transfer(bit wr, bit rd, bit [7:0] addr, bit [7:0] read_addr, bit [31:0] data = 0,
                  bit [3:0] strb = 15, int ordering = 0, bit cancel = 0);
      axi_item req = axi_item::type_id::create("request");
      axi_item rsp;
      req.wr = wr;
      req.rd = rd;
      req.addr = addr;
      req.read_addr = read_addr;
      req.data = data;
      req.strb = strb;
      req.aw_delay = ordering == 1 ? 4 : 0;
      req.w_delay = ordering == 0 ? 4 : 0;
      req.ar_delay = ordering % 2;
      req.b_delay = ordering;
      req.r_delay = ordering + 1;
      req.cancel = cancel;
      start_item(req);
      finish_item(req);
      get_response(rsp);
      if (rsp.cancel != cancel) `uvm_fatal("AXI_RESPONSE", "incorrect reset cancellation")
      if (cancel) cancelled++;
      else begin
        if (wr && rsp.response != (addr >= 64 || addr % 4 != 0 ? 2'b10 : 2'b00))
          `uvm_fatal("AXI_RESPONSE", "driver returned incorrect write status")
        if (rd && rsp.read_response != (read_addr >= 64 || read_addr % 4 != 0 ? 2'b10 : 2'b00))
          `uvm_fatal("AXI_RESPONSE", "driver returned incorrect read status")
        if (wr) writes++;
        if (rd) reads++;
      end
    endtask
    virtual task body();
      for (int i = 0; i < 16; i++) transfer(0, 1, 0, 8'(i * 4));
      for (int i = 0; i < 16; i++) begin
        transfer(1, 1, 8'(i * 4), 8'((i ^ 8) * 4), $urandom, 4'(i), i % 3);
        transfer(0, 1, 0, 8'(i * 4));
      end
      transfer(1, 1, 8'h80, 8'h80, 32'hbadbad00);
      transfer(1, 1, 8'h03, 8'h03, 32'h12345678);
      // Check every word before reset can hide an erroneous rejected write.
      for (int i = 0; i < 16; i++) transfer(0, 1, 0, 8'(i * 4));
      transfer(1, 1, 8'h04, 8'h24, 32'hcafecafe, 15, 0, 1);
      for (int i = 0; i < 16; i++) transfer(0, 1, 0, 8'(i * 4));
      repeat (32) begin
        bit [7:0] addr = 8'($urandom_range(0, 7) * 4);
        transfer(1, 1, addr, addr + 8'h20, $urandom, 4'($urandom), int'($urandom_range(0, 2)));
        transfer(0, 1, 0, addr);
      end
    endtask
  endclass

  `include "t_uvm_axi_ral.vh"

  class axi_test extends uvm_test;
    `uvm_component_utils(axi_test)
    axi_agent active_agent;
    axi_agent passive_agent;
    axi_scoreboard active_scoreboard;
    axi_scoreboard passive_scoreboard;
    axi_coverage coverage;
    axi_ral_helper ral;
    axi_sequence sequence_h;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      active_agent = axi_agent::type_id::create("active_agent", this);
      passive_agent = axi_agent::type_id::create("passive_agent", this);
      active_scoreboard = axi_scoreboard::type_id::create("active_scoreboard", this);
      passive_scoreboard = axi_scoreboard::type_id::create("passive_scoreboard", this);
      coverage = axi_coverage::type_id::create("coverage", this);
      ral = axi_ral_helper::type_id::create("ral", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      active_agent.monitor.observed.connect(active_scoreboard.analysis_export);
      passive_agent.monitor.observed.connect(passive_scoreboard.analysis_export);
      passive_agent.monitor.observed.connect(coverage.analysis_export);
      ral.attach(active_agent, passive_agent, active_scoreboard, passive_scoreboard);
    endfunction
    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      sequence_h = axi_sequence::type_id::create("sequence_h");
      sequence_h.start(active_agent.sequencer);
      ral.run_checks();
      repeat (3) @(active_agent.cfg.monitor_vif.monitor_cb);
      phase.drop_objection(this);
    endtask
    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (passive_agent.driver != null || passive_agent.sequencer != null)
        `uvm_fatal("AXI_PASSIVE", "passive agent contains active components")
      if (sequence_h.writes != 50 || sequence_h.reads != 146
          || ral.writes != 1152 || ral.reads != 1120 || ral.completed != 2272
          || active_agent.driver.writes != 1202 || active_agent.driver.reads != 1266
          || active_agent.monitor.writes != 1202 || active_agent.monitor.reads != 1266
          || passive_agent.monitor.writes != 1202 || passive_agent.monitor.reads != 1266
          || active_scoreboard.writes != 1202 || active_scoreboard.reads != 1266
          || passive_scoreboard.writes != 1202 || passive_scoreboard.reads != 1266)
        `uvm_fatal("AXI_COUNT",
                   "driver, monitors and scoreboards did not complete every transaction")
      if (sequence_h.cancelled != 1 || active_agent.driver.cancelled != 1
          || active_agent.monitor.cancelled_aw != 1 || active_agent.monitor.cancelled_read != 1
          || passive_agent.monitor.cancelled_aw != 1 || passive_agent.monitor.cancelled_read != 1
          || active_scoreboard.resets != 5 || passive_scoreboard.resets != 5)
        `uvm_fatal("AXI_RESET", "reset did not discard partial AW and outstanding R transactions")
      if (active_agent.monitor.reset_cycles < 15
          || active_agent.monitor.reset_cycles != passive_agent.monitor.reset_cycles)
        `uvm_fatal("AXI_RESET", $sformatf(
                   "reset cycle counts active=%0d passive=%0d expected at least 15 each",
                   active_agent.monitor.reset_cycles,
                   passive_agent.monitor.reset_cycles
                   ))
      if (active_agent.driver.aligned_requests == 0 || active_agent.driver.immediate_requests == 0)
        `uvm_fatal("AXI_TIMING", "off-edge and immediate requests were not exercised")
      if (coverage.transfers.get_inst_coverage() != 100.0)
        `uvm_fatal("AXI_COVERAGE",
                   "direction, response, byte masks, channel order or cross bins are missing")
      if (active_scoreboard.errors != 4 || passive_scoreboard.errors != 4
          || active_scoreboard.digest != passive_scoreboard.digest)
        `uvm_fatal("AXI_PASSIVE", "active/passive observations or error counts differ")
      foreach (active_agent.monitor.order_counts[i])
      if (active_agent.monitor.order_counts[i] == 0
            || active_agent.monitor.order_counts[i] != passive_agent.monitor.order_counts[i])
        `uvm_fatal("AXI_ORDER",
                   "AW-before-W, W-before-AW or simultaneous acceptance was not checked")
      foreach (active_agent.monitor.stalled[i])
      if (active_agent.monitor.stalled[i] == 0
            || active_agent.monitor.stalled[i] != passive_agent.monitor.stalled[i])
        `uvm_fatal("AXI_STALL", "one of the five channels never experienced backpressure")
      if (active_agent.monitor.overlap_cycles == 0
          || active_agent.monitor.overlap_cycles != passive_agent.monitor.overlap_cycles)
        `uvm_fatal("AXI_OVERLAP", "reads and writes did not overlap")
      $display(
          "AXI_SENTINEL reads=1266 writes=1202 errors=4 resets=5 cancel_aw=1 cancel_r=1 orders=%0d,%0d,%0d stalls=%0d,%0d,%0d,%0d,%0d overlap=%0d",
          active_agent.monitor.order_counts[0], active_agent.monitor.order_counts[1],
          active_agent.monitor.order_counts[2], active_agent.monitor.stalled[0],
          active_agent.monitor.stalled[1], active_agent.monitor.stalled[2],
          active_agent.monitor.stalled[3], active_agent.monitor.stalled[4],
          active_agent.monitor.overlap_cycles);
    endfunction
  endclass

  initial begin
    axi_config active_cfg;
    axi_config passive_cfg;
    uvm_report_server reports;
    active_cfg = axi_config::type_id::create("active_cfg");
    passive_cfg = axi_config::type_id::create("passive_cfg");
    active_cfg.driver_vif = bus.driver_mp;
    active_cfg.monitor_vif = bus.monitor_mp;
    passive_cfg.mode = UVM_PASSIVE;
    passive_cfg.monitor_vif = bus.monitor_mp;
    uvm_config_db#(axi_config)::set(null, "uvm_test_top.active_agent", "cfg", active_cfg);
    uvm_config_db#(axi_config)::set(null, "uvm_test_top.passive_agent", "cfg", passive_cfg);
    uvm_root::get().set_finish_on_completion(0);
    run_test("axi_test");
    reports = uvm_report_server::get_server();
    if (reports.get_severity_count(UVM_ERROR) != 0 || reports.get_severity_count(UVM_FATAL) != 0)
      $fatal(1, "AXI environment reported errors");
    $display("** UVM AXI ENV PASSED **");
    $finish;
  end
  initial begin
    #1000000;
    $fatal(1, "AXI environment timed out");
  end
endmodule
