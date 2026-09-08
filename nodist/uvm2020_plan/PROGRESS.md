<!-- DESCRIPTION: Verilator: UVM 2020 program progress
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020 program progress

Updated 2026-09-07, with evidence observed on 2026-09-08 UTC.
[tracker.yaml](tracker.yaml) is authoritative. Recompute every roll-up with
`python nodist/uvm2020_plan/check_tracker.py`.

## Accepted progress

| Measure | Accepted | Percentage |
|---|---:|---:|
| Public capability milestones | 7/20 | 35.0% |
| Required atomic gates | 31/46 | 67.4% |
| Program exit criteria | 3/21 | 14.3% |
| Full UVM compliance goal checks | 0/6 | Pending |
| Production performance goal checks | 0/6 | Pending |

The denominators are unchanged. Gate completion is not a UVM conformance
percentage. Both explicit goals remain open under [GOALS.md](GOALS.md).
The accumulated compatibility inventory has 115/115 passing declared
oracles, including negative tests and bounded XFAIL handling; it does not
establish full compliance. Direct resource lookup remains a normative blocker.

## New accepted capability

**M06, M11 and M12, with C06, C07 and C08, pass their declared local acceptance.**
The APB environment uses typed virtual clocking modports through config
objects, active/passive agents, independent monitors and scoreboards, wait
states, errors, byte masks, reset cancellation and recovery. Delayed requests
receive a complete setup cycle, and back-to-back transfers are exercised.

Each seeded run completes 2,436 APB transfers. RAL checks include frontdoor
read/write, set/update/mirror, individual byte fields, explicit monitor
prediction, external bus writes and the built-in reset/bit-bash/access
sequences. Seven individual coverage bins match traffic histograms; merge
and report checks pass. Data and four protocol fault injections are detected.

All four local configurations pass: bundled/source UVM, each in vlt/vltmt,
with three seeded positives and five negatives per configuration. Source
runs explicitly select clean, unmodified UVM 2020.3.1 at
`78c06547a2a0a29b3dc9dcafae62b75b2ff61544`. `UVM_HOME` alone does not select
source mode in this harness. The custom SV RAL backdoor does not claim HDL-DPI
acceptance. [APB evidence](uvm-apb-local-2026-09-07.yaml) records source,
binary, commands, counts, logs and limitations.

The extended AXI-lite environment also passes all four bundled/source and
vlt/vltmt configurations: 12 seeded positives and 24 negatives. Every positive
completes 2,468 transfers, including 2,272 RAL frontdoor/predictor/built-in
operations. Twenty-seven individual coverage-bin counts match independent
driver handshakes, and merge/report checks pass. Reset requests arriving
between clocking events now preserve three full sampled reset cycles. A
corrupt RAL response is detected independently of correct bus and predictor
observations. [AXI RAL evidence](uvm-axi-ral-local-2026-09-08.yaml) closes M12;
broader policies/maps, full coverage semantics and the assertion profile stay
open under M13, M10 and M15.

## Other validated components

| Component | Result | Scope still open |
|---|---|---|
| Compiler safe access | Complete 164-unit audit reduced 47 to 21, then 11 primary findings; a statistics insertion race was reproduced and fixed; 18 behavioral scenarios pass. | Eleven source findings, runtime findings, broad sanitizer and release acceptance. |
| Coverage weighting | Weighted item percentages, dynamic instance weights and supported array-bin cross products have passing evidence across 52 scenarios. | Type aggregation, lifetime/ownership, other options and complete cross semantics. |
| AXI-lite environment | All four configurations pass RAL, coverage and the existing independent-channel transport checks; each positive completes 1,202 writes and 1,266 reads. | Broader RAL policies/maps, full coverage semantics and the assertion profile remain separate open scope. |
| CMake FST dependencies | Parent failed with missing `lz4.h` despite a valid prefix; dependency discovery now passes eight FST/VCD/SAIF scenarios. | Combined-source and supported-host CI validation. |

