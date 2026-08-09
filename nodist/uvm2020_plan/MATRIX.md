<!-- DESCRIPTION: Verilator: UVM 2020.3.1 regression evidence matrix
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020.3.1 evidence matrix

The first table records the original three-test pull request #41 proof
boundary. The current focused 15-test two-scenario target has passing local
evidence, and the ordered 20-test UVM target also has passing local evidence.
Both current CI proofs are pending. Older UVM lane results are retained below
as historical evidence only.

See `PROGRESS.md` for the complete requirement dashboard, progress bars, open
work, and estimates. This matrix remains the authority for accepted evidence
and claim boundaries.

| Evidence ID | Issue | Proof | Expected evidence | Historical local | Historical CI |
|---|---:|---|---|---|---|
| HARNESS-FANOUT-0001 | #21, #39 | Named lane uses one test process and one generated-build job | `--jobs=1`, `--driver-build-jobs=1`, `--build-jobs 1`, `--output-groups 6` | Pass: three 3/0 runs plus parent-jobserver probe | Pass: canonical fifteen-test job retained 1/1 fanout and output groups 6 |
| HARNESS-CLEAN-0001 | #21, #39 | Lane removes its complete suffixed object directory before every attempt | Planted `interrupted.gch` files are absent after a passing run | Pass: all three original target-seeded sentinels removed | Pass: 15/15 child-local sentinels removed; cleanup postcheck passed |
| UVM-PKG-NODPI-0001 | #21, #39 | Vendored concatenated UVM 2020.3.1 no-DPI package hello | `UVM TEST PASSED`, `Self PASSED`, exit 0 | Pass: expected warnings observed | Pass: canonical fifteen-test job 87592850312 |
| UVM-PKG-DPI-0001 | #21 | Vendored concatenated UVM 2020.3.1 DPI package hello | `UVM TEST PASSED`, `Self PASSED`, exit 0 | Pass | Pass: canonical fifteen-test job 87592850312 |
| UVM-DPI-HDL-0001 | #21 | UVM 2020.3.1 DPI HDL API regression | Golden output match, `Self PASSED`, exit 0 | Pass | Pass: canonical fifteen-test job 87592850312 |
| HARNESS-DEFAULT-0001 | #21, #39 | Omit new options | Existing automatic fanout and object reuse remain selected | Pass: two runs; `-j 9`; sentinel retained | Not separately validated |

The five evidence IDs other than `HARNESS-DEFAULT-0001` each require local and
CI proof. `HARNESS-DEFAULT-0001` requires local proof only. At the recorded
revisions, all six local and all five CI proofs were accepted, for 11/11
historical proof environments. This measures the original evidence slice, not
current 20-test validation, focused PR technical closure, UVM feature
completion, or a test pass rate.

## Current PR validation gates

These current contracts are independent of the historical 11/11 evidence
slice. Both require exact-head local and CI proof:

| Gate | Contract | Exact-head local | Exact-head CI | Claim boundary |
|---|---:|---|---|---|
| Focused named-disable/process lane | 15 ordered tests under both `vlt` and `vltmt` (30 scenario executions and cleanup sentinels) | Pass: 30/30, zero failed, 30/30 sentinels removed, cleanup passed | Pending: Ubuntu 26 GCC `named-disable` job | Compiler/runtime technical scope only. |
| UVM integration lane | 20 ordered tests under `vlt` (20 cleanup sentinels) | Pass: 20/20, zero failed, 20/20 sentinels removed, symlink preflight and cleanup passed | Pending: Ubuntu 26 GCC `uvm2020` job | Selected UVM integration evidence only. |

The focused local proof used validation head
`c1dab4a4f5961fe5e6c61ed57d539d576cecca0d` and the exact clean compiler at
`/tmp/pr41-exact-build.eR6mjg/repo/bin/verilator_bin`. The compiler version was
`Verilator 5.051 devel rev vUNKNOWN-built20260809-c1dab4a4f`, with binary
SHA-256
`37551f1957a2a31f5f321ad69cdb39e05e97c1f4d2583834a33528d9714302bb`.
Driver time was 22:03; `time -p` reported 1324.11 real, 1051.40 user, and
241.91 system seconds. The worktree remained clean.

The UVM local proof used the same validation head and compiler
`/tmp/pr41-coroutine-return.JfE1Cy/verilator_bin_fixed`, version
`Verilator 5.051 devel rev vUNKNOWN-built20260809-fa6fd2c68 (mod)`, with binary
SHA-256
`e52a7a32fe54127f6a4a37cb315bfd2d1e6b1c998d2180184f02c2b357073e62`.
Driver time was 80:15; external timing reported 4819.25 real, 3761.18 user,
and 998.74 system seconds.

