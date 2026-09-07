<!-- DESCRIPTION: Verilator: complete UVM 2020 program progress dashboard
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020 program progress

## Explicit compliance and performance goals

The [goal contract](GOALS.md) defines **G-UVM: full IEEE 1800.2-2020 UVM
compliance** and **G-PERF: measured production performance optimization**.
Both remain in progress, with zero of six final acceptance checks accepted
for each. These checks supplement the existing program gates. Documented
mandatory-feature limitations cannot satisfy full compliance, and regression
durations cannot satisfy performance acceptance. `check_tracker.py` rejects
a goal marked pass without its required checks, evidence, and prerequisites.

## Current checkpoint: 2026-09-07

The declared 27-test UVM contract has accepted local, push, and pull-request
CI evidence. Both CI matrices passed all 46 jobs at source
`91089908ad5e464f33676dfd88ffc1e8e266885b`; the PR tested merge
`4c8c048cfa734dcfad26dd50a624b1e0362af662`. Both have source tree
`b678cab2a01c6019f1914c2755cd28b22d82658c`, matching retained local validation.

The downloaded UVM logs each contain exactly 27 passing tests in Makefile
order, successful symlink-safety and cleanup checks, and the 1,000-phase
teardown sentinel. Push elapsed 22:02; PR elapsed 21:17. The retained local
run passed in 30:10. These are regression durations, not performance grades.
[CI evidence](ordered-lane-ci-2026-09-07.yaml) records job URLs, source
provenance, log hashes, pass order, and the exact acceptance sentinels.

The evidence closes the declared M05 class/factory/static-initialization and
M08 TLM/sequence acceptance gates. Current formal progress is **0/21 program
criteria, 4/20 milestone exits, and 28/46 atomic gates**. The compatibility
inventory now has **115/115 passing declared oracles, zero blocked**, using
accumulated evidence. The [eight newly executed tests](dependency-closure-2026-09-07.yaml)
passed locally with the debug compiler and Z3 available. This is not a fresh
115-test run and does not close the constrained-random UVM item milestone.
M07 stays open: the resource direct-lookup XFAIL is not conformance credit.
Unmodified upstream UVM source-flow acceptance and both performance gates remain open.

The fresh ordered source-library run now passes all 27 tests in 78:18 against
the unchanged Accellera 2020.3.1 checkout at `78c06547a`. The run verified
the declared order, clean-before symlink safety, stale-artifact cleanup, and
the 1,000-phase teardown sentinel. The DPI adapter links unchanged upstream
common components with Verilator's HDL backend; the upstream top-level DPI
file has no Verilator backend selector. The
[local source-lane evidence](source-lane-local-2026-09-07.yaml) records source
and binary hashes. The source-selection flow is implemented at `0be94bf57`;
CI validation remains pending; the resource direct-lookup XFAIL is still outside
conformance credit.

