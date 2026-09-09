<!-- DESCRIPTION: Verilator: UVM 2020 program progress
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020 program progress

Updated 2026-09-09, with evidence observed on 2026-09-09 UTC.
[tracker.yaml](tracker.yaml) is authoritative. Recompute every roll-up with
`python nodist/uvm2020_plan/check_tracker.py`.

## Accepted progress

| Measure | Accepted | Percentage |
|---|---:|---:|
| Public capability milestones | 12/20 | 60.0% |
| Required atomic gates | 36/46 | 78.3% |
| Program exit criteria | 9/21 | 42.9% |
| Full UVM compliance goal checks | 0/6 | Pending |
| Production performance goal checks | 0/6 | Pending |

The denominators are unchanged. Gate completion is not a UVM conformance
percentage. Both explicit goals remain open under [GOALS.md](GOALS.md).
The accumulated compatibility inventory has 115/115 passing declared
oracles, including negative tests and bounded XFAIL handling; it does not
establish full compliance. Direct resource lookup remains a normative blocker.

## Latest validation checkpoint

**C20 now passes its original user-facing source-selection criterion.** The
documented `examples/make_uvm` flow selects an external UVM checkout and runs
with or without DPI. Both the clean committed source and copied installation
pass 12 independently checked positive runs, 96 operations and four fatal-exit
controls. Seven invalid configurations give actionable diagnostics. Existing
source and bundled HDL-backdoor regressions also pass after the shared adapter
move. [Acceptance evidence](uvm-user-flow-2026-09-09.yaml) records exact inputs,
logs and validation limits. The new CI lane is implemented but still pending;
this accepts C20 locally and does not grant full-release or conformance credit.

