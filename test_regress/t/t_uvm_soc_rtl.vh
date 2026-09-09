// -*- Verilog -*-
// DESCRIPTION: Verilator: Synthetic SoC CSR mailbox, byte DMA and AXI-lite memory
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// APB register contract, byte offsets:
// 0 source, 4 destination, 8 byte count, 12 start (write one),
// 16 status {pending,busy}, 20 interrupt enable, 24 pending (write one clears).
// Source/destination/count are stable while busy. A toggle mailbox crosses from
// the CSR clock into the DMA clock; completion uses the reverse toggle crossing.
module soc_dma (
    soc_apb_if csr,
    soc_axi_if mem,
    output logic irq
);
  logic [31:0] source, destination, length;
  logic request, acknowledge, ack_meta, ack_sync, ack_seen;
  logic req_meta, req_sync;
  logic pending, irq_enable;
  logic [1:0] csr_wait;
  // Consume completion and release busy on the same CSR edge.
  wire busy = request != ack_seen;
  typedef enum logic [2:0] {
    IDLE,
    READ_ADDR,
    READ_DATA,
    WRITE_DATA,
    WRITE_RESP
  } state_t;
  state_t state;
  logic [8:0] from_addr, to_addr;
  logic [31:0] remaining;
  logic [7:0] octet;
  logic address_sent, data_sent;
  logic [3:0] cycles;
  bit corrupt_data, suppress_irq, spurious_irq, resume_canceled;
  initial begin
    corrupt_data = $test$plusargs("SOC_CORRUPT_DATA");
    resume_canceled = $test$plusargs("SOC_RESUME_CANCELED");
    suppress_irq = $test$plusargs("SOC_SUPPRESS_IRQ");
    spurious_irq = $test$plusargs("SOC_SPURIOUS_IRQ");
  end
  assign irq = (pending && irq_enable && !suppress_irq) || (spurious_irq && busy);
  assign csr.ready = csr.sel && csr.enable && csr_wait == 0;
  assign csr.error = csr.ready && (csr.addr > 24 || csr.addr[1:0] != 0
      || (csr.write && (csr.addr == 16 || (busy && csr.addr <= 12)))
      || (csr.write && csr.addr == 12 && csr.wdata[0]
          && (length == 0 || length > 63 || source + length > 256
              || destination < 256 || destination + length > 512)));
  always_comb begin
    case (csr.addr)
      0: csr.rdata = source;
      4: csr.rdata = destination;
      8: csr.rdata = length;
      16: csr.rdata = {30'b0, pending, busy};
      20: csr.rdata = {31'b0, irq_enable};
      24: csr.rdata = {31'b0, pending};
      default: csr.rdata = 0;
    endcase
  end
  always @(posedge csr.clk or negedge csr.reset_n) begin
    if (!csr.reset_n) begin
      source <= 0;
      destination <= 0;
      length <= 0;
      request <= 0;
      ack_meta <= 0;
      ack_sync <= 0;
      ack_seen <= 0;
      pending <= 0;
      irq_enable <= 0;
      csr_wait <= 0;
    end
    else begin
      ack_meta <= acknowledge;
      ack_sync <= ack_meta;
      ack_seen <= ack_sync;
      if (csr.sel && !csr.enable) csr_wait <= 2'(csr.addr[3:2] % 3);
      else if (csr_wait != 0) csr_wait <= csr_wait - 1;
      if (csr.ready && csr.write && !csr.error) begin
        for (int lane = 0; lane < 4; lane++) begin
          if (csr.strb[lane]) begin
            case (csr.addr)
              0: source[lane*8+:8] <= csr.wdata[lane*8+:8];
              4: destination[lane*8+:8] <= csr.wdata[lane*8+:8];
              8: length[lane*8+:8] <= csr.wdata[lane*8+:8];
              default: ;
            endcase
          end
        end
        if (csr.strb[0]) begin
          case (csr.addr)
            12: if (csr.wdata[0]) request <= !request;
            20: irq_enable <= csr.wdata[0];
            24: if (csr.wdata[0]) pending <= 0;
            default: ;
          endcase
        end
      end
      // A simultaneous completion wins over a software clear.
      if (ack_sync != ack_seen) pending <= 1;
    end
  end

  assign mem.arvalid = mem.reset_n && state == READ_ADDR;
  assign mem.araddr = {from_addr[8:2], 2'b0};
  assign mem.arprot = 0;
  assign mem.rready = state == READ_DATA && cycles[1:0] == 0;
  assign mem.awvalid = mem.reset_n && state == WRITE_DATA && !address_sent;
  assign mem.awaddr = {to_addr[8:2], 2'b0};
  assign mem.awprot = 0;
  assign mem.wvalid = mem.reset_n && state == WRITE_DATA && !data_sent;
  assign mem.wdata = (32'(octet) ^ (corrupt_data ? 32'h1 : 32'h0)) << (8 * to_addr[1:0]);
  assign mem.wstrb = 4'b1 << to_addr[1:0];
  assign mem.bready = state == WRITE_RESP && cycles[1:0] == 0;
  always @(posedge mem.clk or negedge mem.reset_n) begin
    if (!mem.reset_n) begin
      state <= resume_canceled && state != IDLE ? READ_ADDR : IDLE;
      req_meta <= 0;
      req_sync <= 0;
      acknowledge <= 0;
      from_addr <= 0;
      to_addr <= 0;
      remaining <= 0;
      octet <= 0;
      address_sent <= 0;
      data_sent <= 0;
      cycles <= 0;
    end
    else begin
      cycles <= cycles + 1;
      req_meta <= request;
      req_sync <= req_meta;
      case (state)
        IDLE:
        if (req_sync != acknowledge) begin
          from_addr <= 9'(source);
          to_addr <= 9'(destination);
          remaining <= length;
          state <= READ_ADDR;
        end
        READ_ADDR: if (mem.arready) state <= READ_DATA;
        READ_DATA:
        if (mem.rvalid && mem.rready) begin
          octet <= 8'(mem.rdata >> (8 * from_addr[1:0]));
          address_sent <= 0;
          data_sent <= 0;
          state <= WRITE_DATA;
        end
        WRITE_DATA: begin
          if (mem.awvalid && mem.awready) address_sent <= 1;
          if (mem.wvalid && mem.wready) data_sent <= 1;
          if ((address_sent || mem.awready) && (data_sent || mem.wready)) state <= WRITE_RESP;
        end
        WRITE_RESP:
        if (mem.bvalid && mem.bready) begin
          if (remaining == 1) begin
            acknowledge <= req_sync;
            state <= IDLE;
          end
          else begin
            from_addr <= from_addr + 1;
            to_addr <= to_addr + 1;
            remaining <= remaining - 1;
            state <= READ_ADDR;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule

module soc_memory (
    soc_axi_if bus
);
  logic [7:0] storage[512];
  logic have_address, have_data;
  logic [8:0] address;
  logic [31:0] data;
  logic [3:0] strobes;
  logic [3:0] cycles;
  assign bus.awready = bus.reset_n && !have_address && !bus.bvalid && cycles[1:0] == 2;
  assign bus.wready = bus.reset_n && !have_data && !bus.bvalid && cycles[1:0] == 3;
  assign bus.arready = bus.reset_n && !bus.rvalid && cycles[1:0] == 2;
  assign bus.bresp = 0;
  assign bus.rresp = 0;
  always @(posedge bus.clk or negedge bus.reset_n) begin
    if (!bus.reset_n) begin
      for (int i = 0; i < 512; i++) storage[i] <= 8'((i * 37) ^ (i >> 2) ^ 8'h5a);
      have_address <= 0;
      have_data <= 0;
      address <= 0;
      data <= 0;
      strobes <= 0;
      bus.bvalid <= 0;
      bus.rvalid <= 0;
      bus.rdata <= 0;
      cycles <= 0;
    end
    else begin
      cycles <= cycles + 1;
      if (bus.awvalid && bus.awready) begin
        address <= bus.awaddr;
        have_address <= 1;
      end
      if (bus.wvalid && bus.wready) begin
        data <= bus.wdata;
        strobes <= bus.wstrb;
        have_data <= 1;
      end
      if (have_address && have_data && !bus.bvalid) begin
        for (int lane = 0; lane < 4; lane++)
        if (strobes[lane]) storage[32'(address)+lane] <= data[lane*8+:8];
        have_address <= 0;
        have_data <= 0;
        bus.bvalid <= 1;
      end
      if (bus.bvalid && bus.bready) bus.bvalid <= 0;
      if (bus.arvalid && bus.arready) begin
        for (int lane = 0; lane < 4; lane++) bus.rdata[lane*8+:8] <= storage[32'(bus.araddr)+lane];
        bus.rvalid <= 1;
      end
      if (bus.rvalid && bus.rready) bus.rvalid <= 0;
    end
  end
endmodule