M09 is now in progress. New real UVM constrained-random integration exposed
compiler failures beyond the accumulated compatibility inventory. Seven
separate fixes are under validation on
[`codex/uvm-randomization-correctness`](https://github.com/phoenix-hacking/verilator-uvm-extend/tree/codex/uvm-randomization-correctness):
foreach index diagnostics, inherited array element solving, inherited
constraint preparation, inline array resize-and-resolve behavior, failed-solve
post callbacks, mixed standalone/nested constraint processing, and nested
constraint-mode ownership.
The inline-array test passes in both simulation modes and with protected
identifiers; its 16 adjacent regression scenarios also pass. The callback
fix passes its causal regression in both simulation modes and 13 existing
callback/null-randomization scenarios. The nested-constraint fix passes its
expanded causal regression in both modes and 20 adjacent scenarios.

At `a9949d7ae`, the real UVM item test passes completely against unchanged
Accellera 2020.3.1 sources in both single-threaded and multithreaded simulation.
Each mode passes three runs of 64 checked transactions, with seeds 1729, 1729,
and 2718: 384 transactions across six runs. The repeated seed produces identical traces;
the different seed changes them. Modes, failed-solve callbacks, and recovery
checks pass. This is local development evidence using retained
compiler binary SHA-256
`5599913ab5dd2845dfe253faf39731ae7654f413d4312b67dd362bf4e6b880d1`.
The full candidate regression and static analysis remain running. Candidate
CI at `a9949d7ae` exposed a reproducible `t_constraint_mode` failure in both
simulation modes: flattened child constraints read independent parent mode
slots instead of the original child's modes. The correction is published at
`2dbe3b22c`; its final focused regression passes 32/32, including the original
CI failure in both modes, inherited/static modes, deeper nesting, independent
instances, protected identifiers, and setters on empty parents. Optimized
and debug builds, formatting, Python lint, and focused C++ analysis pass.
The earlier reported attribute-check success is withdrawn: the harness returned
success despite Clang parse failures (missing builtin headers and an obsolete
coroutine flag). Attribute validation remains unproven until that checker and
its environment are corrected. The fresh real UVM replay at this seventh correction
also passes both modes: 384 transactions across the same six seeded runs, with
repeatability and recovery checks. Its retained compiler SHA-256 is
`52fdcfcddde4c8d7edf69df07c26e40eb4d610b096f1ae97aaeb748f115a1955`;
logs, model binaries, and trace hashes are preserved under
`/home/holden/verilator-work/uvm-random-2dbe3b22c-artifacts`.
Full regression and new CI for this correction remain pending. Another confirmed
open defect is value preservation after failed randomization: an unsatisfiable
call changes an unconstrained scalar, and a failed array-element solve leaves
the array resized and a scalar changed. Value preservation remains unfixed.
A separate null-child probe aborts while registering nested constraint variables
on both the sixth and seventh compiler revisions; that edge case remains open.
The integrated UVM test remains
uncommitted, and none of these development results advances formal completion
counts or establishes performance.

A separate build correction at `ff0e5c041` makes user C++ files use the same
optimization-flag order as precompiled headers. All four explicit override
regressions fail before the change; those four plus six neighboring build
scenarios pass afterward (10/10). Optimized/debug builds, full formatting,
Python lint, and focused C++ analysis pass. The change is published separately
on `codex/compiler-include-flags`; full regression and CI remain pending.
The attribute-checker corrections are published separately through `6e9227ea1`
on `codex/attribute-parse-errors`. Their causal regression covers 20 serial/parallel
cases and rejects incomplete parsing, failed precompilation, missing compile
commands, and annotation diagnostics even when the unsafe-call count is zero. With matching Clang 18 builtin and GCC 13 C++ headers, the existing
negative test also reproduces all 230 expected unsafe-function diagnostics.
Full formatting and Python lint pass. Actual checks for 16 runtime and six
compiler source files completed with annotation mismatches and a compiler-file
parse failure. Positive annotation acceptance remains open. The MT_SAFE_EXCLUDES
body-check omission is now corrected, with a failing-before test, four independent
safe/unsafe body probes, and two passing final regression drivers. Its golden was
regenerated through the harness. The corrected runtime scan reports 42 unique
unsafe callees and two annotation mismatches; these require review against the
actual locking contracts and are not automatically 42 runtime defects. Compiler
translation-unit selection still needs correction. Broad C++ analysis completed with 11 error-level diagnostics,
despite exit status zero; those findings require review before acceptance.

Recent implementation work has concentrated on M09 and validation tools. None
of those local results closes another capability milestone. Seven milestones
remain not started: M10 coverage, M11 APB, M12 AXI-lite, M13 RAL, M15 protocol
assertions, M16 synthetic SoC, and M18 advanced parity. Performance acceptance
still has no verified improvement measurement.

The independent M14 C reference-scoreboard test is published at `e148bbfbc` on
`codex/uvm-dpi-reference`. It passes all four source/bundled and
single/multithreaded configurations: 1,440 checked DUT samples, with separate
model handles, resets, strings, fixed-array arguments with nonzero bounds,
explicit cleanup, hand-derived reference vectors, and detected injected DUT
errors. The [retained local evidence](dpi-reference-local-2026-09-07.yaml)
accepts **M14-G02-C-REFERENCE**, bringing atomic gates from 27/46 to **28/46**.
This gate specifies the C scoreboard path; CI and full DPI acceptance remain
separate and pending. M14 now has two of three gates accepted and remains open.

A separate small input-only reproduction confirms missing legal dynamic-array
DPI support independently of UVM and randomization. The initial integration
draft also used an output dynamic array, which IEEE 1800-2017 7.7 prohibits;
that draft is not used as an all-legal positive test. The new compiler work on
`codex/dpi-dynamic-arrays` targets legal input/inout arrays and queues, including
empty arrays, nested dimensions, wide values, real numbers, handles, and strings.
The initial dynamic-array snapshot passed 22 focused/neighbor DPI configurations,
including C++14 builds, protected identifiers, and out-of-bounds access. Its debug
compiler passed all seven new configurations. The dynamic-array C scoreboard passed
both simulation modes against unmodified Accellera source, checking 720 DUT
samples and detecting the injected DUT fault in each mode. Artifacts and the
uncommitted source-index tree are retained in
`/home/holden/verilator-work/dpi-dynamic-artifacts/manifest-initial.json`.
These are local development results, not another accepted gate or milestone.
The C source packaging correction is now published at `635aabd5d`; the model
is a `.c` translation unit, the C-header distribution rule recognizes it, and
source-UVM integration passes both modes after the rename. The correction is
integrated into the dynamic-array development branch at `4fddc5ce5`.
Further type validation exposed nine invalid DPI actual arguments that were
previously accepted. The candidate now diagnoses these and adds runtime checks
for sized formal dimensions connected to variable-sized actuals. These newer
changes pass all eight new configurations with both optimized and debug
compilers, plus 15 neighboring configurations. The old `t_dpi_open` fixture
passed packed scalars to unpacked `int[]` formals; it now uses matching
one-element unpacked arrays and retains all six packed widths through canonical
DPI vector access. The 15 neighboring passes combine the initial 13 passes
with both corrected-fixture passes. Seven distribution checks, full formatting,
and focused Python lint pass. Fresh dynamic UVM integration passes both modes
against source UVM in 12:48 and bundled UVM in 10:28: all four configurations
pass, with 1,440 checked DUT samples and fault detection in each configuration.
The feature is committed at `9477897b7` on `codex/dpi-dynamic-arrays`.
Matching sources, binaries, and logs are retained in
`/home/holden/verilator-work/dpi-dynamic-artifacts/type-validation/manifest-four-modes.json`.
Broader C++ analysis still has existing runtime findings, and no global
static-analysis or release-regression pass is claimed.
An independent baseline probe also confirms incorrect nested `foreach` indices
for queues under fixed dimensions with nonzero bounds. It is retained at
`/home/holden/verilator-work/foreach-nonzero-probe` and remains an open compiler
defect; the DPI oracle now uses explicit inner indices and checks queue sizes.

The minimal VPI/backdoor gate now has a full-UVM clocked RTL fixture implemented
at `ff023501c` on `codex/uvm-backdoor`. All four source/bundled configurations
pass: each checks 115 HDL reads, 14 deposits, 16 forces/releases, and 62 clock
cycles, including 31-bit state, 65-bit memory, nonzero bounds, memory aliasing,
and detected injected DUT corruption. The [local backdoor evidence](backdoor-local-2026-09-07.yaml)
records all four configurations and matching retained artifacts. M14-G03 is
now in progress with local proof passed and required exact-revision CI and
release regression pending. Formal totals remain 4/20 milestones and 28/46
atomic gates; the backdoor gate and full-compliance requirements remain open.

Both PRs remain draft for human review and Contributor Agreement/DCO. No new
compiler implementation is claimed by this evidence update. Older dated
results and detailed tables below are historical; use `tracker.yaml` and this
checkpoint for current status.

Historical detailed snapshot: **2026-08-09** (PR #41 retains its recorded local and exact-head
CI closure; stacked PR #42 contains a source-integrated 27-test successor lane
whose tested integration-head pull-request CI passed at workflow level while
accepted local validation remains pending because of `ENOSPC`; later
evidence-only `[ci skip]` commits are not tested revisions)

Repository: `phoenix-hacking/verilator-uvm-extend`

Active branch: `codex/uvm-program-integration-wip`

Active pull request: [#42, Expand UVM class, config, TLM, and sequence acceptance](https://github.com/phoenix-hacking/verilator-uvm-extend/pull/42), stacked on draft PR #41.

This is the human-readable, full-program dashboard for the objective:

> Make this Verilator checkout capable of evidence-backed UVM 2020
> verification for a large functional SoC.

It intentionally reports several independent progress measures. A passing
smoke lane, a high compatibility-corpus rate, or many small atomic gates does
not mean that the end-to-end UVM program is complete.

The source-of-truth order is:

1. `tracker.yaml` owns machine-checked statuses and evidence IDs.
1. `PLAN.md` owns the current PR lane contract and reproduction protocol.
1. `MATRIX.md` owns accepted evidence and claim boundaries.
1. `ROADMAP.md`, `SUPPORT_MATRIX.md`, and `roadmap-tracker.yaml` preserve the
   broader pre-PR requirements and dependency plan.
1. GitHub issues #1-#40 own public work items.
1. This file combines those sources into an honest status and forecast.

Run this before trusting the exact roll-ups:

```sh
python3 nodist/uvm2020_plan/check_tracker.py
```

## Repository text-file audit

The 2026-08-08 sweep read all 23 repository paths matched by `*.txt`
(3,473 lines) and classified their purpose before changing any of them:

| Class | Files | Disposition |
|---|---:|---|
| License texts | 10 | Required legal source material; preserve verbatim. |
| CMake inputs named `CMakeLists.txt` | 9 | Executable build configuration, not work queues; preserve. |
| UVM baseline manifest | 1 | `baseline-tests.txt` is the frozen 72-test evidence inventory; preserve and validate through the tracker. |
| Tool/dependency inputs | 3 | `docs/spelling.txt`, `python-dev-requirements.txt`, and `src/cppcheck-suppressions.txt` are active tool inputs; preserve. |

The only actionable marker in that set is the existing broad-upstream comment
at `src/cppcheck-suppressions.txt:52`, which covers const-correctness
suppressions across many compiler subsystems. It is not a UVM tracker and is
outside PR #41's focused semantic scope. Deleting the comment or suppression
list would hide work rather than complete it, so it remains explicit. The UVM
action state is instead reconciled in the machine-checked YAML and Markdown
files in this directory.

## What 100% means

The program is 100% complete only when all of the following are true:

- all 21 program criteria `C01`-`C21` are formally `pass`;
- all 20 public capability milestones `M00`-`M19` have exited;
- all 46 required atomic gates have accepted, reproducible evidence;
- PR #41 and its successors pass every required supported-host check;
- every blocked corpus entry is executed or has an accepted support-envelope
  disposition;
- config/resource DB, components, TLM, sequences, randomization, APB,
  AXI-lite, RAL, coverage, SVA, DPI/reference modeling, VPI/backdoor, and the
  synthetic SoC work end to end;
- fixed-seed replay, diagnostics, user selection, clean-checkout operation,
  nightly operation, and performance baselines are reproducible;
- every public issue, matrix row, tracker row, test, and limitation agrees;
- no open technical blocker contradicts a claimed capability.

Anything less remains incomplete, even if a narrower test lane is green.

## Executive dashboard

| Measure | Progress | Exact state | Honest interpretation |
|---|---:|---:|---|
| Full program criteria | `[----------]` **0.0%** | 0/21 passed | No end-state criterion has cleared every mapped milestone. |
| Public milestone exits | `[#---------]` **10.0%** | 2/20 exited | Only M00 and M01 have formally exited. |
| Atomic gates | `[#####-----]` **52.2%** | 24/46 passed | Useful foundation progress, but later verticals are represented by fewer, much larger gates. |
| Effort-weighted program | `[###-------]` **about 30%** | Estimated 25-35% | The best single estimate of real engineering completion. |
| Remaining engineering | `[#######---]` **about 70%** | Estimated 65-75% | Most integrated UVM verticals remain. |
| Historical PR #41 evidence slice | `11/11 accepted` | Original three-test proof environments accepted at their recorded revisions | Historical evidence only; it is not current-head technical closure or full-program completion. |
| Focused PR #41 technical scope | **Technical closure passed; no broader completion percentage assigned** | Local and exact-head push/PR focused and UVM targets passed; format and both 46-job matrices passed | Human review and DCO remain separate, and the PR remains draft. |
| Current expanded UVM lane | **Workflow-level pull-request CI pass; local pending** | Run 31346076613 passed source `b09ff3e78f97e928907b8f2929bf8bacab6b16bd` through synthetic merge `cda98bba177663b2df45745d2e946ddf0e274d73` and includes the configured current `uvm2020` job; no job-level metadata is claimed | Overall validation remains pending because accepted local evidence is blocked by `ENOSPC`; historical 20/20 results remain separately scoped. |
| Mixed compatibility corpus | `[#########-]` **87.0% verified** | 100/115 passed; 8 blocked; 7 pending | Compatibility inventory only, not IEEE/UVM conformance. |
| Frozen 72-test selection | `[##########]` **100% dispositioned** | 64 pass, 1 environment block, 7 dependency skips | Every entry is classified, but only 64 are semantic passes. |
| Competitive C0 tracking envelope | `[##########]` **100%** | Planning/tracking exists | Tracking is complete enough to expose the remaining work. |
| Competitive C1 usable core | `[####------]` **about 40%** | Not formally achieved | Scheduler/factory/phasing/VIF foundations exist; DB/TLM/sequences/randomization/coverage remain. |
| Competitive C2 protocol level | `[----------]` **0%** | Not started | APB and AXI-lite environments are not implemented. |
| Competitive C3 SoC level | `[----------]` **0%** | Not started | The synthetic SoC regression is not implemented. |

## Completion forecast

These ranges are engineering-time estimates, not promises. They assume an
experienced contributor working from this checkout, normal review latency,
access to supported CI hosts, and no major redesign of upstream UVM or the
constraint/coverage architecture.

| Staffing model | Estimated remaining calendar time | Approximate finish from this snapshot | Confidence |
|---|---:|---:|---|
| One full-time experienced engineer | **15-30 months** | Q4 2027 through Q1 2029 | Low-to-medium; compiler/runtime discoveries can expand the range. |
| Two experienced engineers with useful parallelism | **9-18 months** | Q2 2027 through Q1 2028 | Medium-low; many milestones are dependency-ordered. |
| Three experienced engineers split across compiler/runtime, UVM libraries, and environments | **6-12 months** | Q1 through Q3 2027 | Low unless integration and review capacity scale too. |

Estimated remaining effort is **12-24 engineer-months**. Summing individual
rows below will over-count because APB, RAL, coverage, SVA, packaging, and SoC
work overlap. The largest uncertainty is not writing tests; it is discovering
and correcting compiler/runtime semantics under realistic UVM pressure.

## Immediate critical path

| Order | Work | Bar | Current evidence | Open work | Remaining estimate |
|---:|---|---:|---|---|---:|
| 1 | Focused named-disable/process closure | Pass; unscored | Local, push CI, and PR CI passed 30/30 with cleanup; the implementation has an explicit support envelope. | None inside this focused technical gate; preserve evidence. | 0 |
| 2 | Current 27-test UVM lane | Workflow-level pull-request CI pass; local pending | Run 31346076613 passed source `b09ff3e78f97e928907b8f2929bf8bacab6b16bd` through synthetic merge `cda98bba177663b2df45745d2e946ddf0e274d73`; the successful aggregate includes the configured current `uvm2020` job. | Obtain accepted local execution after the `ENOSPC` blocker is removed; do not treat later evidence-only commits as tested. | 1-2 days after executable access |
| 3 | PR #41 current-head technical CI | Pass | Format succeeded; push and PR `build-test` each passed 46/46, including all 25 former-red shards and all five `dist-vlt-0` jobs. | Keep the tracker-only recording child scoped as untested documentation. | 0 |
| 4 | Contributor Agreement/DCO | `[----------]` external | Runs 31311244130 and 31311246183 request a human-signed `docs/CONTRIBUTORS` entry. | Human contributor must satisfy repository policy; agents must not edit `docs/CONTRIBUTORS`. | Usually \<1 day of human time |
| 5 | Align all planning artifacts | `[########--]` about 80% | Canonical PR files validate; broad pre-PR files and `PROGRESS.md` are published. | Align stale issue bodies, split over-broad gates, and remove namespace ambiguity. | 2-5 days |
| 6 | M07 config/resource/component closure | `[######----]` source-integrated; 0% formal | Strict config/resource/component and numeric-precedence source tests are present, and workflow-level pull-request CI passed the configured current lane. | Obtain accepted local proof and close the direct-path deviation; a bounded direct-path XFAIL is not conformance. | 2-5 days after executable access |

## All 21 program criteria

The bar in this table is **mapped-gate readiness**, not formal criterion
completion. Formal completion remains binary and is 0/21. A nonzero bar can
come from supporting milestones that do not directly implement the named
feature; such cases are called out explicitly.

| ID | Requirement | Readiness bar | Formal state | Accepted evidence now | Open work to pass | Remaining estimate |
|---|---|---:|---|---|---|---:|
| C01 | Unmodified Accellera UVM 2020.3.1 source flow | `[########--]` 5/6, 83.3% | In progress | Concatenated vendored package no-DPI/DPI/HDL-DPI smokes and factory API pass. | Complete P0 API inventory and prove a genuinely unmodified upstream source flow; current packed artifact is not that proof. | 2-4 weeks |
| C02 | Tracker reaches complete or documented zero-blocker state | `[#######---]` 5/7, 71.4% | In progress | Tracker/checker, manifest, baseline dispositions, and dashboard mechanics pass. | Align broad/canonical milestone namespaces, issue bodies, claim levels, and every proof path; finish all technical work before final pass. | 1-3 weeks of hygiene spread across program |
| C03 | All P0 IEEE 1800 reduced tests pass | `[########--]` 3/4, 75.0% | In progress | Wait-zero, finish/clocking, and recursive process-kill slices pass. | Complete clause inventory, fill missing reductions, and classify every P0 semantic dependency. | 2-4 weeks |
| C04 | Core UVM factory, reporting, phasing, DB, TLM, and sequence APIs pass | `[#####-----]` 7/14, 50.0% | In progress | Package, factory, phasing, VIF/config slice, and process foundations pass. | Class/static closure, complete config/resource/component flow, TLM, sequences, canonical CI, and Ubuntu 22 stability. | 6-14 weeks |
| C05 | Virtual interfaces propagate through config DB and config objects | `[######----]` 3/5, 60.0% | In progress | Typed driver/monitor modports propagate and five exact clocking events pass. | Consolidated config object identity, resource precedence/scope, agent hierarchy, and APB integration. | 1-3 weeks |
| C06 | Clocking blocks work through virtual interfaces | `[########--]` 3/4, 75.0% | In progress | Reduced and UVM VIF/clocking evidence passes. | APB setup/access cycles through real driver and monitor; tracker currently over-couples this criterion to APB. | 2-4 weeks |
| C07 | Active and passive APB agent passes | `[----------]` 0/1, 0% | Not started | Only lower-layer VIF/clocking prerequisites. | Interface, item, config, active/passive agent, sequencer, driver, monitor, scoreboard, coverage, assertions, adapter, wait/error cases. | 3-6 weeks |
| C08 | Active and passive AXI-lite agent passes | `[----------]` 0/1, 0% | Not started | No direct evidence. | Master, slave responder, independent channels, ready/valid, backpressure, monitor, scoreboard, coverage, assertions, adapter, active/passive modes. | 4-8 weeks |
| C09 | Scalable AXI-style synthetic SoC smoke passes | `[----------]` 0/1, 0% | Not started | No direct evidence. | Integrated RTL/UVM SoC with clocks/reset, CSR, DMA, IRQ, memory, APB/AXI-lite, scoreboards, coverage, SVA, RAL, DPI, and replay. | 6-12 weeks after prerequisites |
| C10 | RAL frontdoor mirror and update pass | `[----------]` 0/1, 0% | Not started | No direct evidence. | Register model, maps, adapter, frontdoor read/write, mirror/update, access policies, byte enables, and reset semantics. | 3-6 weeks |
| C11 | RAL predictor passes | `[----------]` 0/1, 0% | Not started | No direct evidence. | Monitor-to-predictor path, observed/mirrored consistency, error and reset behavior. | 2-4 weeks, overlapping C10 |
| C12 | Built-in RAL reset, access, and bit-bash smokes pass | `[----------]` 0/1, 0% | Not started | No direct evidence. | Separate reset, access, and bit-bash proofs; current tracker compresses C10-C12 into one gate. | 2-5 weeks, overlapping C10 |
| C13 | Constrained-random fixed-seed replay passes | `[----------]` 0/2, 0% | In progress | Seven compiler corrections have focused evidence; real UVM replay passes 384 transactions across six seeded runs at `2dbe3b22c`. | Failed-solve value preservation, null-child handling, complete constraint coverage, full regression/CI, and SoC integration. | 5-12 weeks |
| C14 | Functional coverage from UVM classes passes | `[----------]` 0/1, 0% | Not started | No direct UVM-class coverage evidence. | Covergroups in classes, subscribers, sampling correctness, bins/crosses, and precise unsupported limits. | 4-10 weeks |
| C15 | Coverage report and merge pass | `[#####-----]` 2/4, 50.0% prerequisite readiness | Not started | Packaging/CI gates contribute mechanically; no coverage feature passes. | Coverage data/report generation, deterministic merge, CI artifacts, and user workflow. Direct feature progress is 0%. | 5-12 weeks |
| C16 | APB and AXI-lite protocol assertions pass | `[----------]` 0/1, 0% | Not started | No direct evidence. | Practical SVA subset, APB/AXI properties, pass/fail reductions, monitor agreement, unsupported-construct limits. | 3-8 weeks |
| C17 | DPI and no-DPI flows are tested and documented | `[###-------]` 1/3, 33.3% | In progress | No-DPI, DPI package, and HDL-DPI smokes pass. | C reference scoreboard, full boundary policy, strings/chandles/open arrays as needed, clean user documentation. | 1-4 weeks |
| C18 | VPI and backdoor strategy is implemented or documented | `[##--------]` 1/4, 25.0% prerequisite readiness | Not started | The mapped DPI smoke does not prove VPI/backdoor. | Minimal supported VPI/backdoor path or explicit accepted limitation, RAL impact, force/release and advanced parity disposition. | 2-8 weeks |
| C19 | Diagnostics provide useful source file, line, and context | `[#######---]` 2/3, 66.7% prerequisite readiness | Not started | Lane/CI infrastructure exists; no dedicated diagnostic gate exists. | Add explicit malformed-UVM reductions and golden source/line/context acceptance; split tracker gate. Direct feature progress is 0%. | 1-3 weeks |
| C20 | UVM 2020 user-facing selection flow exists | `[#######---]` 2/3, 66.7% prerequisite readiness | Not started | Developer-only `make -C test_regress uvm2020` exists. | Productized selection, documented clean-checkout commands, dependencies, DPI/no-DPI choice, examples, and supported envelope. | 1-3 weeks |
| C21 | Nightly synthetic SoC regression passes reproducibly | `[#####-----]` 2/4, 50.0% prerequisite readiness | Not started | Generic CI/lane infrastructure exists; no SoC workload or nightly job exists. | Finish M16, seed/replay policy, nightly scheduling, artifacts, triage, runtime/performance budgets, and repeated green evidence. | 7-14 weeks after prerequisites |

## Public milestone dashboard

Bars are exact passed-gate fractions. A milestone exits only at 100%.

| Milestone / issue | Capability | Gate bar | Tracker state | Principal open work | Remaining estimate |
|---|---|---:|---|---|---:|
| M00 / [#1](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/1) | Source-tree build and reproducible baseline | `[##########]` 4/4, 100% | **Pass/exited** | Keep evidence current as branch changes. | Maintenance only |
| M01 / [#2](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/2) | Existing UVM smoke baseline | `[##########]` 3/3, 100% | **Pass/exited** | Preserve on every supported host. | Maintenance only |
| M02 / [#3](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/3) | IEEE 1800 P0 semantic audit | `[########--]` 3/4, 75% | In progress | Complete P0 clause matrix. | 2-4 weeks |
| M03 / [#4](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/4) | UVM 1800.2 API audit | `[#######---]` 2/3, 66.7% | In progress | Complete every P0 UVM API category. | 2-4 weeks |
| M04 / [#5](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/5) | Scheduler, process, and fork closure | `[#######---]` 4/6, 66.7% | In progress | Publish and prove the Ubuntu 22 teardown fix; event regions and RTL performance proof remain. | 1-3 weeks |
| M05 / [#6](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/6) | Class, factory, and static initialization | `[###-------]` 1/3, 33.3% | In progress | Class identity/static initialization matrix and canonical CI. | 2-5 weeks |
| M06 / [#7](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/7) | Interfaces, VIFs, modports, clocking | `[########--]` 3/4, 75% | In progress | APB setup/access proof through driver and monitor. | 2-4 weeks |
| M07 / [#8](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/8) | Config/resource DB and component flow | `[----------]` 0/1, 0% | In progress at source level | Source acceptance tests are present; executable lane proof and direct-path conformance remain pending. | 2-5 days after executable access |
| M08 / [#9](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/9) | TLM and sequence flow | `[----------]` 0/1, 0% | In progress at source level | TLM fanout/FIFO and sequence-driver/cancellation source tests are present; executable lane proof remains pending. | 2-5 days after executable access |
| M09 / [#10](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/10) | Constrained-random sequence items | `[----------]` 0/1, 0% | Not started | Solver/runtime semantics and deterministic UVM item replay. | 4-10 weeks |
| M10 / [#11](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/11) | Functional coverage from UVM classes | `[----------]` 0/1, 0% | Not started | UVM covergroups/subscribers plus report and merge. | 4-10 weeks |
| M11 / [#12](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/12) | APB protocol environment | `[----------]` 0/1, 0% | Not started | Complete active/passive APB environment. | 3-6 weeks |
| M12 / [#13](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/13) | AXI-lite protocol environment | `[----------]` 0/1, 0% | Not started | Complete active/passive AXI-lite environment. | 4-8 weeks |
| M13 / [#14](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/14) | RAL frontdoor and predictor | `[----------]` 0/1, 0% | Not started | Frontdoor, predictor, reset/access/bit-bash; split broad gate. | 4-8 weeks |
| M14 / [#15](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/15) | DPI/reference model and VPI strategy | `[###-------]` 1/3, 33.3% | In progress | C reference scoreboard and accepted VPI/backdoor disposition. | 2-6 weeks |
| M15 / [#16](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/16) | SVA protocol profile | `[----------]` 0/1, 0% | Not started | Practical APB/AXI-lite assertion subset. | 3-8 weeks |
| M16 / [#17](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/17) | Synthetic SoC regression | `[----------]` 0/1, 0% | Not started | Integrated SoC acceptance workload. | 6-12 weeks after lower layers |
| M17 / [#18](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/18) | Packaging, CI, and performance | `[#######---]` 2/3, 66.7% | In progress | Reproducible performance dashboard and productized workflow. | 1-3 weeks |
| M18 / [#19](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/19) | Advanced parity limits | `[----------]` 0/1, 0% | Not started | Implement or explicitly accept each advanced gap. | 2-8 weeks |
| M19 / [#20](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/20) | Competitive closure and issue hygiene | `[###-------]` 1/3, 33.3% | In progress | Roadmap/issue alignment and complete C0-C3 proof paths. | 1-3 weeks spread across program |

## All 46 atomic gates

Each bar is binary because tracker gates accept only reproducible proof, not
partial credit. The estimate is remaining focused engineer time and overlaps
other rows.

| Gate | Requirement | Bar / status | Accepted evidence or exact open proof | Remaining estimate |
|---|---|---:|---|---:|
| M00-G01-SOURCE-BUILD | Source-tree build completes | `[##########]` Pass | `LOCAL-SOURCE-BUILD-0001` | 0 |
| M00-G02-TRACKER-MANIFEST | Tracker schema and compatibility manifest validate | `[##########]` Pass | `LOCAL-TRACKER-MANIFEST-0001` | 0 |
| M00-G03-FULL-BASELINE | Frozen inventory has reproducible dispositions | `[##########]` Pass | `FULL-BASELINE-0001` | 0 |
| M00-G04-DASHBOARD | Allowed-state dashboard is reproducible | `[##########]` Pass | `LOCAL-TRACKER-MANIFEST-0001` | 0 |
| M01-G01-LOCAL-SMOKE | Existing three-test UVM smoke passes locally | `[##########]` Pass | `LOCAL-UVM-SMOKE-0001` | 0 |
| M01-G02-PR-CI | Original clean lane passes canonical CI | `[##########]` Pass | Harness, no-DPI, DPI, and HDL-DPI evidence IDs | 0 |
| M01-G03-EXPANDED-LANE | Expanded lane completes locally | `[##########]` Pass | `LOCAL-LANE-CONTRACT-0001` | 0 |
| M02-G01-WAIT-ZERO | Constant-false wait and neighbors pass | `[##########]` Pass | `LOCAL-WAIT-ZERO-0001` | 0 |
| M02-G02-FINISH-CLOCKING | Finish audit and reduced virtual clocking pass | `[##########]` Pass | `LOCAL-FIRST-BLOCKERS-0001` | 0 |
| M02-G03-PROCESS-KILL | Recursive process kill and neighbors pass | `[##########]` Pass | `LOCAL-PROCESS-KILL-0001` | 0 |
| M02-G04-P0-MATRIX | Every P0 clause has a reduced result and disposition | `[----------]` Pending | Build clause inventory, link existing tests, add missing reductions, classify limits. | 2-4 weeks |
| M03-G01-PACKAGE-SMOKE | Package and DPI smokes pass locally | `[##########]` Pass | `LOCAL-UVM-SMOKE-0001` | 0 |
| M03-G02-FACTORY-API | Expanded factory API reduction passes | `[##########]` Pass | `LOCAL-FACTORY-0001` | 0 |
| M03-G03-P0-API-INVENTORY | Every P0 UVM API category has a result | `[----------]` Pending | Inventory reporting, sync, containers, TLM, components, sequences, DB, macros, package and command-line APIs. | 2-4 weeks |
| M04-G01-WAIT | Constant-false wait semantics pass | `[##########]` Pass | `LOCAL-WAIT-ZERO-0001` | 0 |
| M04-G02-FINISH | Finish termination audit passes | `[##########]` Pass | `LOCAL-FIRST-BLOCKERS-0001` | 0 |
| M04-G03-KILL | Recursive process-kill slice passes | `[##########]` Pass | `LOCAL-PROCESS-KILL-0001` | 0 |
| M04-G04-UVM-PHASING | Phasing, objections, and phase kill close | `[##########]` Pass | `LOCAL-UVM-PHASING-0001`; Ubuntu 22 stability is now under revalidation | 0-2 weeks if evidence must be revised |
| M04-G05-EVENT-REGIONS | Required event-region semantics close | `[----------]` Pending | Explicit active/inactive/NBA/reactive ordering matrix and UVM-linked reductions. | 1-3 weeks |
| M04-G06-RTL-PERFORMANCE | RTL fast path is preserved | `[----------]` Pending | Reproducible before/after compile/runtime/memory dashboard with thresholds. | 3-5 days |
| M05-G01-FACTORY | Factory override and creation API passes | `[##########]` Pass | `LOCAL-FACTORY-0001` | 0 |
| M05-G02-CLASS-STATIC-CLOSURE | Class identity and static initialization close | `[----------]` Pending | Parameterized identity, typedef/type linking, nested classes, virtual dispatch, static order, base handles. | 2-5 weeks |
| M05-G03-CANONICAL-CI | Class/factory closure passes canonical CI | `[----------]` Pending | Finish G02, promote exact tests, prove supported-host CI. | 2-5 days after G02 |
| M06-G01-REDUCED-CLOCKING | Reduced VIF clocking drive/sample passes | `[##########]` Pass | `LOCAL-FIRST-BLOCKERS-0001` | 0 |
| M06-G02-UVM-VIF | UVM config-DB VIF clocking passes | `[##########]` Pass | `LOCAL-UVM-VIF-CLOCKING-0001` | 0 |
| M06-G03-SUBINTERFACE-TRIGGERS | Sub-interface and VIF triggers pass | `[##########]` Pass | `LOCAL-VIF-NEIGHBORS-0001` | 0 |
| M06-G04-APB-CYCLES | APB setup/access cycles pass through driver/monitor | `[----------]` Pending | Implement cycle-accurate APB interface, driver, monitor, and exact observations. | 2-4 weeks |
| M07-G01-CLOSURE | Config/resource DB and component acceptance passes | `[----------]` Pending | Source assertions cover hierarchy/order/identity/scope/override/update/negative/report/timeout behavior; obtain executable lane proof. Bounded direct-path XFAIL is not conformance. | 2-5 days after executable access |
| M08-G01-CLOSURE | TLM and sequence handshake acceptance passes | `[----------]` Pending | Source covers analysis fanout/FIFO, predictor/scoreboard, sequencer-driver handshake, stop/kill, and reuse; obtain executable lane proof. | 2-5 days after executable access |
| M09-G01-CLOSURE | Deterministic constrained-random UVM items pass | `[----------]` Pending | Solver, fields, inline/member constraints, arrays, modes, failures, fixed-seed replay. | 4-10 weeks |
| M10-G01-CLOSURE | UVM class coverage/report/merge passes | `[----------]` Pending | Covergroups/subscribers, data generation, report, merge, CI artifact flow. | 4-10 weeks |
| M11-G01-CLOSURE | Active/passive APB environment passes | `[----------]` Pending | Full APB vertical including scoreboard, coverage, assertions, RAL adapter. | 3-6 weeks |
| M12-G01-CLOSURE | Active/passive AXI-lite environment passes | `[----------]` Pending | Full AXI-lite vertical including backpressure and independent channels. | 4-8 weeks |
| M13-G01-CLOSURE | RAL frontdoor/predictor/built-in smokes pass | `[----------]` Pending | Model/map/adapter/frontdoor/predictor/reset/access/bit-bash; split into separate gates. | 4-8 weeks |
| M14-G01-LOCAL-DPI-SMOKE | DPI/no-DPI/HDL-DPI smokes pass | `[##########]` Pass | `LOCAL-UVM-SMOKE-0001` | 0 |
| M14-G02-C-REFERENCE | C reference scoreboard path passes | `[----------]` Pending | DPI data boundary and end-to-end scoreboard comparison. | 1-3 weeks |
| M14-G03-VPI-BACKDOOR | Minimal VPI/backdoor strategy is accepted | `[----------]` Pending | Implement supported minimum or document precise limitation and RAL impact. | 2-6 weeks |
| M15-G01-CLOSURE | Practical APB/AXI-lite SVA profile passes | `[----------]` Pending | Properties, negative tests, diagnostics, protocol integration, limits. | 3-8 weeks |
| M16-G01-CLOSURE | Synthetic SoC acceptance passes | `[----------]` Pending | Multi-agent SoC with reset/CSR/DMA/IRQ/memory/RAL/DPI/coverage/SVA/replay. | 6-12 weeks after prerequisites |
| M17-G01-LOCAL-LANE | Clean capped original lane passes locally | `[##########]` Pass | `LOCAL-LANE-CONTRACT-0001` | 0 |
| M17-G02-CANONICAL-CI | Clean-checkout canonical lane passes | `[##########]` Pass | `HARNESS-FANOUT-0001`, `HARNESS-CLEAN-0001` | 0; preserve |
| M17-G03-PERFORMANCE | Reproducible performance dashboard exists | `[----------]` Pending | Baselines, thresholds, history, compiler/runtime/memory metrics, user command. | 1-2 weeks |
| M18-G01-DISPOSITION | Advanced gaps implemented or accepted | `[----------]` Pending | VPI/debug DB, force/release, full SVA, four-state parity, UCIS, transaction DB, encrypted IP, SDF/timing checks. | 2-8 weeks |
| M19-G01-TRACKER-SCHEMA | Machine-checked tracker and manifest validate | `[##########]` Pass | `LOCAL-TRACKER-MANIFEST-0001` | 0 |
| M19-G02-ROADMAP-ALIGNMENT | Public trackers and leaf issues align | `[----------]` Pending | Reconcile `M0-M17` dependency names with `M00-M19`, update stale GitHub bars, split broad gates, publish dashboard. | 3-5 days |
| M19-G03-CLAIM-LEVELS | C0-C3 have complete proof paths | `[----------]` Pending | Map every claim to tests/evidence/limits and prevent unsupported promotion. | 1-3 weeks across program |

## GitHub public issue audit

All 40 issues are currently open. That is not identical to tracker status:
M00 and M01 have exited in the tracker but their GitHub issues remain open.
Several GitHub issue bodies still show their 2026-07-03 initial `[----------]`
bar even where later tracker evidence exists. Updating those bodies is open
M19-G02 work; this dashboard does not silently treat stale issue text as proof.

### Milestone issues #1-#20

| Issues | Live GitHub state | Tracker interpretation | Open action |
|---|---|---|---|
| #1-#2 | Open | M00 and M01 passed/exited | Update body evidence and decide whether maintainers close or retain as umbrella issues. |
| #3-#7 | Open | M02-M06 in progress | Keep open until every atomic gate in the milestone passes. |
| #8-#9 | Open | M07-M08 source integration in progress; formal gates pending | Execute the integrated config/resource/TLM/sequence tests and preserve claim boundaries. |
| #10-#14 | Open | M09-M13 formally not started | Implement constrained-random through RAL verticals. |
| #15 | Open | M14 in progress | C reference and VPI/backdoor work remain. |
| #16-#17 | Open | M15-M16 not started | SVA and synthetic SoC remain. |
| #18 | Open | M17 in progress | Performance/productization remains. |
| #19 | Open | M18 not started | Advanced parity dispositions remain. |
| #20 | Open | M19 in progress | Align every tracker, issue, claim, test, and limitation. |

### Leaf issues #21-#40

The first bar is the progress explicitly present in the live GitHub body. The
second is supporting owner-milestone gate readiness; it must not be mistaken
for direct leaf acceptance.

| Leaf | Requirement | GitHub body bar | Owner-gate readiness | Direct evidence and open acceptance work | Remaining estimate |
|---|---|---:|---:|---|---:|
| A01 / [#21](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/21) | Upstream UVM package elaborates unmodified | `[########--]` 83.3% | 5/6, 83.3% | Packed package smokes pass; prove truly unmodified upstream tree and complete API category. | 2-4 weeks |
| A02 / [#22](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/22) | Cookbook sample coverage | `[----------]` 0% | 2/6, 33.3% | Historical config/factory work exists; inventory and prove build/connect/config/TLM/sequence/RAL Cookbook patterns. | 4-10 weeks across M07/M08/M13 |
| A03 / [#23](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/23) | Generic interface support | `[----------]` 0% | 3/4, 75% | VIF/config/clocking passes; generic-interface parameterization and real agent/APB flow remain. | 1-3 weeks |
| A04 / [#24](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/24) | Parameterized class default resolution | `[----------]` 0% | 1/3, 33.3% | Historical class shard evidence exists; add explicit UVM factory/sequence acceptance and tracker evidence. | 3-7 days |
| A05 / [#25](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/25) | Parameter-dependent type linking | `[----------]` 0% | 1/3, 33.3% | Historical reductions exist; prove all relevant dtypes in UVM parameterized classes. | 3-7 days |
| A06 / [#26](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/26) | Typedef linking in UVM class/package contexts | `[----------]` 0% | 1/3, 33.3% | Link reduced typedef tests to UVM-heavy package/class acceptance. | 3-7 days |
| A07 / [#27](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/27) | Type as class parameter | `[----------]` 0% | 1/3, 33.3% | Historical class evidence exists; prove factory, adapter, and sequence uses. | 3-7 days |
| A08 / [#28](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/28) | Nested class support | `[----------]` 0% | 1/3, 33.3% | Historical reductions exist; prove lookup/construction/inheritance/parameterization needed by UVM. | 3-7 days |
| A09 / [#29](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/29) | Dynamic-cast expression purity | `[----------]` 0% | 4/7, 57.1% | Historical cast/class evidence exists; add optimization-sensitive reduction and link affected UVM path. | 2-5 days |
| A10 / [#30](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/30) | Select-expression side effects | `[----------]` 0% | 4/7, 57.1% | Add explicit side-effect reductions and Cookbook/UVM linkage. | 2-5 days |
| A11 / [#31](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/31) | Complex/member-select `randomize with` | `[----------]` 0% | 0/1, 0% | Implement/prove solver handling in reduced and UVM sequence-item tests. | 1-3 weeks |
| A12 / [#32](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/32) | `$countones` in constraints | `[----------]` 0% | 0/1, 0% | Reduced solver proof and sequence-item usage. | 3-10 days |
| A13 / [#33](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/33) | `randomize with` on aliased types | `[----------]` 0% | 0/1, 0% | Alias/link/solver reduction and UVM item proof. | 3-10 days |
| A14 / [#34](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/34) | `randomize with` for parameterized classes | `[----------]` 0% | 1/4, 25% | Complete both M05 class identity and M09 solver paths in UVM items. | 1-3 weeks |
| A15 / [#35](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/35) | Size constraints | `[----------]` 0% | 0/1, 0% | Dynamic-array/queue size constraints, diagnostics, precise unsupported forms. | 1-3 weeks |
| A16 / [#36](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/36) | Rand dynamic arrays, null handles, object elements | `[----------]` 0% | 0/1, 0% | Solver/runtime allocation semantics and deterministic UVM item proof. | 2-4 weeks |
| A17 / [#37](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/37) | Covergroup parsing and initial elaboration | `[----------]` 0% | 0/1, 0% | Reduced parsing/elaboration plus UVM subscriber workload or precise limits. | 2-5 weeks |
| A18 / [#38](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/38) | Disable-by-label with forks | `[----------]` 0% | 4/6, 66.7% | Focused exact-head CI is green; add explicit leaf evidence and broader UVM phase/sequence kill coverage. | 3-10 days |
| A19 / [#39](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/39) | `UVM_NO_DPI` tutorial flow | `[#######---]` 66.7% | 6/9, 66.7% | Clean command works; finish reference/VPI boundary, productization, performance, and documentation. | 1-3 weeks |
| A20 / [#40](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/40) | Dashboard and SV test-suite coverage alignment | `[----------]` 0% stale | 7/10, 70% | Dashboard/checker and inventory exist; publish this file, align all issue bodies and claim links, remove stale/mixed accounting. | 3-5 days |

## PR #41 and current CI state

PR #41 remains a focused named-disable/process/runtime effort inside the much
broader UVM program. Its focused technical closure has passed but is not
converted into a broader completion percentage. The
current Makefile contains two separate gates: 15 focused tests in both `vlt`
and `vltmt`, and 20 ordered UVM integration tests in `vlt`. Both current local
gates passed. Exact-head CI is now scoped to published source head
`ea172f63c5ddab12a5ca032e119b2f1a95b4e71e` (tree
`469066ed27dc53a0977f7131a6ffd0d30ce71879`) and GitHub's synthetic merge
`19ca7867bdff8fc60c35e11132d37b88ab2df1c5`. Push and pull-request
`build-test` runs passed 46/46 jobs each and are accepted exact-head evidence.
The older 15-test UVM and supported-host results below are historical
evidence, not a statement of current CI or merge readiness. Independently,
formal full-program completion remains 0/21.

| Area | Current state | Exact evidence | Open work |
|---|---|---|---|
| Format | Pass | Run 31311244123 succeeded for `ea172f63`. | None technical. |
| Builds | Pass | Push run 31311244235 and PR run 31311246321 each passed 46/46 for `ea172f63` / `19ca7867`. | None technical. |
| Focused named-disable lane | Local and exact-head CI pass | Local 30/30; push job 93239581011 passed 30/0 in 1:36; PR job 93239545832 passed 30/0 in 1:37; cleanup passed. | None inside the focused gate. |
| Dedicated UVM 2020 lane | Workflow-level pull-request CI pass; local pending | Run 31346076613 concluded successfully for source `b09ff3e78f97e928907b8f2929bf8bacab6b16bd` through synthetic merge `cda98bba177663b2df45745d2e946ddf0e274d73`; the aggregate includes the configured current `uvm2020` job, but connector pagination prevents job-level claims. | Obtain accepted local execution after the `ENOSPC` blocker is removed. |
| Broad distribution checks | Pass | All five exact-head `dist-vlt-0` jobs passed in both 46-job matrices. | Preserve current evidence. |
| Broad recovered shards | Pass | All 25 jobs that were red on earlier heads recovered on both exact-head events. | Preserve current evidence. |
| Ubuntu 22 broad UVM tests | Pass | Exact-head matrices include the corrected teardown path; on each event, the dedicated UVM job passed one 1,000-phase teardown stress run (`phases=1000`, `winners=1000`, `cleanups=1000`). | Broader UVM program work remains separate. |
| Contributor Agreement | Pending external | Runs 31311244130 and 31311246183 require contributor action. | Human-only repository policy action; do not edit `docs/CONTRIBUTORS` as an agent. |
| Review comments | None known | No actionable review thread was found in the latest audit | Recheck before final promotion. |

The focused local proof used validation worktree head
`c1dab4a4f5961fe5e6c61ed57d539d576cecca0d` and the exact clean compiler at
`/tmp/pr41-exact-build.eR6mjg/repo/bin/verilator_bin`. The target passed 30/30
scenarios, seeded and removed 30/30 sentinels, passed cleanup, and left the
worktree clean. Driver time was 22:03; `time -p` reported 1324.11 real,
1051.40 user, and 241.91 system seconds. The compiler version was
`Verilator 5.051 devel rev vUNKNOWN-built20260809-c1dab4a4f`, and its binary
SHA-256 was
`37551f1957a2a31f5f321ad69cdb39e05e97c1f4d2583834a33528d9714302bb`.

The UVM local proof used the same validation head with compiler
`/tmp/pr41-coroutine-return.JfE1Cy/verilator_bin_fixed`, version
`Verilator 5.051 devel rev vUNKNOWN-built20260809-fa6fd2c68 (mod)`, and binary
SHA-256
`e52a7a32fe54127f6a4a37cb315bfd2d1e6b1c998d2180184f02c2b357073e62`.
All 20 tests passed under `vlt`; symlink preflight passed, 20/20 sentinels were
removed, and cleanup passed. Driver time was 80:15; external timing reported
4819.25 real, 3761.18 user, and 998.74 system seconds.

In the historical workflow snapshot, duplicate pre-fix push and pull-request
runs completed with three observed technical cause classes--missing SPDX
headers, a stale generated golden, and Ubuntu 22 teardown corruption--plus two
Contributor Agreement jobs. The exact-head matrices recovered all 25 formerly
red shards and all five `dist-vlt-0` jobs; the current focused lane and
historical 20-test lane passed on both events. Current 27-test workflow-level
pull-request CI passed at source
`b09ff3e78f97e928907b8f2929bf8bacab6b16bd` through synthetic merge
`cda98bba177663b2df45745d2e946ddf0e274d73`; local execution remains pending
because of `ENOSPC`. Connector pagination prevents a job-level result claim.
The remaining contributor action is independent.

### Focused named-disable support envelope

| Form | Current disposition |
|---|---|
| Scalar hierarchical module paths and scalar class-object receivers | Supported by the focused implementation and positive regression. |
| Ordinary, pure-virtual, and parameterized virtual class task families | Supported, including base- and derived-typed receiver cancellation. |
| Interface-class task disable through an interface-class receiver | Explicitly unsupported; the 15-test lane includes the expected-diagnostic regression. |
| Generate-scope paths and instance/cell-array paths | Pre-existing unsupported hierarchy forms; not claimed by PR #41. |

This envelope is a focused compiler/runtime statement. It neither advances nor
redefines the broader 0/21 program denominator.

## Ubuntu 22 defect investigation

| Investigation item | Bar | Result |
|---|---:|---|
| First bad commit | `[##########]` Complete | `138f2c97` is the first semantic commit after known-green `a2693ecc`. |
| Exact environment | `[##########]` Complete | Persistent Ubuntu 22.04 Jammy rootfs, glibc 2.35, GCC 11.4, gdb, build tools. |
| Native Ubuntu 24 reproduction | `[##########]` Complete | Full factory passes; explicit ASan run is clean with leak detection disabled. |
| Constant-false wait reducer on Jammy | `[##########]` Complete | Passes, exit 0. |
| Nested process-kill/wait-zero reducer on Jammy | `[##########]` Complete | Passes, exit 0. |
| Process tree/RNG-context reducer on Jammy | `[##########]` Complete | Passes, exit 0. |
| Full UVM reproduction on Jammy | `[##########]` Complete before fix | A sliced GCC 11 build prints the factory success sentinel, zero UVM errors/fatals, and `$finish`, then glibc 2.35 aborts during model teardown. |
| Abort backtrace and ownership proof | `[##########]` Complete | GDB and ASan trace the failure to a lost `VlProcessRef` owner: two live references share a control block reporting `use_count == 1`; child destruction frees the parent before the saved process wrapper releases it. |
| Minimal failing phase-teardown reduction | `[##########]` Complete | `t_process_phase_teardown` recreates the package NBA waits, detached phase worker, saved process wrapper, nested `join_any`/kill, constant-false wait, and final model teardown over 1,000 phases. |
| Permanent root fix | `[##########]` Complete locally | `VlForever` held a `VlProcessRef` in an awaiter whose `await_suspend()` destroys its own coroutine frame; GCC 11 undercounted/released that nontrivial owner during self-destruction. It now retains only a non-owning `VlProcess*` used before `coro.destroy()`; the enclosing live owner guarantees lifetime to that point. Post-fix GDB reports the required `use_count == 2`. |
| Exact Jammy A/B regression | `[##########]` Complete | Pre-fix GCC 11 normal and ASan builds reproduce allocator/UAF failures; the minimal fix passes both with the exact sentinel and no ASan diagnostic. |
| Focused native validation | `[##########]` Complete | The 1,000-phase regression, process kill-self, kill/wait-zero, scheduler wait-zero, and process-task tests pass; the new regression simulates in about 8 ms. |
| Post-fix full UVM validation | `[##########]` Complete | The rebuilt full factory test prints `UVM FACTORY BASIC PASSED`, zero UVM errors/fatals, and `$finish`, then exits 0 under Jammy GCC 11/glibc 2.35 with no allocator abort. |
| Supported-host CI validation | `[##########]` Complete for focused PR scope | Push and PR `build-test` each passed 46/46; all 25 former-red shards recovered and all five `dist-vlt-0` jobs passed. |

## Test and corpus evidence

| Corpus | Bar | Exact state | What it proves | What it does not prove |
|---|---:|---:|---|---|
| L0 reduced SystemVerilog | `[#########-]` 94/102, 92.2% | 94 pass, 8 blocked | Selected language compatibility around known UVM dependencies | Complete IEEE 1800 parity |
| L1 minimal UVM | `[##########]` 6/6, 100% | Six accepted local tests | Package smoke, factory, phasing, VIF/config slices | Full UVM 1800.2 API or integrated environments |
| Mixed corpus | `[#########-]` 100/115, 87.0% | 100 pass, 8 blocked, 7 pending | Reproducible selected compatibility evidence | Full-program completion |
| Current focused named-disable lane | Local and exact-head CI pass, 15 tests x 2 scenarios | Local, push CI, and PR CI passed 30/30; cleanup passed | Ordered focused membership, positive scalar/class cases, explicit interface-class diagnostic, and cleanup contract | Complete IEEE/UVM support outside the focused envelope |
| Current expanded lane | Workflow-level pull-request CI pass; local pending | Run 31346076613 passed source `b09ff3e78f97e928907b8f2929bf8bacab6b16bd` through synthetic merge `cda98bba177663b2df45745d2e946ddf0e274d73`; no job metadata is claimed | Ordered Makefile/tracker membership plus workflow-level execution of the configured lane | Accepted local execution, direct numeric-path conformance, or broader-program closure |
| Historical expanded lanes | 20/20 and 15/15 accepted at recorded revisions | Historical local and canonical CI passes | Older lane contracts and cleanup/fanout invariants at those revisions | Current 27-test or exact-head closure |
| Phase-teardown stress | `[##########]` Local, exact Jammy A/B, and exact-head CI pass | 1,000 phase graphs pass natively and under GCC 11 normal/ASan; each UVM CI job passed one 1,000-phase run with `winners=1000` and `cleanups=1000` | The isolated process/coroutine lifetime defect and its teardown path | Broader UVM program completion |

The eight blocked L0 entries remain open:

| Test | Block | Open action |
|---|---|---|
| `t_class_dead_varscope_uaf` | Missing debug Verilator/tooling in frozen local environment | Build the debug toolchain and execute; do not count environment classification as semantic pass. |
| `t_constraint_global_nested_member` | No constraint solver in frozen environment | Provide supported solver and execute. |
| `t_constraint_global_randMode` | No constraint solver | Provide solver and execute. |
| `t_constraint_global_randmode_subobj` | No constraint solver | Provide solver and execute. |
| `t_randomize` | No constraint solver | Provide solver and execute. |
| `t_randomize_class_inherit_size_foreach` | No constraint solver | Provide solver and execute. |
| `t_randomize_shift_distribution` | No constraint solver | Provide solver and execute. |
| `t_randomize_std_param_extends` | No constraint solver | Provide solver and execute. |

## Historical local-only references

These paths are named by older planning records but are not present in this
checkout. They are not current evidence or recoverable-work claims. Restore
only from provenance that can be reviewed, run, tracked, and promoted:

| Area | Local artifacts | Current value | Open decision/work |
|---|---|---|---|
| Broad roadmap | `ROADMAP.md`, `SUPPORT_MATRIX.md`, `roadmap-tracker.yaml` | Present as a dated pre-PR planning snapshot, not canonical current status. | Retain the historical banner and reconcile only through the canonical tracker. |
| Config object | `t_uvm_config_db_basic*` | Absent; older records describe a typed config object prototype. | Recreate only if unique coverage is still required by M07. |
| Config DB VIF | `t_uvm_config_db_vif*` | Absent; older records describe a live VIF mutation prototype. | Compare the description with the canonical VIF/clocking test before recreating. |
| Resource DB | `t_uvm_resource_db_basic*` | Absent; older records describe wildcard, override, and scope checks. | Implement fresh canonical resource precedence/scope coverage. |
| Factory | `t_uvm_factory_basic*` | Absent; older records describe factory assertions. | Compare against the canonical factory test and add only missing coverage. |
| Helpers and issue comments | `run_logged.sh`, `run_c1_class_core.sh`, `github_issues/` | Absent historical references. | Do not treat them as proof; recover only with verifiable provenance. |

## Tracker/modeling defects

| Defect | Impact | Required correction |
|---|---|---|
| Mixed `M0-M17` and `M00-M19` namespaces | Readers can mistake dependency order for public completion IDs. | Preserve a documented crosswalk and use only `M00-M19` for formal progress. |
| C01 wording overclaims current package artifact | Packed/normalized UVM is not proof of an unmodified upstream tree. | Add true upstream-source proof or narrow the criterion title. |
| C06 is coupled to APB through broad M06 | Direct clocking evidence cannot close independently. | Split direct VIF clocking from APB integration gates. |
| C10-C12 share one RAL gate | Frontdoor, predictor, and built-in smoke progress is unmeasurable separately. | Split M13 into distinct frontdoor, predictor, reset, access, and bit-bash gates. |
| C19-C21 lack direct atomic gates | Packaging prerequisites create misleading nonzero readiness bars. | Add dedicated diagnostics, selection, nightly/replay, and artifact gates. |
| Some issue bodies retain 0% from 2026-07-03 | Public GitHub state contradicts current tracker evidence. | Update issue bodies/comments from checker-derived values. |
| Historical `golden_revision`/workflow fields are stale | Evidence can appear unpublished or still running. | Update only after new branch head and CI run are authoritative. |
| M07 is one broad gate | Config object, resource DB, components, and CI cannot progress independently. | Split into config-object, resource precedence/scope, component-flow, and canonical-CI gates. |

## Remaining capability sequence

This is the current dependency-aware order, not a promise that only one item
can run at a time:

1. Merge-ready PR #41: Ubuntu 22 root fix, golden, regression, CI, human DCO.
1. M07 config/resource/component acceptance and M05 class/static cleanup.
1. M02/M03 semantic/API inventories and explicit diagnostics.
1. M08 TLM and sequence handshake.
1. M09 constrained-random sequence items with solver/replay.
1. M11 APB agent, using the completed VIF/config/TLM/sequence layers.
1. M12 AXI-lite agent.
1. M13 RAL frontdoor/predictor/built-in smokes.
1. M10 coverage and M15 SVA, integrated into both protocol agents.
1. M14 C reference path and accepted VPI/backdoor strategy.
1. M16 synthetic SoC with reset/CSR/DMA/IRQ/memory/multi-agent traffic.
1. M17 nightly, selection, documentation, diagnostics, performance, and
   reproducibility closure.
1. M18 advanced parity dispositions and M19 claim/issue hygiene.
1. Requirement-by-requirement final audit proving all 21 criteria.

## Update contract

Update this file whenever any of these changes:

- a tracker gate or criterion changes state;
- a GitHub issue/PR/check changes authoritative status;
- a new test, blocker, limitation, or evidence record is accepted;
- an estimate materially changes because a root cause or dependency is found;
- a local-only artifact is promoted, superseded, or rejected.

Every update must:

- rerun `check_tracker.py`;
- distinguish direct feature proof from prerequisite-gate readiness;
- keep blocked and skipped tests in their denominators;
- name the evidence or open proof for every changed row;
- preserve the 21 criteria, 20 milestones, 46 gates, 40 public issues, and
  broader competitive claim scope;
- never replace an honest incomplete state with a narrower definition of done.
