<!-- DESCRIPTION: Verilator: UVM 2020.3.1 regression lane plan
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020.3.1 regression plan

This plan tracks one resource-capped regression lane for the vendored,
concatenated UVM 2020.3.1 package. It advances issue #21 package-elaboration
smoke and issue #39 `UVM_NO_DPI` command-flow evidence. The current local
expansion also closes the tracker gates for issue #5 UVM phasing/process
semantics and issue #7 config-DB virtual-interface/clocking flow. It does not
establish complete UVM 2020 or IEEE 1800.2 parity.

The package snapshots under `test_regress/t/uvm/` are produced by
`nodist/uvm_pkg_packer`. The packer concatenates selected upstream files,
mechanically normalizes the result, removes selected directives and preamble,
and stops at `endpackage`. This lane validates that checked-in artifact; it
does not establish semantic equivalence with, or a byte-for-byte copy of, the
upstream `uvm_pkg.sv` source tree.

## Progress accounting

Progress is reported against five independent denominators. They must not be
combined into one percentage:

| Metric | Denominator | Completion rule |
|---|---:|---|
| Program exit criteria | `C01` through `C21` (21) | A criterion counts only when its status is `pass` and every referenced public capability milestone has exited. |
| Public capability milestones | `M00` through `M19` (20) | A milestone exits only when every required gate has accepted evidence. |
| Atomic milestone gates | 46 required gates | Engineering progress counts each required gate with accepted evidence; this diagnostic does not substitute for milestone exits. |
| Pull request #41 lane evidence | 11 required proof environments | Five evidence IDs require local and CI proof; `HARNESS-DEFAULT-0001` requires local proof only. Six local proofs pass and five CI proofs are pending: 6/11, or 54.5%. |
| Test corpora | Per-corpus planned-test count | Report implementation, execution, pass, and verified rates separately as described below. |

Full-program `C01`-`C21` completion cannot be inferred from a lane evidence
rate or from any corpus pass rate.

The unpadded `M0` through `M17` identifiers in the Library master plan are an
implementation dependency order, not another completion denominator. Their
order is:

1. `M0` baseline/dashboard;
2. `M1` packages, macros, and source locations;
3. `M2` scheduler, processes, `$finish`, `wait`, and `fork`;
4. `M3` classes, factory, and static initialization;
5. `M4` interfaces, virtual interfaces, and clocking blocks;
6. `M5` configuration and resource databases;
7. `M6` components, build/connect, and reporting;
8. `M7` TLM;
9. `M8` sequences, sequencers, and drivers;
10. `M9` constrained randomization;
11. `M10` APB agent;
12. `M11` AXI-lite agent;
13. `M12` RAL frontdoor and predictor;
14. `M13` functional coverage, reporting, and merge;
15. `M14` SVA profile;
16. `M15` DPI, VPI, and backdoor;
17. `M16` synthetic SoC; and
18. `M17` packaging, documentation, and performance.

`tracker.yaml` owns atomic statuses and evidence references. Its checker
derives all roll-ups so documentation does not become a second source of
truth:

```sh
python3 nodist/uvm2020_plan/check_tracker.py
```

The current checker-derived snapshot is:

```text
program criteria: 0/21 (0.0%)
public milestone exits: 1/20 (5.0%)
atomic milestone gates: 22/46 (47.8%)
PR #41 lane evidence: 6/11 (54.5%)
mixed corpus: planned=108 implemented=108 executed=100 passed=100 failed=0 blocked=8
mixed corpus rates: execution=92.6% pass/executed=100.0% verified=92.6%
issue #5 mapped gates: 4/6 (66.7%)
issue #7 mapped gates: 3/4 (75.0%)
issue #21 mapped gates: 4/6 (66.7%)
issue #39 mapped gates: 4/9 (44.4%)
```

The mixed corpus consists of 102 L0 reduced-language tests and six minimal
UVM tests at L1. One hundred tests have accepted passing evidence. Eight
frozen-corpus entries are blocked: one by the missing local debug-tool build
and seven by the absence of a constraint solver. Blocked entries remain in the
denominator and do not count as executed. This is a compatibility inventory,
not an IEEE or UVM conformance rate. Public milestone `M00` has exited. `M04`
still requires explicit event-region and RTL fast-path performance closure;
`M06` still requires APB setup/access proof. No full-program criterion has yet
cleared all of its public milestone dependencies.