See [compiler evidence](compiler-safe-access-local-2026-09-07.yaml),
[coverage evidence](coverage-weight-local-2026-09-07.yaml),
[AXI evidence](uvm-axi-local-2026-09-07.yaml), and
[CMake evidence](cmake-fst-local-2026-09-07.yaml). The 52 coverage passes span
the broad run and final targeted reruns, not one uninterrupted all-green run.
The compiler's exact diagnostic-pair comparison includes the changed wording
of an existing CellEdge finding; no newly affected function is claimed.

## Integration and release state

The combined checkout is `/home/holden/verilator-work/uvm-integration-20260908`,
branch `codex/uvm-integration-20260908`. It includes the DPI C-build correction,
compiler fixes, coverage semantics, APB/RAL, AXI transport and CMake dependency
fix. Its optimized native build and coverage utility passed. The combined
`uvm2020-protocol-source` target at `77a328f91` passed all four APB/AXI configurations in
17:25, with 12 seeded positives, 20 injected-fault negatives, pinned clean
source UVM and removal of every seeded stale artifact. That AXI version is
the 196-transfer transport fixture; the later RAL extension above has separate
all-four-configuration evidence. Another 22 compiler,
coverage and CMake neighbor scenarios passed in 4:24. See
[combined evidence](integration-next-local-2026-09-08.yaml). All four DPI-enabled
source reference checks also passed in 14:52, including strict C11 reference
compilation and injected-fault rejection. Exact-revision CI remains open.

The original integration checkout remains at `382553c08`. Its segmented
regression finished with **6,727 passes, eight skips and three failures across
6,738 scenarios**. The continuation reran all 4,185 pending and 13 failed
scenarios and contributed 4,195 passes. Final evidence verifies all 9,812
source inputs, native binaries, stage logs and 6,738 status hashes.
Failures are contributor certification and CMake FST discovery in both modes;
the CMake cases pass against the combined candidate. Skips cover the disabled
enum-pattern test, NUMA/LCOV dependencies and missing attribute compilation
databases. These remain open release work. [Final regression evidence](integration-resume-final-2026-09-08.yaml)
preserves each disposition. This is not a fresh continuous full-regression pass.

After completion and evidence verification, 78.40 GiB of disposable regression
objects, archives and precompiled headers were removed. Earlier component
cleanup and compressed, verified AST archives recovered another 14.86 GiB.
Sources, logs, coverage, statuses, generated code and executables are retained.

Historical CI at `382553c08` finished with 35 successful and 13 failed jobs in
each of two matrices. Attribute checks, DPI C compilation and upstream UVM
format-security failures remain separately recorded in the continuation
ledger. Prior successful 27-test and 46-job results apply only to their
recorded revisions. PRs #41 and #42 remain draft. Agents must not edit
`docs/CONTRIBUTORS` or sign the Contributor Agreement.

Performance acceptance is not established. The shared development host is
running builds and regressions; these durations are not controlled performance
measurements. Correct workload baselines, seven paired samples, confidence
intervals, memory limits and dedicated performance CI remain required.

## Next technical work

1. Complete current combined-source CI and retain exact-revision evidence.
1. Resolve the eight remaining skip dispositions, close compiler/runtime
   safety findings and run a fresh full regression at the final combined revision.
1. Extend RAL policies/maps and the full assertion/monitor profile without
   relaxing their oracles.
1. Resolve remaining compiler/runtime safety findings and coverage type/lifetime
   semantics. Complete the normative language/UVM requirement inventory.
1. Implement the synthetic SoC workload, resolve source-library deviations,
   complete supported-host CI and sanitizers, then freeze correct performance
   workloads and run the controlled acceptance protocol.

## Public milestones

