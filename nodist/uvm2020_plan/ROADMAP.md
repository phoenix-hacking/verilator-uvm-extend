<!-- DESCRIPTION: Verilator: broad UVM 2020 execution roadmap
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020 Execution Plan

This directory is a developer-only planning area for extending this checkout
toward IEEE 1800.2-2020 / Accellera UVM 2020.3.1 support. It is not product
documentation and must not be used to claim implemented user-facing support.

Snapshot: 2026-07-03, repository commit `f82f59a02`.

## Top-Level Objective

The objective is to make this Verilator checkout capable of running a serious
UVM 2020 verification environment for a large functional SoC. "Serious" means
unmodified UVM sources, standard UVM APIs, factory/config/phasing/TLM/sequences,
constrained-random sequence items, covergroups, protocol agents, RAL frontdoor
flows, DPI reference models, a practical VPI/backdoor policy, SVA protocol
checks, repeatable CI, performance tracking, and a synthetic SoC regression that
resembles real verification pressure.

The competitive target is not "implements every obscure IEEE 1800 feature before
any support can be useful." The competitive target is a documented, repeatable
support envelope that lets verification teams bring up real UVM environments,
debug failures, run constrained-random protocol and SoC tests, collect meaningful
coverage, and understand the remaining limits without guesswork.

The plan is deliberately staged. We do not jump straight to a giant SoC test and
call every failure "UVM." We first prove the compiler and runtime semantics that
UVM relies on, then layer UVM APIs on top, then build reusable protocol
environments, and only then raise the difficulty to RAL, coverage closure,
multi-agent traffic, resets, interrupts, DPI scoreboards, and long regressions.

The final story this plan should tell is:

1. This checkout builds reproducibly.
2. Existing UVM smoke tests are baselined honestly.
3. Every UVM failure is reduced to a SystemVerilog semantic, UVM API, runtime,
   or known limitation row.
4. The core UVM library works as a library, not as a pile of local patches.
5. UVM components can build, connect, configure, phase, communicate, randomize,
   sample coverage, and report useful failures.
6. APB and AXI-lite environments prove the feature set in realistic protocol
   testbenches.
7. RAL, SVA, DPI, and VPI/backdoor boundaries are tested or explicitly limited.
8. A synthetic SoC regression proves the pieces together under increasing
   scale, seed variety, reset behavior, coverage pressure, and performance
   constraints.

## Competitive Support Target

The first competitive support claim is earned when Verilator can run a
professional UVM 2020 SoC-style flow with documented limits. It must be strong
enough to compete for digital RTL verification workloads that mostly depend on
UVM classes, virtual interfaces, clocking blocks, constrained random stimulus,
coverage, protocol scoreboards, RAL, DPI models, and repeatable regressions.

| Area | Competitive requirement | Owning milestones |
|---|---|---|
| UVM library | UVM 2020.3.1 compiles/elaborates unmodified in supported DPI and no-DPI modes. | M01, M03, M17 |
| UVM methodology | Factory, config/resource DB, phasing, objections, reporting, TLM, sequences, sequencers, and components work in normal testbench structure. | M03, M07, M08 |
| SystemVerilog classes | Inheritance, virtual methods/tasks, parameterized classes, typedefs, static initialization, casts, dynamic allocation, containers, and strings support UVM usage. | M02, M05 |
| Scheduler/processes | Event regions, zero-delay behavior, wait, fork/join, disable, process kill, finish/stop, and phase shutdown are deterministic. | M02, M04 |
| Interfaces/timing | Virtual interfaces, modports, clocking blocks, class tasks driving DUT signals, and monitor sampling work for protocol agents. | M06, M11, M12 |
| Randomization | Sequence items support practical inline constraints, arrays, size constraints, member selects, seed replay, and actionable diagnostics. | M09 |
| Coverage | Class covergroups in monitors/subscribers can sample, report, and support practical closure dashboards. | M10, M17 |
| Protocol agents | APB and AXI-lite active/passive environments run with scoreboards, coverage, assertions, reset, and backpressure. | M11, M12, M15 |
| RAL | Frontdoor read/write/mirror/update, adapters, predictors, reset/access/bit-bash-style smoke, and explicit backdoor policy are proven. | M13, M14 |
| DPI/VPI boundary | DPI C reference models work; `uvm_hdl_*`/VPI/backdoor behavior is either supported for the target flow or precisely limited. | M14, M18 |
| SoC pressure | Synthetic SoC regression covers CSR/RAL, DMA, interrupts, resets, clocks, multi-agent traffic, coverage, DPI scoreboards, and seed replay. | M16 |
| Professional use | CI shards, dashboards, performance thresholds, reproducible commands, known limitations, and issue coverage exist. | M17, M19 |

These areas are not required for the first competitive claim unless a target UVM
or SoC workload depends on them. They stay tracked as advanced parity limits:

| Advanced parity area | Competitive handling | Owning milestone |
|---|---|---|
| Exhaustive gate/UDP/specify/SDF/timing-check behavior | Document as out of first competitive UVM target unless a SoC workload needs it. | M18 |
| Full PLI/VPI/debug database parity | Support the practical UVM HDL/backdoor subset first; document the rest. | M14, M18 |
| Full four-state commercial-simulator parity | Define two-state/X-initial strategy and document divergence. | M18 |
| Complete SVA language/API/coverage API/UCIS parity | Prove protocol assertion and coverage workflows first; track full parity separately. | M10, M15, M18 |
| Exotic constraints and random stability across all forms | Prioritize UVM sequence-item constraints and seed replay; document unsupported forms. | M09, M18 |
| Transaction recording/database parity | Treat as P2 unless needed by the SoC target; reporting and debug usability remain P1. | M03, M18 |