## Lane contract

Run the named lane from the repository root:

```sh
make -C test_regress uvm2020
```

The current target runs nine reduced scheduler/process/interface tests and
six UVM package/API tests:

```sh
cd test_regress
python3 driver.py --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --driver-clean-before-seed=interrupted.gch \
  --obj-suffix=-uvm2020 --vlt \
  t/t_uvm_lrm_sched_wait_zero.py \
  t/t_uvm_lrm_process_kill_tree.py \
  t/t_uvm_lrm_process_kill_self_tree.py \
  t/t_uvm_lrm_process_kill_self_zero.py \
  t/t_uvm_lrm_process_kill_function.py \
  t/t_uvm_lrm_process_kill_wait_zero.py \
  t/t_timing_finish.py \
  t/t_finish_stops_nonfinal.py \
  t/t_clocking_virtual.py \
  t/t_uvm_core_factory_basic.py \
  t/t_uvm_config_vif_clocking.py \
  t/t_uvm_core_phasing.py \
  t/t_uvm_hello_all_v2020_3_1_nodpi.py \
  t/t_uvm_hello_all_v2020_3_1_dpi.py \
  t/t_uvm_dpi_v2020_3_1.py
```

The child regression process plants `interrupted.gch` in each dedicated
object directory immediately before that test is cleaned. It then atomically
renames the complete directory to a process- and time-unique quarantine,
creates the active directory, asserts that the active directory is empty, and
removes the quarantine. The current target therefore creates and removes 15
sentinels without an external pre-seeding race. After the harness returns, a
fail-fast shell loop independently asserts that all 15 sentinel paths are
absent and prints `uvm2020: stale-artifact cleanup PASSED`. Thus every lane
execution, including the first execution in a clean checkout, exercises the
recovery policy rather than relying on pre-existing workspace state.

The lane has the following invariants:

- Test-process fanout is one.
- Verilator and generated C++ build fanout is one.
- An explicit driver build cap discards inherited GNU Make jobserver metadata,
  so a parallel parent `make` cannot enlarge the lane's build fanout.
- `test.build_jobs_groups` selects `--output-groups 6` at that build cap.
- Every test uses a dedicated `-uvm2020` object-directory suffix.
- The complete per-test object directory is atomically quarantined before each
  attempt, and the new active directory must be empty. A cleanup error fails
  the attempt instead of allowing possible stale object or PCH reuse.
- Every pre-existing object-path component is rejected if it is a symlink.
  Seed creation also rejects a pre-existing symlinked filename and uses
  `O_NOFOLLOW` where the host provides it; the negative probes preserve both
  tested external targets. This is not a claim of resistance to adversarial
  concurrent path swaps or hard links. The postcheck treats dangling symlinks
  as surviving sentinels.
- `--driver-clean-before-seed` requires `--driver-clean-before` and accepts a
  basename only; it is a lane self-test hook, not a default policy change.
- Without the new `--driver-*` options, the regression driver's existing
  automatic build fanout and object reuse are unchanged.

The `uvm2020` suite in `ci/ci-script.bash` runs the same Make target. The suite
is an Ubuntu GCC entry in the normal `build-test` workflow, which connects the
proof to the repository's built-checkout regression path.

The current 15-test target passed locally, including all 15 post-run sentinel
assertions, in 14:27. Canonical CI is still pending. The PR #41 metric
deliberately retains its original three-test proof boundary and therefore
remains 6/11: expanding the local target does not retroactively add or replace
the five required CI proof environments.

## Frozen repo-native compatibility corpus

`baseline-tests.txt` freezes a 72-test, repository-native compatibility
corpus. The first three entries are the UVM 2020.3.1 package/DPI tests; the
remaining 69 are reduced tests for language constructs exercised by UVM. The
manifest is deliberately frozen, so adding a new test does not silently change
the denominator.

The executable helper validates that all 72 entries are unique, existing
Python tests expressed as repository-relative paths. It exposes three
selections:

| Selection | Tests | Contents |
|---|---:|---|
| `quick` | 8 | Three package/DPI tests plus five explicit reduced UVM tests |
| `reduced` | 69 | All reduced compatibility tests, without the package tests |
| `full` | 72 | The complete frozen corpus |

Reproduce the manifest and selections from any working directory:

