<!-- DESCRIPTION: Verilator: UVM 2020.3.1 regression evidence matrix
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020.3.1 evidence matrix

The first table records the original three-test pull request #41 lane. The
current fifteen-test lane is tracked separately below because its accepted
local result does not replace the five still-pending original PR CI proofs.

| Evidence ID | Issue | Proof | Expected evidence | Local | CI |
|---|---:|---|---|---|---|
| HARNESS-FANOUT-0001 | #21, #39 | Named lane uses one test process and one generated-build job | `--jobs=1`, `--driver-build-jobs=1`, `--build-jobs 1`, `--output-groups 6` | Pass: three 3/0 runs plus parent-jobserver probe | Pending |
| HARNESS-CLEAN-0001 | #21, #39 | Lane removes its complete suffixed object directory before every attempt | Planted `interrupted.gch` files are absent after a passing run | Pass: all three original target-seeded sentinels removed | Pending; current fifteen-test CI target is tracked separately |
| UVM-PKG-NODPI-0001 | #21, #39 | Vendored concatenated UVM 2020.3.1 no-DPI package hello | `UVM TEST PASSED`, `Self PASSED`, exit 0 | Pass: expected warnings observed | Pending |
| UVM-PKG-DPI-0001 | #21 | Vendored concatenated UVM 2020.3.1 DPI package hello | `UVM TEST PASSED`, `Self PASSED`, exit 0 | Pass | Pending |
| UVM-DPI-HDL-0001 | #21 | UVM 2020.3.1 DPI HDL API regression | Golden output match, `Self PASSED`, exit 0 | Pass | Pending |
| HARNESS-DEFAULT-0001 | #21, #39 | Omit new options | Existing automatic fanout and object reuse remain selected | Pass: two runs; `-j 9`; sentinel retained | Not separately validated |

The five evidence IDs other than `HARNESS-DEFAULT-0001` each require local and
CI proof. `HARNESS-DEFAULT-0001` requires local proof only. Pull request #41
therefore has 11 required proof environments: all six local proofs pass and
the five CI proofs are pending, for 6/11 accepted (54.5%). This measures
evidence acceptance, not UVM feature completion or a test pass rate.

## Progress denominators

| Metric | Correct denominator | Current interpretation |
|---|---:|---|
| Program criteria | 21 (`C01`-`C21`) | 0/21 complete (0.0%); every criterion retains at least one open public-milestone dependency. |
| Public capability exits | 20 (`M00`-`M19`) | 1/20 exited (5.0%); `M00` has accepted evidence for every tracker gate. |
| Atomic milestone gates | 46 required gates | 22/46 pass (47.8%); this engineering diagnostic does not substitute for public milestone exits. |
| Library implementation order | None | Unpadded `M0`-`M17` is dependency-order metadata and must never be converted to a completion percentage. |
| PR #41 lane evidence | 11 required proof environments | 6 pass locally; 5 CI proofs pending; 54.5% accepted. |
| Tracker mixed corpus | 108 planned tests | 108 implemented; 100 executed/pass and 8 blocked; execution and verified 92.6%; pass/executed 100.0%. |
| Frozen compatibility selection | 72 manifest entries | All 72 received reproducible dispositions: 64 pass, one debug-build environment block, and seven no-solver skips. This is not a 72/72 semantic-pass claim. |

Mapped issue progress is also checker-derived: issue #5 is 4/6 gates (66.7%),
issue #7 is 3/4 (75.0%), issue #21 is 4/6 (66.7%), and issue #39 is 4/9
(44.4%). Open event-region/performance, APB, and canonical-CI gates remain in
their denominators.

The tracker checker computes the program, milestone, atomic-gate, PR-evidence,
and mixed-corpus metrics from atomic status and evidence records:

```sh
python3 nodist/uvm2020_plan/check_tracker.py
```

Current atomic state is intentionally non-complete: all 21 criteria retain
open milestone dependencies. `M00` has exited; `M04` retains event-region and
performance gates, and `M06` retains its APB setup/access gate. Other public
milestones remain gate-controlled by their tracker entries.

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
| Prior expanded lane | Run the thirteen-test target under `make -j8` with child-local stale seeds and atomic quarantine | Passed 13, failed 0, 8:23; 13/13 sentinels removed; fanout remained 1/1 |
| Current expanded lane | Run the exact fixed fifteen-test target from an isolated execution root with child-local stale seeds and atomic quarantine | Passed 15, failed 0, 14:27; 15/15 sentinels removed; fanout remained 1/1; stale-artifact postcheck passed |
| Exact-head optimized source build | Fully build revision `703bb474d` in an isolated source tree with the temporary Flex/Bison toolchain | Pass; every current focused/lane result uses that compiler; debug build not run |
| Cleanup symlink safety | Reject a symlinked object ancestor and seed; preserve both external targets; detect a dangling sentinel symlink | Pass |
| Static | Python compile, Bash syntax, manifest/checker validation, `git diff --check`, and three parser rejections | Pass |

Current validation base revision:
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
| Expanded local UVM lane | 15 | Pass | 15/0 in 14:27; atomic quarantine removed 15 child-local `interrupted.gch` sentinels; test/build fanout stayed 1/1; stale-artifact postcheck passed |
| Expanded CI UVM lane | 15 | Pending | No accepted workflow result |

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

- Package and no-DPI smoke: local execution passed; draft-PR CI pending.
- Full UVM package/API support: not claimed.
- No-DPI parity with DPI: not claimed; the boundary in `PLAN.md` remains a
  known support-envelope constraint.
- Reduced scheduler/process, factory, phasing, and virtual-interface evidence:
  local red/green, self-kill, wait-state, function-unwind, UVM phase cleanup,
  exact clocking samples, sub-interface/member-trigger, and neighbor runs
  passed. The resulting M04/M06 gates receive credit, but event-region,
  performance, and APB gates remain open, so no milestone exit is inferred.
- Expanded fifteen-test lane: the prior 13/0 local result remains historical;
  the exact fixed target passed 15/0 locally in 14:27 with its cleanup
  postcheck, while canonical CI remains pending.
- Frozen 72-test corpus: every entry has a reproducible disposition (64 pass,
  one environment block, seven dependency skips); this is not 72/72 semantic
  compatibility.
- CI promotion: the named suite is configured; its required PR proofs remain
  pending.