Competitive claim levels:

| Claim level | Meaning | Minimum proof |
|---|---|---|
| C0 tracked | Plan, matrix, tracker, and issues cover the competitive support envelope. | M00-M19 and leaf issues exist with progress bars. |
| C1 usable UVM core | UVM package, core APIs, scheduler/classes/VIF/randomize/coverage basics pass focused tests. | S0-S3 P0 rows pass or have documented limits. |
| C2 protocol competitive | APB and AXI-lite UVM environments pass with coverage, scoreboards, assertions, and RAL frontdoor. | S4 rows pass in local regression. |
| C3 SoC competitive | Synthetic SoC regression passes with multi-agent random traffic, reset/IRQ/DMA/RAL/DPI/coverage/performance. | S5-S6 acceptance passes in CI. |

## Sophistication Ladder

Later edits must add sophistication by moving down this ladder. A new item may
start at an earlier level, but it should explain which later level will prove it
in a larger workload.

| Stage | Difficulty | Milestones | Proof required before promotion |
|---|---|---|---|
| S0 | Reproducible baseline | M00-M01 | Source-tree build, version capture, existing UVM smoke results. |
| S1 | Language semantics | M02, M04-M06, M09-M10, M14-M15 | Reduced IEEE 1800 tests for classes, scheduler, VIF, randomize, coverage, DPI/VPI, and assertions. |
| S2 | UVM API correctness | M03, M07-M10 | Minimal UVM 1800.2 API tests with result states and known-limit records. |
| S3 | UVM testbench patterns | M07-M10, M13 | Cookbook-style build/connect/config/TLM/sequence/RAL patterns. |
| S4 | Protocol environments | M11-M12, M15 | APB and AXI-lite active/passive agents with scoreboards, assertions, and coverage. |
| S5 | SoC verification pressure | M13-M16 | RAL, DMA, interrupts, reset-mid-traffic, multiple agents, DPI reference checks, seed replay. |
| S6 | Professional support envelope | M17-M19 | CI shards, dashboards, performance thresholds, packaging flow, documented parity limits. |

Every future edit must land in one of these stages and point forward to the next
harder proof. For example, a reduced class fix in S1 should identify the UVM API
test in S2 and the protocol or RAL workload in S4/S5 that will eventually prove
the fix under real verification use.

## Unified Inputs

All requirement sources feed the same objective. None of them creates a separate
roadmap.

| Input | Role in this plan | Tracking rule |
|---|---|---|
| IEEE 1800 SystemVerilog LRM | Defines compiler semantics UVM depends on. | Tracked in `MATRIX.md` IEEE 1800 rows and M02/M04-M06/M09-M10/M14-M15. |
| IEEE 1800.2-2020 UVM standard | Defines required UVM API behavior. | Tracked in `MATRIX.md` UVM rows and M03/M07-M10/M13/M17. |
| Accellera UVM 2020.3.1 package | Main UVM implementation workload. | Tracked by UVM smoke/API/protocol/SoC tests in M01/M03-M17. |
| Attached gameplan | Project scope and execution expectations. | Normalized into milestones, workstreams, issue leaves, and progress bars. |
| External evidence | Gap discovery and regression inspiration. | Folded into objective-owned leaf issues with capability milestones. |
| Cookbook/protocol/SoC workloads | Professional confidence proof. | Tracked by M11-M17 and the protocol/SoC matrix. |

Tracking hierarchy:

| Level | IDs | Meaning |
|---|---|---|
| Objective | O00 | Full UVM 2020 support for complex SoC verification. |
| Stages | S0-S6 | Increasing proof difficulty and sophistication. |
| Milestones | M00-M19 | Capability and evidence-closure milestones. |
| Workstreams | A-W | Compiler/runtime/test areas that implement the milestones. |
| Leaf issues | A01-A20 and future leaves | Concrete observed or standards-derived gaps owned by milestones. |
| Tests | `test_regress` entries and future `uvm_ext` workloads | Executable proof for progress changes. |

## Progress Rules

Every tracked item carries an ASCII progress bar. Percentages are evidence
based, not effort based.

| Percent | Bar | Meaning |
|---:|---|---|
| 0 | `[----------]` | Not baselined or no passing proof. |
| 10 | `[#---------]` | Reduced test or harness stub exists. |
| 25 | `[###-------]` | Reduced IEEE 1800 semantic test passes locally. |
| 40 | `[####------]` | Minimal UVM API test passes locally. |
| 60 | `[######----]` | Cookbook or protocol workload passes locally. |
| 80 | `[########--]` | SoC, performance, or CI shard passes. |
| 100 | `[##########]` | Full acceptance proof, documented limits, and regression coverage. |

Allowed result states:

`NOT_RUN`, `COMPILE_FAIL`, `ELAB_FAIL`, `VERILATE_FAIL`, `BUILD_FAIL`,
`RUN_FAIL`, `TIMEOUT`, `OUTPUT_MISMATCH`, `REFERENCE_MISMATCH`, `PASS`,
`XFAIL_KNOWN`, `WAIVED_DOCUMENTED`.