```sh
nodist/uvm2020_plan/baseline_runner.py validate
nodist/uvm2020_plan/baseline_runner.py list quick
nodist/uvm2020_plan/baseline_runner.py list reduced
nodist/uvm2020_plan/baseline_runner.py list full
```

Run a selection with one test process, one generated-build job, complete
pre-run object-directory cleanup, and an isolated object suffix:

```sh
nodist/uvm2020_plan/baseline_runner.py run quick
nodist/uvm2020_plan/baseline_runner.py run reduced
nodist/uvm2020_plan/baseline_runner.py run full
```

The manifest validation passed with counts 8, 69, and 72. Within the complete
capped and clean run, the eight quick entries passed 8/8, the package portion
passed 3/3, and the reduced portion produced 61 passes, one environment
failure, and seven dependency skips. The resulting full classification is 64
pass, one environment-blocked entry, and seven dependency-blocked entries in
9:44. It
is a complete disposition baseline, not a 72/72 semantic-pass claim.

Corpus metrics remain separate from criteria, milestone, and lane-evidence
progress:

- implementation rate is implemented tests divided by planned tests;
- execution rate is executed tests divided by planned tests;
- pass rate is passing tests divided by executed tests; and
- verified rate is passing tests divided by planned tests.

This corpus measures only the checked-in Verilator compatibility surface. It
does not prove unmodified upstream Accellera UVM, IEEE 1800.2 compliance, or
the historical issue-ledger denominator, none of which is present in this
checkout.

## DPI boundary

The no-DPI snapshot defines `UVM_NO_DPI`, which selects
`UVM_HDL_NO_DPI`, `UVM_REGEX_NO_DPI`, and `UVM_CMDLINE_NO_DPI` behavior.
Consequently, a passing no-DPI hello test proves package elaboration and a
basic `run_test` flow only. It does not prove the following capabilities:

- HDL backdoor check, read, deposit, force, or release;
- C/C++ reference-model or other DPI integrations;
- full regular-expression or command-line helper behavior; or
- parity with the companion DPI smoke and HDL-DPI API test.

The no-DPI runtime warnings `NO_DPI_USED` and `NO_VISIT_CHECK` are expected.
The DPI hello and HDL-DPI API tests remain in the lane so both sides of this
boundary stay visible.

## Reproduction protocol

From a fresh checkout with the documented build dependencies installed:

```sh
autoconf
./configure --enable-longtests --enable-ccwarn
make -j2
make -C test_regress uvm2020
```

The named target performs its 15-directory child-local sentinel setup and
assertions automatically. It must report the expected test pass markers and
the cleanup pass marker, then exit zero. Repeating the same command
additionally proves that artifacts left by a prior completed or interrupted
invocation cannot be reused by the next attempt.

## Reduced-test validation

The constant-false wait reduction was first run against the pre-fix runtime.
It failed semantically because the nested class-task call returned through
`wait (0)` and reached the caller's `$stop`. After permanent suspension was
propagated through nested coroutine call frames, the same capped, clean command
passed one test in 0:06:

```sh
python3 test_regress/t/t_uvm_lrm_sched_wait_zero.py \
  --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-uvm-progress --vlt
```

A batch containing the new reduction and 11 scheduler neighbors then passed
12/12 in 0:20:

```sh
cd test_regress
python3 driver.py --jobs=4 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-uvm-wait-neighbors --vlt \
  t/t_uvm_lrm_sched_wait_zero.py \
  t/t_wait.py \
  t/t_wait_const.py \
  t/t_wait_fork.py \
  t/t_timing_wait1.py \
  t/t_timing_wait2.py \
  t/t_timing_wait3.py \
  t/t_fork_join_none_wait_ev.py \
  t/t_fork_join_none_virtual.py \
  t/t_interface_virtual_func_wait.py \
  t/t_timing_finish3.py \
  t/t_finish_stops_nonfinal.py
```

A separate first-blocker audit passed four existing tests covering `$finish`
and virtual clocking in 0:06:

```sh
cd test_regress
python3 driver.py --jobs=4 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-uvm-first-blockers --vlt \
  t/t_timing_finish.py \
  t/t_finish_stops_nonfinal.py \
  t/t_timing_finish3.py \
  t/t_clocking_virtual.py
```

