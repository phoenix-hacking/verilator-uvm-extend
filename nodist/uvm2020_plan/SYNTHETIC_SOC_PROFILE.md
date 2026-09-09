<!-- DESCRIPTION: Verilator: Synthetic SoC UVM acceptance profile
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# Synthetic SoC profile

The original M16 contract requires CSR/RAL, DMA, interrupts, reset, clocks,
coverage, DPI and fixed-seed replay in a synthetic RTL/UVM environment. This
profile defines the executable checks; [tracker.yaml](tracker.yaml) records
acceptance separately. Full compliance, release and performance requirements
remain governed by [GOALS.md](GOALS.md).

## Hardware and firmware flow

[t_uvm_soc](../../test_regress/t/t_uvm_soc.py) instantiates an APB CSR interface,
a byte DMA engine and a 512-byte AXI-lite memory. The clocks have periods 10 and
14 simulation time units. A synchronized toggle mailbox carries stable command
fields across the clock boundary and returns completion. Busy clears on the same
CSR edge that latches completion pending. Firmware cannot observe a false idle
window between those updates.

| Byte offset | Register behavior |
|---:|---|
| 0 | Source byte address, read/write while idle |
| 4 | Destination byte address, read/write while idle |
| 8 | Transfer byte count, read/write while idle |
| 12 | Write one to start; command writes while busy are rejected |
| 16 | Read-only status: bit 0 busy, bit 1 completion pending |
| 20 | Interrupt enable, bit 0 |
| 24 | Completion pending; write one to clear |

Commands copy 1 through 63 bytes from the lower 256-byte source region to the
upper 256-byte destination region. The DMA reads aligned words, selects each
source byte, and uses the corresponding destination byte enable. Source and
destination offsets exercise all four alignments and cross word boundaries.
Memory initializes byte `i` to `((37*i) XOR (i/4) XOR 90) modulo 256` on reset.
Independent AW/W acceptance and backpressure on all five AXI channels exercise
request/response ownership. The APB and AXI assertions retain their established
physical-sample trace format and independent protocol oracle.

The UVM register model drives real frontdoor transactions through its adapter,
sequencer and driver. Firmware programs source/destination/count/mask, checks
readback, starts DMA, polls status, verifies masked/unmasked interrupt behavior,
clears pending and checks the resulting memory. Passive UVM monitors feed the
scoreboard and coverage subscriber. A reset interrupts an active 63-byte transfer
after at least three observed writes. No stale work or IRQ may survive; a fresh
command must then complete. An invalid CSR read checks error reporting.

## Independent checks and matrix

The source matrix uses clean, unmodified UVM 2020.3.1 at
`78c06547a2a0a29b3dc9dcafae62b75b2ff61544`, with DPI off/on and one/two
simulation threads. Each configuration executes seeds 1729, 1729 and 2718 with
four regular commands, plus seed 314159 with nine. Every run also executes the
reset-canceled command and the recovery command. `SOC_JOBS` accepts 4 through 64;
this scales workload length while keeping one DMA engine and the same memory.
It does not claim multiple initiators or a larger hardware interconnect.

[The independent Python oracle](../../test_regress/t/uvm_soc_common.py) checks
command/register agreement, every DMA read and byte write, all 512 bytes of each
reported memory image including untouched locations, complete/canceled counts,
IRQ ordering, reset epochs, and deterministic traces. It reconstructs APB/AXI
transactions and IRQ transitions from sampled pins and matches them to UVM
observations. Deliberately corrupted trace fields must be rejected.

The coverage database contains twelve normal bins: four event kinds, two
transaction directions, two CSR responses and four byte lanes. Each count must
match independently checked observations. Different-seed files merge by exact
hit-count addition; the LCOV report must match each branch/line count and the
coverpoint source locations.

The DPI configuration compiles [the reference](../../test_regress/t/t_uvm_soc.c)
as C11, enforced by rejecting C++ compilation. It builds the specified initial
image and uses `memmove` to calculate the result independently of RTL/UVM state.
Each reported memory byte is checked through the C DPI ABI. No-DPI runs retain
the SV/Python checks and claim no C execution.

Fault runs corrupt DMA write data, suppress IRQ, assert IRQ prematurely, resume
canceled DMA work after reset, and corrupt the C result in DPI mode. Each must
reach its intended stimulus and first diagnostic without a success sentinel.

The named `uvm2020-soc-source` target runs the source matrix with one driver and
one build job and checks stale-artifact cleanup. CI uses that target with the
same pinned library and verifies the library remains clean. A configured CI
lane is not evidence that it has passed; its result must be inspected separately.

## Claim boundaries

This fixture establishes a bounded synthetic SoC profile, not arbitrary AXI
bursts, coherency, all RAL policies, every clock-domain crossing, or complete UVM
conformance. Other mandatory requirements remain open under their own gates.
C09 and C13 require verified M16 evidence; C21 also requires M17 and reproducible
nightly execution. Simulation duration alone is not production performance proof.