**M17 and C15 now pass their original acceptance.** The reproducible
[performance dashboard](PERFORMANCE_DASHBOARD.md) retains frozen inputs,
paired measurements, checked completed work and raw resource samples.
Thirty-two SoC control runs at two sizes verify 240 completed DMA commands;
relocation reproduces identical JSON, Markdown and HTML reports. Clean-checkout
[tooling CI](https://github.com/phoenix-hacking/verilator-uvm-extend/actions/runs/34394319207)
passes all eleven integrity controls on revision `8076d7069`.

C15 combines M17 with independently rechecked M10 report/merge evidence:
all eight source configurations and 24 seeded runs still pass, with every
coverage bin and report location/count checked. The corresponding compiler,
runtime and fixture inputs remain unchanged. [Acceptance evidence](performance-dashboard-accepted-2026-09-09.yaml)
records these distinct proof paths. C19 and C21 remain open; C20 now has the separate acceptance below.

These short same-executable controls do not establish an optimization or
production performance result. Full G-PERF requirements and current-release
CI remain required. Neither final goal receives acceptance credit.

**M16, C09 and C13 now pass their original local acceptance.** The synthetic
SoC combines an APB register model, byte DMA, AXI-lite memory, two clocks,
interrupt masking/clearing, reset cancellation, class coverage, C DPI and seed
replay. All four source DPI/thread configurations pass sixteen positive runs:
100 completed commands, sixteen canceled commands, 1,264 DMA reads and writes
each, and 59,392 independently checked memory bytes. DPI checks 29,696 bytes
through the C reference. All eighteen hardware/reference fault runs and 112
corrupted-trace controls are rejected. Individual bins, file merge and LCOV
reports agree with independently reconstructed physical traffic.
[Acceptance evidence](synthetic-soc-local-2026-09-09.yaml) preserves exact source,
raw logs, clock/seed/resource provenance and the failing pilot cases. Final source
also checks every frontdoor read updates the register mirror. C13 combines this
SoC replay evidence with the already accepted M09 randomization profile.

The [profile](SYNTHETIC_SOC_PROFILE.md) records the original scope and limits.
The source CI lane is configured but no current CI pass or nightly execution is
claimed. C21 still requires reproducible nightly evidence. Both full goals remain open.

**M10 and C14 now pass the original functional coverage profile.** Real UVM
subscribers pass all eight APB/AXI source DPI/thread configurations: 24 seeded
runs, 58,848 transfers, 144 instance/type query checkpoints and 144 deliberately
corrupted query controls. Every database bin, merged hit count and LCOV branch/
line report matches independent driver traffic. Existing protocol, RAL and fault
checks continue to pass. Weighted/type coverage, retained data, static group
options and merged hit thresholds also have reduced C++14/protected/threaded
and sanitizer evidence. [Acceptance evidence](functional-coverage-local-2026-09-09.yaml)
records exact sources, the final independently replayed query helper and raw hashes.
The [profile](FUNCTIONAL_COVERAGE_PROFILE.md) retains the remaining full semantic
requirements. C15 now passes after M17 dashboard acceptance. No final compliance/performance check is
accepted, and complete current-source release CI/regression remains open.

**M09 now passes its original sequence-item acceptance.** Source `63fb4e86b2`
passes the local and dedicated current-source CI matrices: four DPI/thread
configurations, 12 seeded runs and 768 independently checked transactions in
each matrix. Complete failed-solve state, callbacks, modes and deterministic
replay pass. Twenty current constraint-limit drivers match the documented
diagnostics. [Acceptance evidence](randomization-profile-2026-09-09.yaml)
records the exact source, pinned library, raw logs and validation hashes.
The overall CI run failed five jobs on two annotation checks; full exact-release
CI/regression remains open. C13 also requires M16, so no exit criterion or
final-goal check receives credit. Denominators and acceptance scope are unchanged.

**M15 and C16 now pass their declared local acceptance.** At `350da6ef4`,
all ten practical APB/AXI-lite assertion rules agree with independent UVM
monitors and a Python oracle over physical bus samples. All eight clean,
unmodified-source UVM configurations pass: each protocol with DPI off/on
and one/two threads. The proof covers 24 seeded positives, 58,848 transfers,
76 paired fault cases and four legal APB unused-data controls. Equal seeds
replay identical traffic; individual coverage bins, merge, RAL and existing
scoreboard checks remain required. The unchanged APB monitor previously
accepted 3,570 sampled read-strobe violations; the corrected monitor detects
the first invalid cycle, matching the assertion.

The [profile](SVA_PROTOCOL_PROFILE.md) defines the ten rules and documents
precise unsupported forms from 24 passing compile-only drivers. It excludes
a stale, unpaired assertion-control golden that the compiler now accepts.
[Acceptance evidence](sva-protocol-local-2026-09-09.yaml) retains exact source,
native, library, build-command, thread/DPI, fault-cycle and raw-log provenance.
Formatting, full Python lint and both distribution checks pass. This closes
one milestone, one atomic gate and one criterion without changing any
denominator. Full SVA/UVM conformance, current-revision release validation
and controlled performance acceptance remain open.

At `93762ff8b`, class-method writes now trigger combinational readers of
persistent storage, including writes from non-suspending helpers. All six
timing, no-timing and protected-identifier scenarios pass in the combined
checkout, as do both distribution checks. The source-DPI wrapper now follows
the SystemVerilog package's experimental polling opt-in. Both source-DPI
hello and HDL-access tests pass with the clean pinned UVM library. The reused
native compiler has identical compiler/runtime/build sources to this
revision; its original build and preserved parent are recorded in
[combined scheduler/DPI evidence](class-write-source-dpi-local-2026-09-08.yaml).

The separate DPI component at `a9bcaf8a4` also passes all four UVM CI lanes,
including 27 source, four protocol-source and two randomization-source
scenarios. Its overall CI remains unaccepted because other checks failed or
are unfinished. Combined-revision CI and full release regression remain
required. These results add no milestone or final-goal acceptance credit.

Compiler source `bf891338a` fixes recursive assignment-pattern type/default
keys and protected structure initializer names. The strengthened enum fixture
and neighboring array/structure tests pass **98/98 GCC scenarios** and
**14/14 Clang/C++14 scenarios**, with full Python lint and distribution checks.
Isolated LCOV/HTML and NUMA dependencies also pass their four scenarios.
Six historical skips now have passing reruns; the two attribute audits remain
open, and the original regression inventory below retains its actual results.

The named pinned-source protocol target also passes **4/4 in 13:50** with
this compiler: 12 seeded positives and 22 negatives, including the extended
2,468-transfer AXI/RAL fixture. All 9,774 recorded source inputs and the native
binary stayed unchanged, and source UVM remained clean before and after.
Full cppcheck completed with all generated inputs present and no parsing or
missing-input diagnostics. It retains 1,058 unique findings, including ten
error-level reports in files identical to the parent. The changed-file
comparison is 19 versus 19, with none added or removed. This does not close
broader static-analysis or release requirements. See
[skip-closure evidence](regression-skip-closure-local-2026-09-08.yaml).

The component is now integrated. The combined native compiler rebuilt at
`fad9c5d31`, and six normal integration checks pass at `ab69ef0d9` with 9,774
source inputs unchanged. CI on the earlier `471351e7b` exposed two stale
coverage golden files. Both failures reproduced locally; harness regeneration
adds the implemented weight fields and current annotated source. All 127
individual coverage-bin counts remain unchanged, accounting for an internal
unnamed-cross ordinal. The normal rerun has golden updates disabled. See
[integrated evidence](integration-pattern-local-2026-09-08.yaml). New-revision
CI and full regression remain required. Another 1.17 GiB of completed protocol
objects was removed after verifying all 88 retained artifacts.

Checker commits `292419b26` and `06d8db671` fix the Clang 21 cursor-ownership
API failure and preserve recorded C++ dialects while reading forced headers
as source. Both checker regressions pass under Clang 14, 18 and 21. Paired
reduced checks reproduce the old foreign-PCH and default-dialect failures;
all 36 candidate checks pass. A three-unit compiler-source replay under
Clang 14 previously failed to parse two units. The candidate parses all three
and still reports two real annotation violations. Full source/runtime audits
and current-revision CI remain open; these tool fixes add no acceptance credit.
See [cursor evidence](attribute-python-api-local-2026-09-08.yaml) and
[compilation-database evidence](attribute-compdb-local-2026-09-08.yaml).
Removing superseded CI/download archives recovered another 0.60 GiB, excluding
the package index cache; approximately 144 GiB is available locally.

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
broader policies/maps and full coverage semantics stay open under M13 and
M10. The practical assertion profile now has the separate M15 acceptance above.

## Other validated components

| Component | Result | Scope still open |
|---|---|---|
| Compiler safe access | Complete 164-unit audit reduced 47 to 21, then 11 primary findings; a statistics insertion race was reproduced and fixed; 18 behavioral scenarios pass. | Eleven source findings, runtime findings, broad sanitizer and release acceptance. |
| Coverage weighting | Weighted item percentages, dynamic instance weights and supported array-bin cross products have passing evidence across 52 scenarios. | Type aggregation, lifetime/ownership, other options and complete cross semantics. |
| AXI-lite environment | All four configurations pass RAL, coverage and the existing independent-channel transport checks; each positive completes 1,202 writes and 1,266 reads. | Broader RAL policies/maps, full coverage semantics and full SVA parity remain separate open scope. |
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
databases. Six skips have the passing follow-up evidence above; the two attribute
audits and complete release regression remain open. [Final regression evidence](integration-resume-final-2026-09-08.yaml)
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

1. Close M14's remaining exact-revision CI and release-regression evidence.
   Continue the full production benchmark workloads and measurements;
   M17 dashboard acceptance does not complete production optimization.
1. Complete the remaining normative UVM/language inventory, resource-precedence
   behavior and class coverage semantics. Preserve the committed RAL checkpoint;
   further RAL expansion stays paused while the next marker is addressed.
1. Complete the synthetic SoC workload, supported-host and full release
   validation, then freeze correct workloads for controlled performance
   acceptance. Historical component passes retain their exact source scope.

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
| [M09](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/10) | Constrained-random sequence items | 1/1 | pass | Original randomization profile accepted with local and dedicated CI evidence. |
| [M10](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/11) | Functional coverage from UVM classes | 1/1 | pass | Original subscriber/query/report/merge profile accepted; full semantics remain open. |
| [M11](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/12) | APB protocol environment | 1/1 | pass | Accepted APB active/passive, RAL, coverage and assertion scope. |
| [M12](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/13) | AXI-lite protocol environment | 1/1 | pass | Accepted AXI-lite active/passive, RAL, coverage and assertion scope. |
| [M13](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/14) | RAL frontdoor and predictor | 0/1 | in progress | Extend the passing APB RW model to all required access policies and maps. |
| [M14](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/15) | DPI/reference model and minimal VPI strategy | 2/3 | in progress | Complete exact-revision CI and full-regression proof for DPI/HDL backdoor requirements. |
| [M15](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/16) | SVA protocol profile | 1/1 | pass | Ten-rule assertion/monitor agreement and precise unsupported forms accepted; see the profile evidence. |
| [M16](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/17) | Synthetic SoC regression | 1/1 | pass | Original SoC CSR/RAL, DMA, IRQ, reset/clocks, coverage, DPI and replay profile accepted. |
| [M17](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/18) | Packaging, CI, and performance | 3/3 | pass | Original clean-flow, CI and reproducible dashboard gates accepted; production optimization remains open. |
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
| C09 | Scalable AXI-style synthetic SoC smoke passes | M16 | pass |
| C10 | RAL frontdoor mirror and update pass | M13 | in progress |
| C11 | RAL predictor passes | M13 | in progress |
| C12 | Built-in RAL reset, access, and bit-bash smokes pass | M13 | in progress |
| C13 | Constrained-random fixed-seed replay passes | M09, M16 | pass |
| C14 | Functional coverage from UVM classes passes | M10 | pass |
| C15 | Coverage report and merge pass | M10, M17 | pass |
| C16 | APB and AXI-lite protocol assertions pass | M15 | pass |
| C17 | DPI and no-DPI flows are tested and documented | M14 | in progress |
| C18 | VPI and backdoor strategy is implemented or documented | M14, M18 | not started |
| C19 | Diagnostics provide useful source file, line, and context | M17 | not started |
| C20 | UVM 2020 user-facing selection flow exists | M17 | pass |
| C21 | Nightly synthetic SoC regression passes reproducibly | M16, M17 | in progress |

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
| M09-G01-CLOSURE | Deterministic constrained-random sequence-item acceptance passes | pass | UVM-RANDOM-PROFILE-20260909 |
| M10-G01-CLOSURE | UVM class coverage, report, and merge acceptance passes | pass | LOCAL-UVM-COVERAGE-PROFILE-20260909 |
| M11-G01-CLOSURE | Active/passive APB environment acceptance passes | pass | LOCAL-APB-RAL-20260908 |
| M12-G01-CLOSURE | Active/passive AXI-lite environment acceptance passes | pass | LOCAL-AXI-RAL-20260908 |
| M13-G01-CLOSURE | RAL frontdoor, predictor, and built-in smoke acceptance passes | pending | Pending |
| M14-G01-LOCAL-DPI-SMOKE | Existing DPI/no-DPI/HDL-DPI smokes pass locally | pass | LOCAL-UVM-SMOKE-0001 |
| M14-G02-C-REFERENCE | C reference-model scoreboard path passes | pass | LOCAL-DPI-REFERENCE-20260907 |
| M14-G03-VPI-BACKDOOR | Minimal VPI/backdoor support or limitation is accepted | in_progress | UVM-BACKDOOR-20260907 |
| M15-G01-CLOSURE | Practical APB and AXI-lite assertion profile passes | pass | [Local protocol proof](sva-protocol-local-2026-09-09.yaml) |
| M16-G01-CLOSURE | Synthetic SoC acceptance regression passes | pass | LOCAL-UVM-SOC-PROFILE-20260909 |
| M17-G01-LOCAL-LANE | Clean and capped original lane passes locally | pass | LOCAL-LANE-CONTRACT-0001 |
| M17-G02-CANONICAL-CI | Clean-checkout canonical CI lane passes | pass | HARNESS-FANOUT-0001, HARNESS-CLEAN-0001 |
| M17-G03-PERFORMANCE | Reproducible performance dashboard is established | pass | UVM-PERFORMANCE-DASHBOARD-20260909 |
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