Focused technical closure may be recorded only after both rows pass on the
exact source head and the required exact-head workflow checks are green. That
does not change the independent broader-program result, which remains 0/21.

### Focused named-disable support envelope

| Form | Disposition |
|---|---|
| Scalar hierarchical module paths and scalar class-object receivers | Supported in the focused implementation. |
| Ordinary, pure-virtual, and parameterized virtual class task families | Supported, including base- and derived-typed receivers. |
| Interface-class task disable through an interface-class receiver | Explicitly unsupported; the focused lane requires the stable diagnostic regression to pass. |
| Generate-scope paths and instance/cell-array paths | Pre-existing unsupported hierarchy forms; outside this PR's positive claim. |

## Progress denominators

| Metric | Correct denominator | Current interpretation |
|---|---:|---|
| Program criteria | 21 (`C01`-`C21`) | 0/21 complete (0.0%); every criterion retains at least one open public-milestone dependency. |
| Public capability exits | 20 (`M00`-`M19`) | 2/20 exited (10.0%); `M00` and `M01` have accepted evidence for every tracker gate. |
| Atomic milestone gates | 46 required gates | 24/46 pass (52.2%); this engineering diagnostic does not substitute for public milestone exits. |
| Library implementation order | None | Unpadded `M0`-`M17` is dependency-order metadata and must never be converted to a completion percentage. |
| Historical PR #41 evidence slice | 11 required proof environments | Six local and five CI proofs were accepted at their recorded revisions; this is not current-head proof. |
| Current focused lane contract | 15 tests, two scenarios | Exact ordered membership is derived from the Makefile; local passed all 30 `vlt`/`vltmt` scenario executions and cleanup, while CI is pending. |
| Current Makefile lane contract | 20 ordered tests | `check_tracker.py` derives the exact reduced-then-package order from `test_regress/Makefile`; local passed 20/20 with cleanup, while CI is pending. |
| Tracker mixed corpus | 108 planned tests | 108 implemented; 100 executed/pass and 8 blocked; execution and verified 92.6%; pass/executed 100.0%. |
| Frozen compatibility selection | 72 manifest entries | All 72 received reproducible dispositions: 64 pass, one debug-build environment block, and seven no-solver skips. This is not a 72/72 semantic-pass claim. |

Mapped issue progress is also checker-derived: issue #5 is 4/6 gates (66.7%),
issue #7 is 3/4 (75.0%), issue #21 is 5/6 (83.3%), and issue #39 is 6/9
(66.7%). Open event-region/performance, APB, broader package/API, DPI/reference,
VPI/backdoor, and performance gates remain in their denominators.

The tracker checker computes the program, milestone, atomic-gate, PR-evidence,
and mixed-corpus metrics from atomic status and evidence records:

```sh
python3 nodist/uvm2020_plan/check_tracker.py
```

Current atomic state is intentionally non-complete: all 21 criteria retain
open milestone dependencies. `M00` and `M01` have exited; `M04` retains
event-region and performance gates, and `M06` retains its APB setup/access
gate. Other public milestones remain gate-controlled by their tracker entries.

The mixed corpus inventory is 102 L0 reduced-language tests plus six L1
minimal-UVM tests. Accepted evidence covers 94/102 at L0 and 6/6 at L1; the
remaining eight L0 tests have explicit environment or dependency blocks.
Those layer rates remain compatibility evidence and do not claim conformance.

## Local execution