| Milestone | Capability | Accepted gates | Status | Remaining work or accepted scope |
|---|---|---:|---|---|
| [M00](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/1) | Source-tree build and reproducible baseline | 4/4 | pass | Accepted source-build and inventory-disposition scope. |
| [M01](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/2) | Existing UVM smoke baseline | 3/3 | pass | Accepted original and expanded smoke scope. |
| [M02](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/3) | IEEE 1800 P0 semantic audit | 3/4 | in progress | Complete the P0 language requirement matrix and independent dispositions. |
| [M03](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/4) | UVM 1800.2 API audit | 2/3 | in progress | Complete the P0 API inventory and the full normative requirement mapping. |
| [M04](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/5) | Scheduler, process, and fork closure | 4/6 | in progress | Close event-region, cancellation and performance gates. |
| [M05](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/6) | Class, factory, and static initialization closure | 3/3 | pass | Accepted class/factory scope. |
| [M06](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/7) | Interfaces, virtual interfaces, modports, and clocking closure | 4/4 | pass | Accepted virtual-interface, modport and APB clocking scope. |
| [M07](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/8) | Config/resource DB and component flow | 0/1 | in progress | Resolve direct resource-precedence behavior in the pinned library; retain the normative oracle. |
| [M08](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/9) | TLM and sequence flow | 1/1 | pass | Accepted TLM/sequence scope. |
| [M09](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/10) | Constrained-random sequence items | 0/1 | in progress | Finish the declared constrained-random acceptance, including remaining scope/state cases. |
| [M10](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/11) | Functional coverage from UVM classes | 0/1 | in progress | Implement type aggregation, lifetime-safe ownership, remaining options and cross semantics; complete class coverage acceptance. |
| [M11](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/12) | APB protocol environment | 1/1 | pass | Accepted APB active/passive, RAL, coverage and assertion scope. |
| [M12](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/13) | AXI-lite protocol environment | 1/1 | pass | Accepted AXI-lite active/passive, RAL, coverage and assertion scope. |
| [M13](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/14) | RAL frontdoor and predictor | 0/1 | in progress | Extend the passing APB RW model to all required access policies and maps. |
| [M14](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/15) | DPI/reference model and minimal VPI strategy | 2/3 | in progress | Complete exact-revision CI and full-regression proof for DPI/HDL backdoor requirements. |
| [M15](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/16) | SVA protocol profile | 0/1 | in progress | Complete the assertion/monitor agreement profile and document unsupported constructs precisely. |
| [M16](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/17) | Synthetic SoC regression | 0/1 | not started | Implement and validate the scalable synthetic SoC workload. |
| [M17](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/18) | Packaging, CI, and performance | 2/3 | in progress | Finish packaging, diagnostics, coverage integration and exact-revision CI closure. |
| [M18](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/19) | Advanced parity limits | 0/1 | not started | Complete required advanced-parity capabilities and independent validation. |
| [M19](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/20) | Competitive coverage closure and issue hygiene | 1/3 | in progress | Finish clean regression, sanitizer, supported-host and performance release acceptance. |

## Program criteria

Each criterion retains its original required milestone mapping. For example,
passing the APB RW register model advances C10-C12, but M13's broader policy
and map requirements still prevent those criteria from passing.

| Criterion | Required behavior | Required milestones | Status |
|---|---|---|---|
| C01 | Unmodified Accellera UVM 2020.3.1 source flow | M01, M03 | in progress |
| C02 | Tracker reaches complete or documented zero-blocker state | M00, M19 | in progress |
| C03 | All P0 IEEE 1800 reduced tests pass | M02 | in progress |
| C04 | Core UVM factory, reporting, phasing, DB, TLM, and sequence APIs pass | M03, M04, M05, M07, M08 | in progress |
| C05 | Virtual interfaces propagate through config DB and config objects | M06, M07 | in progress |
| C06 | Clocking blocks work through virtual interfaces | M06 | pass |
| C07 | Active and passive APB agent passes | M11 | pass |
| C08 | Active and passive AXI-lite agent passes | M12 | pass |
| C09 | Scalable AXI-style synthetic SoC smoke passes | M16 | not started |
| C10 | RAL frontdoor mirror and update pass | M13 | in progress |
| C11 | RAL predictor passes | M13 | in progress |
| C12 | Built-in RAL reset, access, and bit-bash smokes pass | M13 | in progress |
| C13 | Constrained-random fixed-seed replay passes | M09, M16 | not started |
| C14 | Functional coverage from UVM classes passes | M10 | in progress |
| C15 | Coverage report and merge pass | M10, M17 | in progress |
| C16 | APB and AXI-lite protocol assertions pass | M15 | in progress |
| C17 | DPI and no-DPI flows are tested and documented | M14 | in progress |
| C18 | VPI and backdoor strategy is implemented or documented | M14, M18 | not started |
| C19 | Diagnostics provide useful source file, line, and context | M17 | not started |
| C20 | UVM 2020 user-facing selection flow exists | M17 | not started |
| C21 | Nightly synthetic SoC regression passes reproducibly | M16, M17 | not started |