The descendant-process reduction also demonstrated a semantic red/green
transition. Before recursive disable and parent linkage, killing the parent
allowed a child side effect to run. After the fix, the same reduction passed
1/1 in 0:06:

```sh
python3 test_regress/t/t_uvm_lrm_process_kill_tree.py \
  --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-killtree-fixed --vlt
```

Four additional reductions now cover self-kill with descendants, self-kill at
zero delay, cooperative unwind from both void and value-returning functions,
and `WAITING` status before recursively killing a process suspended in
`wait (0)`. Together with the descendant reduction, all five are selected by
the named lane. The function and wait-zero focused runs each passed 1/1. A
final boundary slice containing the function, wait-zero-kill, and
constant-false-wait reductions passed 3/3 in 0:19.

A targeted post-review boundary run passed 2/2 in 0:16. It verifies that a
synchronous recursive-kill callback restores the caller's process context
(including per-process RNG state) and that kill unwinds through separate,
non-inlined void and value-returning class functions. It also verifies that a
synthetic C++ output for a SystemVerilog function return is staged until the
post-call killed check: assignment, condition, and tail side effects are
suppressed after self-kill, while a real `ref` write performed before the kill
remains visible. The focused function reduction passed 1/1 in 0:07. Before
return staging, its direct-assignment case was red because the target changed
before the cancellation guard. Before the context restore, the RNG reduction
was also red because the killer process state was not advanced. Both causal
red results are retained in `tracker.yaml`.

The first full-lane integration run after return staging exposed one additional
compile-time red in the vendored UVM package: a generated `goto` jumped past
initialization of the new non-trivial return temporary in
`uvm_reg_frontdoor::atomic_unlock`. The fix reuses Verilator's existing jump
block pattern by wrapping the temporary, redirected call, killed check, and
commit in a nested C++ local scope before the outer label. The exact factory
reproducer then passed 1/1 in 2:24, and generated C++ inspection confirmed the
nested block. The failed integration attempt is not counted as an accepted
lane result.

A final 28-test process, named-disable, and fork-neighbor sweep produced 25
passes, zero failures, and three constraint-solver skips in 2:39 under one
test process and one generated-build job:

```sh
cd test_regress
python3 driver.py --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-kill-neighbors-final --vlt \
  t/t_process*.py \
  t/t_disable_fork1.py \
  t/t_disable_fork2.py \
  t/t_disable_fork2_split.py \
  t/t_disable_fork3.py \
  t/t_disable_fork_nested.py \
  t/t_disable_task_by_name.py \
  t/t_disable_task_join.py \
  t/t_disable_task_simple.py
```

The no-timing companion also passed 1/1:

```sh
python3 test_regress/t/t_process_notiming.py \
  --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-killtree-notiming --vlt
```

The expanded UVM 2020.3.1 no-DPI factory test passed 1/1 in 2:22 with
type-based and name-based override and creation checks:

```sh
python3 test_regress/t/t_uvm_core_factory_basic.py \
  --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-uvm-factory-expanded --vlt
```

The reviewed UVM virtual-interface test passed 1/1 in 3:01. It independently
propagates typed driver and monitor modports through `uvm_config_db`, drives
three exact values through an output clocking block, and observes the initial,
three transfer, and deasserted values through a `#1step` input clocking block.
The UVM report server recorded zero errors and zero fatals.

The strengthened UVM phasing test passed 1/1 in 2:35 from an isolated fresh
object tree. It observes build, connect, end-of-elaboration,
start-of-simulation, run, extract, check, report, and final order; the run
ready-to-end followed by ended callbacks; an objection from time 0 through time 10;
and a live nested background descendant. Advancing to time 40 proves the
descendant tree was killed and neither its heartbeat nor delayed side effect
survived phase cleanup. The report server again recorded zero errors/fatals.

A combined 37-test neighbor sweep covered 28 process/fork/named-disable tests
and nine virtual-interface/clocking tests. It passed 34, failed zero, and
skipped three constraint-solver-dependent process-random tests in 4:12 with
test/build fanout capped at 1/1.

The exact nine-test VIF/clocking selection was:

```sh
cd test_regress
python3 driver.py --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-uvm-new-neighbors --vlt \
  t/t_clocking_inout.py \
  t/t_clocking_sched_timing.py \
  t/t_clocking_virtual.py \
  t/t_interface_modport.py \
  t/t_interface_virtual_func_wait.py \
  t/t_interface_virtual_modport_sel.py \
  t/t_interface_virtual_sub_iface.py \
  t/t_interface_virtual_timing.py \
  t/t_virtual_interface_member_trigger.py
```