| Run | Command or check | Result |
|---|---|---|
| Initial lane | Historical three-test `make -C test_regress uvm2020` target | Passed 3, failed 0, 4:42 |
| Interrupted-run recovery | Plant `interrupted.gch`; rerun named lane; assert it is absent | Passed 3, failed 0, 4:41; sentinel removed |
| Integrated self-check | Historical three-test target under `make -j8`; seed and assert all three directories | Passed 3, failed 0, 4:44; all sentinels removed; cap remained one |
| Existing defaults | Run `t_math_arith.py` twice without new options, planting a sentinel between runs | Passed twice; automatic `-j 9`; sentinel retained |
| Parent jobserver | Invoke capped driver from `make -j8` | Passed; generated gmake command remained `make -j 1` |
| Constant-false wait, pre-fix | Run `t_uvm_lrm_sched_wait_zero.py` with capped clean settings | Semantic red: nested class-task caller continued and reached `$stop` |
| Constant-false wait, fixed | Repeat the same reduction after permanent suspension propagation | Passed 1, failed 0, 0:06 |
| Wait neighbors | New reduction plus 11 scheduler neighbors | Passed 12, failed 0, 0:20 |
| `$finish`/clocking audit | Three `$finish` tests plus `t_clocking_virtual.py` | Passed 4, failed 0, 0:06 |
| Descendant process kill, pre-fix | Kill parent of nested fork tree | Semantic red: child side effect ran |
| Descendant process kill, fixed | Repeat after recursive disable and parent linkage | Passed 1, failed 0, 0:06 |
| Self-kill reductions | Kill the current process with live descendants, including the zero-time path | Passed 2, failed 0 |
| Wait-zero kill status | Confirm a permanently suspended process reports `WAITING` before recursive kill | Passed 1, failed 0 |
| Function unwind | Exercise kill guards in non-coroutine void and value-returning functions | Passed 1, failed 0 |
| Caller process/RNG context, pre-fix | Synchronously resume a killed owner, then randomize in the killer | Semantic red: killer process RNG state did not advance |
| Function return commit, pre-fix | Self-kill inside a value function used by direct assignment | Semantic red: assignment target changed before the cancellation guard |
| Focused function return/ref boundary | Stage the synthetic return through the killed check, suppress later assignment/condition/tail effects, and preserve a real `ref` write made before kill | Passed 1, failed 0, 0:07 |
| Post-review kill boundaries | Restore caller process/RNG context; unwind non-inlined void/value functions; verify staged return commit and real-`ref` preservation | Passed 2, failed 0, 0:16 |
| Return-temp jump scope, pre-fix | Compile full UVM `uvm_reg_frontdoor::atomic_unlock` after return staging | Compile red: generated `goto` crossed initialization of the non-trivial return temporary |
| Return-temp jump scope, fixed | Nest the return temporary, call, killed check, and commit before the outer jump label | Factory passed 1, failed 0, 2:24; generated C++ block inspected |
| Process/fork neighbors | 28 capped, clean process, named-disable, and fork tests | Passed 25, failed 0, skipped 3, 2:39; skips require a constraint solver |
| Process no-timing | `t_process_notiming.py` | Passed 1, failed 0 |
| UVM factory | Type/name override and creation against vendored no-DPI package | Passed 1, failed 0, 2:22 |
| UVM config-DB VIF/clocking | Propagate typed driver/monitor modports and verify five exact clocking events | Passed 1, failed 0, 3:01; zero UVM errors/fatals |
| UVM core phasing | Phase order/callbacks, objection 0-10, live nested descendant, and recursive phase cleanup | Passed 1, failed 0, 2:35; ready-to-end preceded ended; zero UVM errors/fatals |
| Process/VIF neighbors | 28 process/fork/named-disable plus nine VIF/clocking tests | Passed 34, failed 0, skipped 3, 4:12; skips require a constraint solver |
| Frozen full selection | Run all 72 manifest entries with capped clean settings | Passed 64, raw failed 1, skipped 7, 9:44; all eight non-passes classified below |
| Historical thirteen-test lane | Run the thirteen-test target under `make -j8` with child-local stale seeds and atomic quarantine | Passed 13, failed 0, 8:23; 13/13 sentinels removed; fanout remained 1/1 |
| Historical fifteen-test lane | Run the then-current fixed target from an isolated execution root with child-local stale seeds and atomic quarantine | Passed 15, failed 0, 14:27; 15/15 sentinels removed; fanout remained 1/1; stale-artifact postcheck passed |
| Current focused named-disable contract | Exact clean-c1 compiler; 15 ordered tests in both `vlt` and `vltmt` with child-local stale seeds | Passed 30/30 scenarios, failed 0; driver 22:03, real 1324.11 s; seeded and removed 30/30 sentinels; cleanup passed; worktree clean; CI pending |
| Current twenty-test contract | `make -C test_regress uvm2020`; ordered `UVM2020_REDUCED_TESTS` then `UVM2020_PACKAGE_TESTS` | Passed 20/20 under `vlt`, failed 0; driver 80:15, real 4819.25 s; symlink preflight passed; seeded and removed 20/20 sentinels; cleanup passed; CI pending |
| Historical exact-head optimized source build | Fully build revision `703bb474d` in an isolated source tree with the temporary Flex/Bison toolchain | Pass for that revision; recorded focused/lane results used that compiler; debug build not run |
| Cleanup symlink safety | Reject a symlinked object ancestor and seed; preserve both external targets; detect a dangling sentinel symlink | Pass |
| Static | Python compile, Bash syntax, manifest/checker validation, `git diff --check`, and three parser rejections | Pass |