## Atomic gates

Every pending or blocked gate remains in the denominator. Evidence IDs resolve
in [tracker.yaml](tracker.yaml); accepted evidence retains its local/CI scope.

| Gate | Required behavior | Status | Evidence |
|---|---|---|---|
| M00-G01-SOURCE-BUILD | Source-tree build completes | pass | LOCAL-SOURCE-BUILD-0001 |
| M00-G02-TRACKER-MANIFEST | Tracker schema and compatibility manifest validate | pass | LOCAL-TRACKER-MANIFEST-0001 |
| M00-G03-FULL-BASELINE | Full frozen compatibility inventory receives reproducible dispositions | pass | FULL-BASELINE-0001 |
| M00-G04-DASHBOARD | Allowed-state dashboard is reproducible | pass | LOCAL-TRACKER-MANIFEST-0001 |
| M01-G01-LOCAL-SMOKE | Existing three-test UVM smoke passes locally | pass | LOCAL-UVM-SMOKE-0001 |
| M01-G02-PR-CI | Original clean lane passes canonical CI | pass | HARNESS-FANOUT-0001, HARNESS-CLEAN-0001, UVM-PKG-NODPI-0001, UVM-PKG-DPI-0001, UVM-DPI-HDL-0001 |
| M01-G03-EXPANDED-LANE | Expanded lane completes locally without unresolved failures | pass | LOCAL-LANE-CONTRACT-0001 |
| M02-G01-WAIT-ZERO | Constant-false wait and scheduler neighbors pass | pass | LOCAL-WAIT-ZERO-0001 |
| M02-G02-FINISH-CLOCKING | Finish audit and reduced virtual clocking pass | pass | LOCAL-FIRST-BLOCKERS-0001 |
| M02-G03-PROCESS-KILL | Recursive process kill and confirmed neighbors pass | pass | LOCAL-PROCESS-KILL-0001 |
| M02-G04-P0-MATRIX | Every P0 clause has a reduced result and reference disposition | pending | Pending |
| M03-G01-PACKAGE-SMOKE | Existing package and DPI smokes pass locally | pass | LOCAL-UVM-SMOKE-0001 |
| M03-G02-FACTORY-API | Expanded factory API reduction passes locally | pass | LOCAL-FACTORY-0001 |
| M03-G03-P0-API-INVENTORY | Every P0 UVM API category has a minimal result state | pending | Pending |
| M04-G01-WAIT | Constant-false wait semantics pass | pass | LOCAL-WAIT-ZERO-0001 |
| M04-G02-FINISH | Finish termination audit passes | pass | LOCAL-FIRST-BLOCKERS-0001 |
| M04-G03-KILL | Recursive process kill slice passes | pass | LOCAL-PROCESS-KILL-0001 |
| M04-G04-UVM-PHASING | UVM phasing, objections, and phase kill close | pass | LOCAL-UVM-PHASING-0001 |
| M04-G05-EVENT-REGIONS | Required event-region semantics receive closure evidence | pending | Pending |
| M04-G06-RTL-PERFORMANCE | RTL fast-path performance is preserved against a reproducible baseline | pending | Pending |
| M05-G01-FACTORY | Expanded factory override and creation API passes | pass | LOCAL-FACTORY-0001 |
| M05-G02-CLASS-STATIC-CLOSURE | Class identity and static initialization closure completes | pass | CLASS-STATIC-CLOSURE-20260907 |
| M05-G03-CANONICAL-CI | Factory and class closure pass canonical CI | pass | CLASS-STATIC-CLOSURE-20260907 |
| M06-G01-REDUCED-CLOCKING | Reduced virtual clocking drive/sample test passes | pass | LOCAL-FIRST-BLOCKERS-0001 |
| M06-G02-UVM-VIF | UVM config DB virtual-interface clocking flow passes | pass | LOCAL-UVM-VIF-CLOCKING-0001 |
| M06-G03-SUBINTERFACE-TRIGGERS | Sub-interface access and virtual-interface member triggers pass | pass | LOCAL-VIF-NEIGHBORS-0001 |
| M06-G04-APB-CYCLES | APB setup/access cycles pass through protocol drivers and monitors | pass | LOCAL-APB-RAL-20260908 |
| M07-G01-CLOSURE | Config/resource DB and component flow acceptance passes | pending | Pending |
| M08-G01-CLOSURE | TLM and sequence handshake acceptance passes | pass | TLM-SEQUENCE-CLOSURE-20260907 |
| M09-G01-CLOSURE | Deterministic constrained-random sequence-item acceptance passes | pending | Pending |
| M10-G01-CLOSURE | UVM class coverage, report, and merge acceptance passes | pending | Pending |
| M11-G01-CLOSURE | Active/passive APB environment acceptance passes | pass | LOCAL-APB-RAL-20260908 |
| M12-G01-CLOSURE | Active/passive AXI-lite environment acceptance passes | pass | LOCAL-AXI-RAL-20260908 |
| M13-G01-CLOSURE | RAL frontdoor, predictor, and built-in smoke acceptance passes | pending | Pending |
| M14-G01-LOCAL-DPI-SMOKE | Existing DPI/no-DPI/HDL-DPI smokes pass locally | pass | LOCAL-UVM-SMOKE-0001 |
| M14-G02-C-REFERENCE | C reference-model scoreboard path passes | pass | LOCAL-DPI-REFERENCE-20260907 |
| M14-G03-VPI-BACKDOOR | Minimal VPI/backdoor support or limitation is accepted | in_progress | UVM-BACKDOOR-20260907 |
| M15-G01-CLOSURE | Practical APB and AXI-lite assertion profile passes | pending | Pending |
| M16-G01-CLOSURE | Synthetic SoC acceptance regression passes | pending | Pending |
| M17-G01-LOCAL-LANE | Clean and capped original lane passes locally | pass | LOCAL-LANE-CONTRACT-0001 |
| M17-G02-CANONICAL-CI | Clean-checkout canonical CI lane passes | pass | HARNESS-FANOUT-0001, HARNESS-CLEAN-0001 |
| M17-G03-PERFORMANCE | Reproducible performance dashboard is established | pending | Pending |
| M18-G01-DISPOSITION | Advanced gaps are implemented or accepted as non-blocking limits | pending | Pending |
| M19-G01-TRACKER-SCHEMA | Machine-checked tracker and manifest validate | pass | LOCAL-TRACKER-MANIFEST-0001 |
| M19-G02-ROADMAP-ALIGNMENT | All public trackers and leaf issues are aligned | pending | Pending |
| M19-G03-CLAIM-LEVELS | C0-C3 claim levels have complete proof paths | pending | Pending |

## Continuation and evidence policy

[CONTINUATION.md](CONTINUATION.md) retains the recovery history and earlier
results. The current local handoff is
`/home/holden/verilator-work/goal-continuation-20260908.md`. Preserve live process
identities and frozen inputs; do not restart work merely because a tool handle
expired. Publish accepted progress only after source, tests and proof agree.
An upstream library defect or required unsupported feature stays open until its
resolution is verified. Full compliance and performance cannot be inferred from
partial fixtures, repeated passes or documented exceptions.
