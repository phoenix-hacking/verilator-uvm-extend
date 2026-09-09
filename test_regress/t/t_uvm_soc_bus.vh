// -*- Verilog -*-
// DESCRIPTION: Verilator: APB and AXI-lite interfaces for the synthetic SoC
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Keep the established APB/AXI protocol assertions and physical trace format.
interface soc_apb_if (
    input logic clk
);
  logic reset_n = 0;
  logic sel = 0;
  logic enable = 0;
  logic write = 0;
  logic [7:0] addr = 0;
  logic [31:0] wdata = 0;
  logic [3:0] strb = 0;
  logic ready;
  logic error;
  logic irq;
  logic [31:0] rdata;
  bit check_sva;
  bit trace_protocol;
  logic [31:0] checked_wdata;

  // Only active write lanes carry request data. Read data and inactive
  // write lanes may vary (Arm IHI 0024D, Appendix A signal validity).
  assign checked_wdata = write ? wdata & {{8{strb[3]}}, {8{strb[2]}}, {8{strb[1]}}, {8{strb[0]}}} : 0;

  initial begin
    check_sva = !$test$plusargs("APB_MONITOR_ONLY");
    trace_protocol = $test$plusargs("APB_PROTOCOL_TRACE");
  end
  always @(negedge clk)
    if (trace_protocol)
      $display(
          "APB_SAMPLE %0t %0d %0d %0d %0d %02h %08h %0h %0d",
          $time,
          reset_n,
          sel,
          enable,
          write,
          addr,
          wdata,
          strb,
          ready
      );

  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output reset_n, sel, enable, write, addr, wdata, strb;
    input ready, error, rdata;
  endclocking
  clocking monitor_cb @(posedge clk);
    default input #1step output #0;
    input reset_n, sel, enable, write, addr, wdata, strb, ready, error, rdata, irq;
  endclocking
  modport driver_mp(clocking driver_cb);
  modport monitor_mp(clocking monitor_cb);

  function automatic void protocol_error(string rule);
    // The driver requires a success sentinel on every positive run and this
    // exact assertion marker on each deliberately corrupted negative run.
    $display("APB_ASSERTION %s time=%0t", rule, $time);
    $finish;
  endfunction

  // Setup lasts one cycle; request fields persist through a stalled access.
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva)
                   sel && !enable |=> sel && enable
                   && $stable(
      {addr, write, checked_wdata, strb}
  ))
  else protocol_error("setup");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva)
                   sel && enable && !ready |=> sel && enable
                   && $stable(
      {addr, write, checked_wdata, strb}
  ))
  else protocol_error("wait");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva) enable |-> sel)
  else protocol_error("select");
  assert property (@(posedge clk) disable iff (!reset_n || !check_sva) sel && !write |-> strb == 0)
  else protocol_error("strobe");
endinterface

interface soc_axi_if (
    input logic clk
);
  logic reset_n = 0;
  logic awvalid = 0;
  logic [8:0] awaddr = 0;
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
  logic [8:0] araddr = 0;
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