Historical validation base revision:
`703bb474d9ea45bff246fec43397cd7c7acaa0fa`.
Environment: Ubuntu 24.04.3 LTS, GCC 13.3.0, Python 3.12.13,
Verilator 5.051 devel. See `PLAN.md` for the local multiprocessing caveat.

The exact reduced-test and neighbor commands are recorded in `PLAN.md`.

## Frozen corpus and integration status

| Selection or lane | Denominator | Status | Accepted result |
|---|---:|---|---|
| Manifest validation | 72 unique existing test paths | Pass | Selection counts are quick 8, reduced 69, full 72 |
| Quick compatibility selection | 8 | Observed within full run | All eight quick entries passed; no separate standalone-run claim |
| Reduced compatibility selection | 69 | Observed within full run | 61 pass, one debug-build environment block, and seven no-solver skips |
| Full compatibility selection | 72 | Disposition complete | 64 pass; `t_class_dead_varscope_uaf` blocked because the image lacks `bin/verilator_bin_dbg` and system `FlexLexer.h`; seven randomize/constraint tests skipped because no constraint solver is available; 9:44 |
| Current Makefile UVM lane | 20 | Local pass; CI pending | 20/20 passed under `vlt`, zero failed; 20/20 sentinels removed; Ubuntu 26 GCC `uvm2020` is pending |
| Current Makefile focused lane | 15 x 2 scenarios | Local pass; CI pending | 30/30 scenarios passed with exact clean-c1 compiler, zero failed, and 30/30 sentinels were removed; Ubuntu 26 GCC `named-disable` is pending |
| Historical expanded local UVM lane | 15 | Pass | 15/0 in 14:27; atomic quarantine removed 15 child-local `interrupted.gch` sentinels; test/build fanout stayed 1/1; stale-artifact postcheck passed |
| Historical expanded CI UVM lane | 15 | Pass | 15/0 in 6:00; cleanup postcheck passed in job 87592850312 for source head `7170338f` |

Use these reproducible commands:

```sh
nodist/uvm2020_plan/baseline_runner.py validate
nodist/uvm2020_plan/baseline_runner.py list full
nodist/uvm2020_plan/baseline_runner.py run quick
nodist/uvm2020_plan/baseline_runner.py run reduced
nodist/uvm2020_plan/baseline_runner.py run full
make -C test_regress uvm2020
```

When execution evidence exists, corpus rates are calculated independently:
execution is executed/planned, pass is passed/executed, and verified is
passed/planned. These values are never substituted for `C01`-`C21`,
`M00`-`M19`, or PR evidence progress.
In particular, neither a 100% lane pass rate nor a 100% corpus pass rate would
by itself establish full-program completion.

## Current classification

- Package and no-DPI smoke: accepted historical local and dedicated draft-PR
  CI evidence exists; the current 20-test local target passed and its CI proof
  remains pending.
- Full UVM package/API support: not claimed.
- No-DPI parity with DPI: not claimed; the boundary in `PLAN.md` remains a
  known support-envelope constraint.
- Reduced scheduler/process, factory, phasing, and virtual-interface evidence:
  local red/green, self-kill, wait-state, function-unwind, UVM phase cleanup,
  exact clocking samples, sub-interface/member-trigger, and neighbor runs
  passed. The resulting M04/M06 gates receive credit, but event-region,
  performance, and APB gates remain open, so no milestone exit is inferred.
- Current focused lane: the Makefile and tracker agree on 15 ordered tests in
  two scenarios; local passed 30/30 with cleanup, and CI remains pending.
- Current expanded lane: the Makefile and tracker agree on 20 ordered tests;
  local passed 20/20 under `vlt` with cleanup, and CI remains pending. The 13/0
  and 15/0 local results and the 15/0 canonical job remain explicitly
  historical.
- Frozen 72-test corpus: every entry has a reproducible disposition (64 pass,
  one environment block, seven dependency skips); this is not 72/72 semantic
  compatibility.
- Historical CI evidence: the dedicated named suite supplied all five required
  CI proofs for the original evidence slice. Focused PR technical closure still
  requires exact-head `named-disable` and `uvm2020` CI validation; the full UVM
  program independently remains 0/21, and human review/DCO remain separate
  gates.
