<!-- DESCRIPTION: Verilator: UVM 2020.3.1 regression lane plan
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020.3.1 regression plan

This plan tracks one resource-capped regression lane for the vendored,
concatenated UVM 2020.3.1 package. It advances issue #21 package-elaboration
smoke and issue #39 `UVM_NO_DPI` command-flow evidence. It does not establish
complete UVM 2020 or IEEE 1800.2 parity.

The package snapshots under `test_regress/t/uvm/` are produced by
`nodist/uvm_pkg_packer`. The packer concatenates selected upstream files,
mechanically normalizes the result, removes selected directives and preamble,
and stops at `endpackage`. This lane validates that checked-in artifact; it
does not establish semantic equivalence with, or a byte-for-byte copy of, the
upstream `uvm_pkg.sv` source tree.

## Lane contract

Run the named lane from the repository root:

```sh
make -C test_regress uvm2020
```

The target expands to this harness invocation:

```sh
python3 driver.py --jobs=1 --driver-build-jobs=1 --driver-clean-before \
  --obj-suffix=-uvm2020 --vlt \
  t/t_uvm_hello_all_v2020_3_1_nodpi.py \
  t/t_uvm_hello_all_v2020_3_1_dpi.py \
  t/t_uvm_dpi_v2020_3_1.py
```

Before invoking the harness, the target creates each dedicated object
directory and plants an `interrupted.gch` sentinel in it. After the harness
returns, a fail-fast shell loop asserts that all three sentinels were removed
and prints `uvm2020: stale-artifact cleanup PASSED`. Thus every lane execution,
including the first execution in a clean checkout, exercises the recovery
policy rather than relying on pre-existing workspace state.

The lane has the following invariants:

- Test-process fanout is one.
- Verilator and generated C++ build fanout is one.
- An explicit driver build cap discards inherited GNU Make jobserver metadata,
  so a parallel parent `make` cannot enlarge the lane's build fanout.
- `test.build_jobs_groups` selects `--output-groups 6` at that build cap.
- Every test uses a dedicated `-uvm2020` object-directory suffix.
- The complete per-test object directory is removed before each attempt. A
  cleanup error fails the attempt instead of allowing possible stale object or
  PCH reuse.
- Without the two new `--driver-*` options, the regression driver's existing
  automatic build fanout and object reuse are unchanged.

The `uvm2020` suite in `ci/ci-script.bash` runs the same Make target. The suite
is an Ubuntu GCC entry in the normal `build-test` workflow, which connects the
proof to the repository's built-checkout regression path.

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

The named target performs its three-directory sentinel setup and assertions
automatically. It must report the expected test pass markers and the cleanup
pass marker, then exit zero. Repeating the same command additionally proves
that artifacts left by a prior completed or interrupted invocation cannot be
reused by the next attempt.

## Validation record

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
either new option. Both attempts passed, automatic fanout remained nine on
this host, and a planted `default-reuse-sentinel.o` survived the second run.
This confirms that object reuse remains the default.

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
bash -n ci/ci-script.bash
git diff --check
```

Both YAML files parsed with PyYAML, and the driver rejected
`--driver-build-jobs=0` with parser exit status 2. A negative shell probe
confirmed that the target's sentinel loop stops on the first surviving file.

The local execution environment prohibits the AF_UNIX socket used by Python's
`forkserver` multiprocessing context. Local regression runs therefore used an
untracked `sitecustomize.py` shim that selected `fork`; it did not modify the
repository, test selection, commands, or build settings. The committed CI lane
uses the driver's normal `forkserver` path, and its status is tracked
separately in `MATRIX.md` and `tracker.yaml`.

Historical `LEDGER-*` logs mentioned in the issues are not present in the
repository and are not treated as reproduced evidence here.