No feature reaches 100 percent until the reduced test, UVM API test,
larger workload, documentation or limitation record, and relevant regression
lane are all updated.

## Ledger Rule

Every meaningful change must be recorded in `changes.log` before the work
segment is considered complete. This includes roadmap edits, source edits, test
additions, build/test commands, validation commands, GitHub issue updates,
failure classifications, known-limit decisions, and next-step handoffs.

Completion for any roadmap/code/test change requires all applicable artifacts to
agree:

| Artifact | Requirement |
|---|---|
| `changes.log` | Chronological entry with scope, files, issues, commands, result, validation, and next step. |
| `tracker.yaml` | Machine-readable progress/result/issue state when a tracked item changes. |
| `PLAN.md` / `MATRIX.md` | Human-readable support envelope, progress, or evidence update when scope changes. |
| GitHub issue | Issue body/title/comment update when ownership, status, or evidence changes. |
| Regression test or known limitation | Required for semantic fixes, waived behavior, or unsupported competitive-envelope gaps. |

## Repository Overview

Static scan findings used to adjust the original gameplan:

| Area | Progress | Repository anchor | Current evidence |
|---|---:|---|---|
| Tracker creation | `[##########] 100%` | `nodist/uvm2020_plan` | This plan, matrix, and YAML tracker exist. |
| Build baseline | `[##########] 100%` | `autoconf`, `configure.ac`, `Makefile.in` | Source-tree build passed with `autoconf && ./configure --enable-ccwarn && make -j8`; captured log is `run_logs/LEDGER-0008-build-m00-captured-20260703.log`. |
| UVM package smoke | `[########--] 80%` | `test_regress/t/uvm` | UVM 2020.3.1 no-DPI and DPI package hello workloads pass with manual `--build-jobs 1`; default local 8-job harness path resets/interrupts WSL during generated C++ build. |
| UVM hello drivers | `[########--] 80%` | `test_regress/t/t_uvm_hello*.py` | No-DPI and DPI hello executables both print `** UVM TEST PASSED **` under the low-pressure manual equivalent commands. |
| UVM DPI smoke | `[########--] 80%` | `test_regress/t/t_uvm_dpi*.py` | UVM 2020.3.1 HDL API smoke exits 0 and reaches `*-* All Finished *-*` under the low-pressure manual equivalent command. |
| Classes | `[####------] 40%` | `src/V3Class.cpp`, `src/V3Width.cpp`, `src/V3LinkDot.cpp` | C1 class/factory-adjacent shard passed nine existing reduced tests, UVM-FACTORY-0001 passed real UVM object factory create/override through base handles, and UVM-CONFIG-0001 passed component build/report with typed config object propagation; VIF/component-agent depth remains open. |
| Timing/process/fork | `[----------] 0%` | `src/V3Timing.cpp`, `src/V3Fork.cpp`, `include/verilated_timing.h` | C++20 coroutine infrastructure exists; UVM-level process semantics are unbaselined. |
| Scheduler/event regions | `[----------] 0%` | `src/V3Sched*.cpp` | Static scheduler has act/nba flow and timing integration; UVM phase/process proof is unbaselined. |
| Virtual interfaces | `[####------] 40%` | `src/V3SchedVirtIface.cpp`, `src/V3SchedTrigger.cpp` | UVM-CONFIG-VIF-0001 passed virtual interface handle propagation through `uvm_config_db` with live field read/write; clocking/modport/protocol trigger depth remains open. |
| Clocking blocks | `[----------] 0%` | `src/V3AssertPre.cpp`, `src/V3Width.cpp` | Clocking lowering exists; UVM driver/monitor proof is unbaselined. |
| Constrained randomization | `[----------] 0%` | `src/V3Randomize.cpp`, `include/verilated_random.h` | SMT-backed implementation exists; many unsupported constraint forms are visible. |
| Functional coverage | `[----------] 0%` | `src/V3Covergroup.cpp`, `include/verilated_covergroup.h` | Covergroup support exists; static `get_coverage()` aggregation has TODOs. |
| Assertions | `[----------] 0%` | `src/V3Assert*.cpp`, `src/V3AssertNfa.cpp` | Partial assertion support exists; protocol assertion profile is unbaselined. |
| VPI/backdoor | `[###-------] 25%` | `include/verilated_vpi.h`, `include/verilated_vpi.cpp`, `test_regress/t/t_uvm_dpi.v` | UVM 2020.3.1 HDL API smoke passed for check/read/deposit/force/release under manual `--build-jobs 1`; RAL backdoor parity is not proven. |

Observed reduced-test inventory by filename keyword:

| Keyword | Count | Progress |
|---|---:|---:|
| `uvm` | 22 | `[----------] 0%` |
| `class` | 608 | `[###-------] 25%` |
| `random` | 227 | `[----------] 0%` |
| `covergroup` | 122 | `[----------] 0%` |
| `clocking` | 76 | `[----------] 0%` |
| `interface` | 513 | `[----------] 0%` |
| `dpi` | 233 | `[----------] 0%` |
| `vpi` | 152 | `[----------] 0%` |
| `fork` | 128 | `[----------] 0%` |
| `process` | 47 | `[----------] 0%` |
| `queue` | 96 | `[----------] 0%` |
| `assoc` | 59 | `[----------] 0%` |
| `assert` | 195 | `[----------] 0%` |
| `timing` | 218 | `[----------] 0%` |
| `mailbox` | 21 | `[----------] 0%` |
| `semaphore` | 21 | `[----------] 0%` |