All nine passed within the combined result. They close the M06 sub-interface
and member-trigger gate in addition to the reduced-clocking and UVM typed-VIF
gates. M06 remains in progress because issue #7 also requires APB setup/access
cycles through protocol drivers and monitors. M04 remains in progress because
issue #5 also requires explicit event-region closure and reproducible proof
that the RTL fast path retains its performance. Criteria `C04`, `C05`, and
`C06` therefore retain their still-open milestone dependencies. `M00` remains
supported by the source build, tracker and manifest checks, full-baseline
dispositions, and reproducible dashboard.

## Validation record

### Original pull request evidence boundary

This subsection applies to the original three-test pull request #41 lane. It
supplies six accepted local proof environments out of the lane's 11 required
environments. Later local expansion does not change that denominator or stand
in for the five pending canonical-CI proofs.

Validation was run on 2026-07-14 (America/Los_Angeles) from a fresh clone based
on `f82f59a0246f7e62f2f3a237446fdf10788cd09f`, plus this change. The host was
Ubuntu 24.04.3 LTS with GCC 13.3.0 and Python 3.12.13; the locally built tool
reported `Verilator 5.051 devel`.

The initial named-lane invocation passed all three tests:

```text
==TESTS DONE, PASSED: Passed 3  Failed 0  Time 4:42
```

The command lines contained `--build-jobs 1 --output-groups 6`. Both hello
tests printed `UVM TEST PASSED` and `Self PASSED`; the no-DPI test also printed
the expected `NO_DPI_USED` and `NO_VISIT_CHECK` warnings. The HDL-DPI API test
matched its golden output and printed `Self PASSED`.

The representative stale-artifact protocol then passed the lane again in
4:41, with three passes and zero failures, and `interrupted.gch` was absent
afterward. A separate default-policy check ran `t_math_arith.py` twice without
any explicit driver fanout or cleanup option. Both attempts passed, automatic
fanout remained nine on this host, and a planted `default-reuse-sentinel.o`
survived the second run. This confirms that object reuse remains the default.

After the sentinel setup and assertion were integrated into the target, a
third validation invoked `make -j8 -C test_regress uvm2020`. It passed all
three tests in 4:44, removed the sentinels from all three object directories,
and completed the target's post-run assertion. The UVM commands still used
`--build-jobs 1 --output-groups 6`, confirming that the explicit cap was not
enlarged by the inherited eight-slot jobserver. A separate fast
`t_math_arith.py` parent-jobserver probe also generated `make -j 1` and passed.

Static checks also passed:

```sh
python3 -m py_compile test_regress/driver.py
python3 -m py_compile nodist/uvm2020_plan/check_cleanup_safety.py
python3 -m py_compile nodist/uvm2020_plan/baseline_runner.py
python3 -m py_compile nodist/uvm2020_plan/check_tracker.py
python3 nodist/uvm2020_plan/check_cleanup_safety.py
python3 nodist/uvm2020_plan/baseline_runner.py validate
python3 nodist/uvm2020_plan/check_tracker.py --format text
bash -n ci/ci-script.bash
git diff --check
```

Both YAML files parsed with PyYAML, and the driver rejected
`--driver-build-jobs=0`, a stale seed without `--driver-clean-before`, and a
seed containing path components, each with parser exit status 2. A negative
cleanup-safety regression proved that a symlinked object-directory ancestor
and a symlinked seed are rejected without modifying either external target;
it also proved the postcheck detects a dangling sentinel symlink. A separate
negative shell probe confirmed that the target's sentinel loop stops on the
first surviving file.

The local execution environment prohibits the AF_UNIX socket used by Python's
`forkserver` multiprocessing context. Local regression runs therefore used an
untracked `sitecustomize.py` shim that selected `fork`; it did not modify the
repository, test selection, commands, or build settings. The committed CI lane
uses the driver's normal `forkserver` path, and its status is tracked
separately in `MATRIX.md` and `tracker.yaml`.

### Current local expansion

