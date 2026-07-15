<!-- DESCRIPTION: Verilator: UVM 2020.3.1 regression evidence matrix
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020.3.1 evidence matrix

| Evidence ID | Issue | Proof | Expected evidence | Local | CI |
|---|---:|---|---|---|---|
| HARNESS-FANOUT-0001 | #21, #39 | Named lane uses one test process and one generated-build job | `--jobs=1`, `--driver-build-jobs=1`, `--build-jobs 1`, `--output-groups 6` | Pass: three 3/0 runs plus parent-jobserver probe | Pending |
| HARNESS-CLEAN-0001 | #21, #39 | Lane removes its complete suffixed object directory before every attempt | Planted `interrupted.gch` files are absent after a passing run | Pass: all three target-seeded sentinels removed | Pending; target seeds and asserts all three |
| UVM-PKG-NODPI-0001 | #21, #39 | Vendored concatenated UVM 2020.3.1 no-DPI package hello | `UVM TEST PASSED`, `Self PASSED`, exit 0 | Pass: expected warnings observed | Pending |
| UVM-PKG-DPI-0001 | #21 | Vendored concatenated UVM 2020.3.1 DPI package hello | `UVM TEST PASSED`, `Self PASSED`, exit 0 | Pass | Pending |
| UVM-DPI-HDL-0001 | #21 | UVM 2020.3.1 DPI HDL API regression | Golden output match, `Self PASSED`, exit 0 | Pass | Pending |
| HARNESS-DEFAULT-0001 | #21, #39 | Omit new options | Existing automatic fanout and object reuse remain selected | Pass: two runs; `-j 9`; sentinel retained | Not separately validated |

## Local execution

| Run | Command or check | Result |
|---|---|---|
| Initial lane | `make -C test_regress uvm2020` | Passed 3, failed 0, 4:42 |
| Interrupted-run recovery | Plant `interrupted.gch`; rerun named lane; assert it is absent | Passed 3, failed 0, 4:41; sentinel removed |
| Integrated self-check | `make -j8 -C test_regress uvm2020`; target seeds and asserts all three directories | Passed 3, failed 0, 4:44; all sentinels removed; cap remained one |
| Existing defaults | Run `t_math_arith.py` twice without new options, planting a sentinel between runs | Passed twice; automatic `-j 9`; sentinel retained |
| Parent jobserver | Invoke capped driver from `make -j8` | Passed; generated gmake command remained `make -j 1` |
| Static | Python compile, Bash syntax, YAML parse, `git diff --check`, invalid-job and fail-fast sentinel probes | Pass |

Base revision: `f82f59a0246f7e62f2f3a237446fdf10788cd09f`.
Environment: Ubuntu 24.04.3 LTS, GCC 13.3.0, Python 3.12.13,
Verilator 5.051 devel. See `PLAN.md` for the local multiprocessing caveat.

## Current classification

- Package and no-DPI smoke: local execution passed; draft-PR CI pending.
- Full UVM package/API support: not claimed.
- No-DPI parity with DPI: not claimed; the boundary in `PLAN.md` remains a
  known support-envelope constraint.
- CI promotion: the named suite is configured; its first draft-PR run is
  pending.