These counts are inventory only. They do not imply support until the tests are
run in this checkout and linked to UVM work items.

## Plan Adjustments

The attached gameplan is a good scope definition, but it needs these repository
specific changes:

| Adjustment | Progress | Reason | Action |
|---|---:|---|---|
| Keep roadmap under `nodist` | `[##########] 100%` | `docs/AGENTS.md` says normal docs should document stable implemented behavior. | Use `nodist/uvm2020_plan` until features are real. |
| Baseline before implementation | `[########--] 80%` | Existing UVM, class, randomize, coverage, VIF, and DPI files mean we need evidence, not assumptions. | Source-tree build, UVM smoke, DPI/VPI smoke, and first class shard are recorded; default local harness and remaining semantic shards stay open. |
| Treat UVM as workload, not special case | `[----------] 0%` | Verilator is a compiler; UVM failures should reduce to IEEE 1800 semantics. | Every UVM failure gets L0 reduced proof first. |
| Add machine-readable tracking | `[##########] 100%` | Manual prose will drift over a multi-month effort. | Update `tracker.yaml` and `MATRIX.md` with every task. |
| Split first PRs by subsystem | `[----------] 0%` | Verilator reviewers expect single-purpose changes and tests. | One semantic family per PR: scheduler, class, VIF, randomize, coverage, etc. |
| Defer user guide claims | `[----------] 0%` | User docs must not advertise planned support. | Move to `docs/guide` only after tested support lands. |

## Top-Level Dashboard

Current overall completion estimate: `[##--------] 15%` for the full competitive
SoC-grade UVM 2020 objective. Tracking is mostly complete, C1 core proof is
roughly 40%, and protocol/SoC/RAL/coverage/performance work is still mostly
ahead.

| ID | Objective | Priority | Progress | First command or artifact | Acceptance |
|---|---|---|---:|---|---|
| M00 | Source-tree build and reproducible baseline | P0 | `[##########] 100%` | `run_logs/LEDGER-0008-build-m00-captured-20260703.log` | PASS: build metadata and first dashboard committed. |
| M01 | Existing UVM smoke baseline | P0 | `[########--] 80%` | `run_logs/LEDGER-0014` through `run_logs/LEDGER-0019` | PASS under manual `--build-jobs 1`; default local harness resource policy remains open. |
| M02 | IEEE 1800 P0 semantic audit | P0 | `[#---------] 10%` | `run_logs/LEDGER-0020-c1-class-core-shard-20260703.log` | First class/expression shard PASS; scheduler, VIF, randomize, coverage, and other P0 clauses remain open. |
| M03 | UVM 1800.2 API audit | P0 | `[##--------] 20%` | `run_logs/LEDGER-0026-uvm-factory-basic-v2020-nodpi-clean-20260703.log`, `run_logs/LEDGER-0033-uvm-config-db-basic-v2020-nodpi-clean-20260704.log`, `run_logs/LEDGER-0039-uvm-config-db-vif-v2020-nodpi-rerun-20260703.log` | Factory API, typed config object/component-flow, and VIF config DB shards PASS; phasing, TLM, sequences, reporting depth, and resource precedence remain open. |
| M04 | Scheduler/process/fork closure | P0 | `[----------] 0%` | wait/fork/process reduced shards | UVM phasing, objections, kill, and time advancement are deterministic. |
| M05 | Class/factory/static initialization closure | P0 | `[####------] 40%` | `run_logs/LEDGER-0026-uvm-factory-basic-v2020-nodpi-clean-20260703.log`, `run_logs/LEDGER-0033-uvm-config-db-basic-v2020-nodpi-clean-20260704.log` | Reduced class shard, UVM object factory create/override, component macro creation, and typed config object propagation PASS; component-agent depth remains open. |
| M06 | Interfaces/VIF/modports/clocking closure | P0 | `[####------] 40%` | `run_logs/LEDGER-0039-uvm-config-db-vif-v2020-nodpi-rerun-20260703.log` | Virtual interface handle config and live field access PASS; modports, clocking block drive/sample, and protocol timing remain open. |
| M07 | Config/resource DB and component flow | P0 | `[####------] 40%` | `run_logs/LEDGER-0033-uvm-config-db-basic-v2020-nodpi-clean-20260704.log`, `run_logs/LEDGER-0039-uvm-config-db-vif-v2020-nodpi-rerun-20260703.log` | Typed config object and virtual interface set/get through `uvm_config_db` PASS; resource DB precedence, wildcard matching, connect-phase depth, and agent hierarchy remain open. |
| M08 | TLM and sequence flow | P0 | `[----------] 0%` | analysis FIFO and sequencer tests | Driver/sequencer/sequence handshake works. |
| M09 | Constrained-random sequence items | P0 | `[----------] 0%` | randomize suite | Sequence items randomize with seed replay and diagnostics. |
| M10 | Functional coverage from UVM classes | P0 | `[----------] 0%` | covergroup subscriber tests | Subscriber covergroups sample and report usable coverage. |
| M11 | APB protocol environment | P0 | `[----------] 0%` | `test_regress/uvm_ext/apb` | Active/passive APB agent, scoreboard, coverage, assertions, RAL frontdoor pass. |
| M12 | AXI-lite protocol environment | P0 | `[----------] 0%` | `test_regress/uvm_ext/axi_lite` | Ready/valid, interleaving smoke, coverage, assertions, RAL frontdoor pass. |
| M13 | RAL frontdoor and predictor | P1 | `[----------] 0%` | RAL smoke tests | Frontdoor read/write/mirror/update and predictor pass. |
| M14 | DPI/reference model and minimal VPI strategy | P1 | `[###-------] 25%` | `run_logs/LEDGER-0016` through `run_logs/LEDGER-0019` | UVM DPI hello and HDL API smoke PASS under manual `--build-jobs 1`; C scoreboard and RAL backdoor policy remain open. |
| M15 | SVA protocol profile | P1 | `[----------] 0%` | APB/AXI-lite assertion tests | Protocol assertions agree with monitor behavior. |
| M16 | Synthetic SoC regression | P1 | `[----------] 0%` | `test_regress/uvm_ext/soc_synth` | CSR/RAL, DMA, IRQ, reset, clocks, coverage, DPI, seed replay pass. |
| M17 | Packaging, CI, performance | P1 | `[----------] 0%` | CI lane scripts and perf shards | Clean checkout flow and performance dashboard exist. |
| M18 | Advanced parity limits | P2 | `[----------] 0%` | known-limitations records | VPI/backdoor/four-state/UCIS/debug gaps are documented or tested. |
| M19 | Competitive coverage closure and issue hygiene | P0/P1 | `[----------] 0%` | Unified evidence checklist | Every standards, source, workload, and SoC requirement maps to an owning milestone, leaf issue, test, or documented limitation. |