Validation on 2026-07-16 used the same host compiler and the same local `fork`
shim caveat. A fresh isolated tree at revision
`703bb474d9ea45bff246fec43397cd7c7acaa0fa` completed a full optimized source
build using Autoconf 2.72, Bison 3.8.2, and Flex 2.6.4 under the temporary
`/tmp/uvm-tools` prefix. Every current focused and integrated result uses its
`vUNKNOWN-built20260716-703bb474d` compiler. A debug build was not run and
receives no credit.

The earlier evidence remains valid history: the complete optimized build
preceded the review-driven `src/V3Timing.cpp` return-staging and jump-scope
edits, after which the exact translation unit compiled and the optimized
binary relinked. The current exact-head full build supersedes the old local
missing-Flex regeneration limitation for optimized-source validation; it does
not reclassify the frozen baseline's canonical missing-debug-binary result.

The accepted pre-expansion integrated run was:

```sh
PYTHONPATH=/tmp/uvm_run_shim make -j8 -C test_regress uvm2020
```

It passed 13 tests, failed zero, completed in 8:23, kept observed test/build
fanout at 1/1 with output group 6, and removed all 13 child-local sentinels.
The target printed `uvm2020: stale-artifact cleanup PASSED`. Three earlier
13/0 semantic attempts, in 8:17, 8:11, and 8:10, deliberately received no
cleanup credit because their post-run sentinel assertions failed. Those
fail-closed results led to child-local seeding and atomic quarantine of the
complete old directory before creation and emptiness checking of the new
active directory.

Two current validation attempts inside the managed workspace received no
credit. In the first, the host restored 317 old generated files after the
harness had asserted the replacement directory empty; the restored dependency
named obsolete specialization `Tz23` while every fresh generated source named
`Tz36`. In the second, a never-before-used suffix avoided that PCH but the host
changed the freshly linked simulator from mode 0755 to 0644 before execution.
The definitive 15-test command therefore runs from an isolated `/tmp`
execution root. Its Makefile, driver, input file, and tests resolve to this
proposed tree, while every generated object/PCH/executable stays outside the
managed overlay. The lane still uses the committed fixed `-uvm2020` suffix;
no environment-specific source override was retained.

The definitive expanded run used that exact fixed target from the isolated
execution root:

```sh
cd /tmp/uvm2020-lane-703bb474-20260716a/test_regress
PYTHONPATH=/tmp/uvm_run_shim \
VERILATOR_ROOT=/tmp/verilator-head-703bb474 \
PATH=/tmp/uvm-tools/bin:$PATH \
LD_LIBRARY_PATH=/tmp/uvm-tools/lib \
make uvm2020
```

It passed all 15 tests with zero failures in 14:27. The target retained
test/build fanout at 1/1 with output group 6, removed all 15 child-local
`interrupted.gch` sentinels, and printed
`uvm2020: stale-artifact cleanup PASSED`. This integrated result includes the
new UVM config-DB virtual-interface/clocking and UVM core-phasing tests, in
addition to the nine scheduler/process/finish/clocking reductions and the four
previous UVM package/API tests.

The frozen-corpus commands are:

```sh
PYTHONPATH=/tmp/uvm_run_shim \
  nodist/uvm2020_plan/baseline_runner.py run quick
PYTHONPATH=/tmp/uvm_run_shim \
  nodist/uvm2020_plan/baseline_runner.py run full
```

The full run completed in 9:44 with 64 passes, one raw environment failure,
and seven skips. Within that result, the eight quick entries passed 8/8, the
69-test reduced portion was 61 pass, one environment failure, and seven
no-constraint-solver skips, and the three package tests passed. The raw failure,
`t_class_dead_varscope_uaf`, explicitly requests the unavailable debug binary.
A diagnostic retry using a temporary copy of the optimized binary passed 1/1,
which supports the environment-blocked classification but is not counted as a
canonical full-baseline pass. In tracker roll-ups the one environment failure
and seven dependency skips are eight blocked entries. With the six L1 UVM
tests, the current mixed corpus is 100 pass, zero semantic failures, and eight
blocked—not 72/72 semantic pass.

No expanded-lane canonical CI result is claimed. Until the
`Test | ubuntu-26.04 | gcc | uvm2020` context passes, PR #41 evidence remains
6/11 (54.5%) and the expanded lane's CI proof remains pending.

Historical `LEDGER-*` logs mentioned in the issues are not present in the
repository and are not treated as reproduced evidence here.