## GitHub Issue Coverage

GitHub Issues are enabled for `phoenix-hacking/verilator-uvm-extend`. The
top-level UVM 2020 milestones and objective-owned leaf issues were created as
open issues on 2026-07-03. This is one issue tree; external sources are cited as
evidence on rows, not tracked in a separate comparison table.

| ID | Coverage | GitHub issue |
|---|---|---|
| M00 | Source-tree build and reproducible baseline | [#1](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/1) |
| M01 | Existing UVM smoke baseline | [#2](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/2) |
| M02 | IEEE 1800 P0 semantic audit | [#3](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/3) |
| M03 | UVM 1800.2 API audit | [#4](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/4) |
| M04 | Scheduler, process, and fork closure | [#5](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/5) |
| M05 | Class, factory, and static initialization closure | [#6](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/6) |
| M06 | Interfaces, virtual interfaces, modports, and clocking closure | [#7](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/7) |
| M07 | Config/resource DB and component flow | [#8](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/8) |
| M08 | TLM and sequence flow | [#9](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/9) |
| M09 | Constrained-random sequence items | [#10](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/10) |
| M10 | Functional coverage from UVM classes | [#11](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/11) |
| M11 | APB protocol environment | [#12](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/12) |
| M12 | AXI-lite protocol environment | [#13](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/13) |
| M13 | RAL frontdoor and predictor | [#14](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/14) |
| M14 | DPI/reference model and minimal VPI strategy | [#15](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/15) |
| M15 | SVA protocol profile | [#16](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/16) |
| M16 | Synthetic SoC regression | [#17](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/17) |
| M17 | Packaging, CI, and performance | [#18](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/18) |
| M18 | Advanced parity limits | [#19](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/19) |
| M19 | Competitive coverage closure and issue hygiene | [#20](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/20) |
| A01 | Upstream UVM package elaborates unmodified | [#21](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/21) |
| A02 | Cookbook sample coverage | [#22](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/22) |
| A03 | Generic interfaces | [#23](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/23) |
| A04 | Parameterized class default resolution | [#24](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/24) |
| A05 | Parameter-dependent type linking | [#25](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/25) |
| A06 | Typedef linking in UVM class/package contexts | [#26](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/26) |
| A07 | Passing type as class parameter | [#27](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/27) |
| A08 | Nested classes | [#28](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/28) |
| A09 | Expression purity for dynamic casts | [#29](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/29) |
| A10 | Select-expression side effects | [#30](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/30) |
| A11 | Randomize-with complex/member-select expressions | [#31](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/31) |
| A12 | `$countones` in constraints | [#32](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/32) |
| A13 | Randomize-with on aliased types | [#33](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/33) |
| A14 | Randomize-with for parameterized classes | [#34](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/34) |
| A15 | Size constraints | [#35](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/35) |
| A16 | Rand dynamic arrays with null handles and object elements | [#36](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/36) |
| A17 | Covergroup parsing and initial elaboration behavior | [#37](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/37) |
| A18 | Disable-by-label with forks | [#38](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/38) |
| A19 | UVM_NO_DPI tutorial flow | [#39](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/39) |
| A20 | Verification dashboard and SystemVerilog test-suite coverage | [#40](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/40) |

## Leaf Issue Ownership

These leaf issues are not a second roadmap. They are concrete evidence/gap
items assigned to the capability milestones that own the fix and proof.

| Leaf | Owning milestone(s) | Capability covered | Required proof path |
|---|---|---|---|
| A01 | M01, M03 | UVM package elaboration | Unmodified UVM package smoke and API audit. |
| A02 | M03, M07, M08, M13 | Cookbook workload coverage | Cookbook tests mapped to UVM APIs, TLM, config, factory, and RAL. |
| A03 | M06 | Generic/virtual interfaces | Reduced interface tests, then UVM config DB VIF usage. |
| A04 | M05 | Parameterized class defaults | Reduced class tests, then factory/sequence parameterized usage. |
| A05 | M05 | Parameter-dependent type linking | Reduced dtype/link tests, then UVM parameterized class use. |
| A06 | M05 | Typedef linking | Package/class typedef tests, then UVM typedef-heavy classes. |
| A07 | M05 | Type parameters | Reduced type-parameter tests, then factory/adapter/sequence usage. |
| A08 | M05 | Nested classes | Reduced nested-class tests, then UVM API dependency proof. |
| A09 | M02, M05 | Dynamic-cast expression purity | Reduced expression tests, then UVM/Cookbook affected paths. |
| A10 | M02, M05 | Select-expression side effects | Reduced expression tests, then UVM/Cookbook affected paths. |
| A11 | M09 | Inline randomize expressions | Reduced randomize-with tests, then sequence-item tests. |
| A12 | M09 | `$countones` constraints | Reduced solver tests, then sequence-item constraints. |
| A13 | M09 | Aliased randomized types | Reduced alias/solver tests, then UVM sequence-item patterns. |
| A14 | M05, M09 | Randomize on parameterized classes | Class/link proof plus solver proof. |
| A15 | M09 | Size constraints | Reduced dynamic-array/queue size constraints and supported-subset records. |
| A16 | M09 | Rand dynamic arrays/objects | Solver/runtime object-array proof and UVM item tests. |
| A17 | M10 | Covergroup parsing/elaboration | Reduced covergroup tests, then subscriber/coverage workload. |
| A18 | M04 | Disable-by-label with forks | Reduced scheduler/process tests, then UVM phase/sequence kill behavior. |
| A19 | M01, M14, M17 | UVM_NO_DPI flow | Clean checkout command flow, DPI boundary policy, CI lane. |
| A20 | M00, M17, M19 | Dashboard/test-suite coverage | Machine-readable dashboard with every allowed state and issue link. |

## Workstreams

| ID | Title | Layer | Priority | Progress | Main Verilator subsystems | First reduced tests | Larger proof |
|---|---|---|---|---:|---|---|---|
| A | Packages, macros, source locations | L0-L1 | P0 | `[----------] 0%` | `verilog.l`, `verilog.y`, `V3PreProc`, `V3LinkParse`, `FileLine` | package import, macro expansion, source-line preservation | UVM package compile and report source lines. |
| B | Scheduler, event regions, wait, finish | L0-L1 | P0 | `[----------] 0%` | `V3Sched*.cpp`, `V3Timing.cpp`, runtime timing | zero delay, wait, finish, NBA/reactive/observed ordering | UVM phasing/objection deterministic order. |
| C | Processes, fork, disable, process kill | L0-L1 | P0 | `[----------] 0%` | `V3Timing.cpp`, `V3Fork.cpp`, `verilated_timing.*` | fork/join_any/join_none, disable fork, process::self/kill | Sequence stop/kill and phase kill. |
| D | Classes, object model, factory base | L0-L1 | P0 | `[####------] 40%` | `V3Class.cpp`, `V3Width.cpp`, `V3LinkDot.cpp`, `V3EmitC*` | C1 class shard, UVM 2020.3.1 object factory create/override, and component/config object flow pass | UVM component-agent hierarchy, sequences, and RAL classes. |
| E | Containers and strings | L0-L1 | P0 | `[----------] 0%` | `V3Width.cpp`, `V3EmitC*`, runtime containers | queues, dynamic arrays, associative arrays, string methods | UVM resource/config DB and queues. |
| F | Interfaces, virtual interfaces, modports | L0-L2 | P0 | `[####------] 40%` | `V3LinkDotIfaceCapture.cpp`, `V3SchedVirtIface.cpp`, `V3SchedTrigger.cpp` | UVM config DB virtual interface handle set/get and live field read/write pass | Modport access, VIF member triggers, and config DB VIF into protocol agent config. |
| G | Clocking blocks and class task access | L0-L3 | P0 | `[----------] 0%` | `V3AssertPre.cpp`, `V3Width.cpp`, scheduler | input/output skew, ##0, VIF clocking drive/sample | APB driver/monitor through clocking blocks. |
| H | IPC primitives | L0-L2 | P0 | `[----------] 0%` | parser/link/width/runtime as needed | event, semaphore, mailbox smoke | UVM events, barriers, sequencer waits. |
| I | UVM config/resource DB | L1-L2 | P0 | `[####------] 40%` | classes, containers, packages, virtual interfaces | typed config object set/get and virtual interface set/get pass | Resource DB precedence, wildcard matching, and Cookbook virtual interface configuration. |
| J | Components, build/connect/reporting | L1-L2 | P0 | `[####------] 40%` | class/object/scheduler/report source paths | minimal component hierarchy and report phase pass | Cookbook env/agent build and connect. |
| K | Phasing and objections | L1-L2 | P0 | `[----------] 0%` | scheduler/process/class dispatch | raise/drop objection, phase_ready_to_end, phase kill | End-of-test behavior in UVM agent. |
| L | TLM 1 and analysis flow | L1-L3 | P0 | `[----------] 0%` | classes, queues, virtual dispatch | analysis port/export/imp, FIFO | Monitor to scoreboard to predictor. |
| M | Sequences, sequencers, drivers | L1-L3 | P0 | `[----------] 0%` | classes, scheduler, IPC | start_item/finish_item, get_next_item/item_done | APB and AXI-lite active agents. |
| N | Constrained randomization | L0-L3 | P0 | `[----------] 0%` | `V3Randomize.cpp`, `verilated_random.*`, solver integration | inline constraints, arrays, rand_mode, seed replay | Random sequence items and SoC random traffic. |
| O | Functional coverage | L0-L4 | P0/P1 | `[----------] 0%` | `V3Covergroup.cpp`, `verilated_covergroup.*`, coverage tools | class covergroup, subscriber sample, get_coverage | APB/AXI-lite/SoC coverage and merge. |
| P | RAL frontdoor and predictor | L2-L4 | P1 | `[----------] 0%` | classes, TLM, sequences, protocol agents | reg block build, adapter, mirror/update | APB/AXI-lite RAL frontdoor and predictor. |
| Q | APB agent | L3 | P0 | `[----------] 0%` | VIF, clocking, sequences, TLM, coverage | APB single read/write, wait states | Active/passive APB env with scoreboard and RAL. |
| R | AXI-lite agent | L3 | P0 | `[----------] 0%` | VIF, scheduler, sequences, TLM | ready/valid, AW/W order, interleave | Active/passive AXI-lite env with RAL. |
| S | SVA protocol profile | L0-L3 | P1 | `[----------] 0%` | `V3Assert*.cpp`, `V3AssertNfa.cpp` | implication, disable iff, sampled funcs, bind | APB/AXI-lite assertions. |
| T | DPI, VPI, backdoor, debug | L1-L5 | P1/P2 | `[###-------] 25%` | DPI/VPI runtime, source location, report hooks | UVM_NO_DPI, DPI hello, and uvm_hdl smoke passed under manual `--build-jobs 1` | C reference scoreboard and documented backdoor policy. |
| U | Synthetic digital SoC | L4 | P1 | `[----------] 0%` | all P0/P1 dependencies | CSR, DMA, IRQ, reset, clocks | SoC-scale long random regression. |
| V | Packaging, CI, performance | L5 | P1 | `[----------] 0%` | options, test harness, CI scripts, docs | `--uvm` flow decision, perf shards | Clean checkout UX and dashboards. |
| W | Advanced commercial parity limits | L5 | P2 | `[----------] 0%` | VPI, four-state, debug DB, UCIS, timing checks | documented limitation tests | Non-blocking limitations clearly published. |

## First Ten Concrete Tasks

| Task | Progress | Goal | Commands | Acceptance |
|---|---:|---|---|---|
| UVM-BASE-001 | `[##########] 100%` | Configure and build the checkout, not the installed Debian Verilator. | `autoconf && ./configure --enable-ccwarn && make -j8` | PASS recorded in `tracker.yaml`; source-tree binary is `Verilator 5.051 devel rev vUNKNOWN-built20260703-f82f59a02`. |
| UVM-BASE-002 | `[########--] 80%` | Run existing UVM 2020.3.1 hello nodpi smoke. | Manual equivalent of `test_regress/t/t_uvm_hello_all_v2020_3_1_nodpi.py` with `--build-jobs 1` | PASS; default local harness interrupted by WSL resource reset. |
| UVM-BASE-003 | `[########--] 80%` | Run existing UVM 2020.3.1 hello DPI smoke. | Manual equivalent of `test_regress/t/t_uvm_hello_all_v2020_3_1_dpi.py` with `--build-jobs 1` | PASS; executable printed `** UVM TEST PASSED **`. |
| UVM-BASE-004 | `[########--] 80%` | Run existing UVM DPI HDL API smoke. | Manual equivalent of `test_regress/t/t_uvm_dpi_v2020_3_1.py` with `--build-jobs 1` | PASS; HDL check/read/deposit/force/release status recorded. |
| UVM-BASE-005 | `[----------] 0%` | Emit first dashboard from existing test inventory. | Add `run_matrix.py` under `test_regress/uvm_support/scripts` after baseline. | Dashboard states are machine readable. |
| SV-SCHED-001 | `[----------] 0%` | Prove zero-delay and finish behavior needed by UVM phasing. | Add/run reduced L0 tests. | Matches IEEE 1800 scheduling and UVM smoke. |
| SV-CLASS-001 | `[####------] 40%` | Prove parameterized class identity through base handles. | `test_regress/t/t_uvm_factory_basic_v2020_3_1_nodpi.py` logged in `run_logs/LEDGER-0026-uvm-factory-basic-v2020-nodpi-clean-20260703.log` | Existing reduced class shard plus UVM object factory create/override PASS; component/config usage is next. |
| SV-VIF-CLK-001 | `[#---------] 10%` | Prove virtual interface clocking drive/sample. | VIF config DB proof logged in `run_logs/LEDGER-0039-uvm-config-db-vif-v2020-nodpi-rerun-20260703.log`; clocking reducer still needed. | VIF handle propagation PASS; driver/monitor clocking phases remain open. |
| UVM-CONFIG-001 | `[####------] 40%` | Prove config DB object and virtual interface propagation. | `test_regress/t/t_uvm_config_db_basic_v2020_3_1_nodpi.py` and `test_regress/t/t_uvm_config_db_vif_v2020_3_1_nodpi.py` | Typed object and virtual interface propagation into child components PASS; resource DB and agent config object integration remain open. |
| UVM-SEQ-001 | `[----------] 0%` | Prove sequencer/driver handshake. | Add/run minimal UVM sequence test. | start_item/finish_item and get_next_item/item_done complete. |

## Definition Of Done Dashboard

| # | Requirement | Progress |
|---:|---|---:|
| 1 | UVM 2020.3.1 compiles unmodified. | `[----------] 0%` |
| 2 | UVM 2020.3.1 runs unmodified. | `[----------] 0%` |
| 3 | UVM core tests pass or have documented zero-blocker exceptions. | `[----------] 0%` |
| 4 | P0 IEEE 1800 reduced tests pass. | `[----------] 0%` |
| 5 | P0 UVM API tests pass. | `[----------] 0%` |
| 6 | Cookbook build/connect/config/factory/agent examples pass. | `[----------] 0%` |
| 7 | APB active/passive agent passes. | `[----------] 0%` |
| 8 | AXI-lite active/passive agent passes. | `[----------] 0%` |
| 9 | Virtual interfaces work through config DB and config objects. | `[####------] 40%` |
| 10 | Clocking blocks work through virtual interfaces. | `[----------] 0%` |
| 11 | UVM phasing, objections, phase kill, and phase_ready_to_end pass. | `[----------] 0%` |
| 12 | Sequencer/driver handshakes pass. | `[----------] 0%` |
| 13 | Sequence stop/kill tests pass. | `[----------] 0%` |
| 14 | Constrained-random sequence items pass. | `[----------] 0%` |
| 15 | Fixed seed replay passes. | `[----------] 0%` |
| 16 | Functional coverage samples from UVM subscribers. | `[----------] 0%` |
| 17 | Coverage report works. | `[----------] 0%` |
| 18 | Coverage merge works. | `[----------] 0%` |
| 19 | RAL frontdoor read/write/mirror/update passes. | `[----------] 0%` |
| 20 | RAL predictor passes. | `[----------] 0%` |
| 21 | Built-in RAL reset/access/bit-bash smoke passes. | `[----------] 0%` |
| 22 | DPI C scoreboard path passes. | `[----------] 0%` |
| 23 | UVM_NO_DPI path is tested. | `[----------] 0%` |
| 24 | DPI-enabled path is tested or limitation documented. | `[----------] 0%` |
| 25 | APB/AXI-lite assertion profile passes. | `[----------] 0%` |
| 26 | Synthetic SoC boot/reset passes. | `[----------] 0%` |
| 27 | Synthetic SoC CSR/RAL passes. | `[----------] 0%` |
| 28 | Synthetic SoC DMA passes. | `[----------] 0%` |
| 29 | Synthetic SoC interrupt tests pass. | `[----------] 0%` |
| 30 | Synthetic SoC multi-clock tests pass. | `[----------] 0%` |
| 31 | Synthetic SoC reset-mid-traffic tests pass. | `[----------] 0%` |
| 32 | Synthetic SoC coverage tests pass. | `[----------] 0%` |
| 33 | Synthetic SoC fixed-seed replay passes. | `[----------] 0%` |
| 34 | Diagnostics show useful SystemVerilog/UVM file/line/context. | `[----------] 0%` |
| 35 | Performance dashboard exists. | `[----------] 0%` |
| 36 | No unacceptable RTL fast-path regression exists. | `[----------] 0%` |
| 37 | Standard UVM 2020 user flow exists. | `[----------] 0%` |
| 38 | Known limitations are documented. | `[----------] 0%` |
| 39 | User guide exists after support is real. | `[----------] 0%` |
| 40 | CI dashboard is reproducible from a clean checkout. | `[----------] 0%` |

## Execution Discipline

For every task:

1. Pick a task ID from `tracker.yaml`.
2. Add or inspect the L0 reduced IEEE 1800 test first.
3. Run it on the current tree and classify the failure.
4. Patch the smallest Verilator subsystem that owns the semantic.
5. Rerun the reduced test, adjacent tests, and the UVM/Cookbook/protocol shard.
6. Update `tracker.yaml`, `MATRIX.md`, and any known limitation entry.
7. Do not patch UVM to hide a Verilator bug.

## Stop Conditions

Stop and report rather than guessing when:

| Condition | Progress |
|---|---:|
| LRM behavior is ambiguous and no reference result exists. | `[----------] 0%` |
| A fix requires broad scheduler architecture changes. | `[----------] 0%` |
| A fix degrades unrelated RTL regressions. | `[----------] 0%` |
| The proposed workaround modifies UVM instead of Verilator. | `[----------] 0%` |
| The feature appears to require full VPI/backdoor infrastructure. | `[----------] 0%` |
| The failure cannot be reduced below a large UVM environment. | `[----------] 0%` |
| A commercial simulator disagreement appears. | `[----------] 0%` |
| The implementation needs policy: experimental, partial, or unsupported. | `[----------] 0%` |
