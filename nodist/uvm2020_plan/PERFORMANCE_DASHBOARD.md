<!-- DESCRIPTION: Verilator: Reproducible performance collection and reporting
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM performance dashboard

`performance.py` collects checked, paired exploratory measurements and produces
JSON, Markdown and standalone HTML reports. This is development tooling for
M17 and [G-PERF](GOALS.md), which remain separate acceptance decisions. The
collector does not grant either decision or update the tracker.

The existing `.github/workflows/rtlmeter.yml`, `reusable-rtlmeter-run.yml`, and
`ci/ci-rtlmeter-report.*` provide the RTL workload/report route. Retain that
infrastructure for the separate upstream RTL baseline. Its current workflow
executes the new version and then the old version in batches. The UVM tool
adds frozen policy, paired interleaving, independent completed-work checks,
retained warmups, and paired bootstrap intervals required by G-PERF. Importing
RTLMeter data into a final combined acceptance report remains future work.

## Commands

Collection currently requires Linux `/proc`, `taskset`, and Python 3.10 or
newer. It uses only the Python standard library. Run the tool integrity checks:

```console
python3 nodist/uvm2020_plan/test_performance.py -v
```

Collect from a reviewed JSON plan into a **new** output directory:

```console
python3 nodist/uvm2020_plan/performance.py collect --plan plan.json --output results/run-001
```

Every bundle archives its collector and report implementation. Regenerate the
report from the bundle, even after moving it or removing the original model:

```console
python3 results/run-001/performance.py report results/run-001
```

Open `results/run-001/report.html`; the full values are in `report.json`.
Re-rendering identical raw records produces byte-identical reports. Use the
archived implementation when reproducing an older report. Original executable,
checker and source paths are needed to **collect again**, not to re-render.

## Frozen plan

The plan contains these required fields:

| Field | Contract |
|---|---|
| `schema_version` | `1` |
| `scope` | `exploratory`; production acceptance is unsupported |
| `cache_policy` | Explicit cache treatment, including inherited warm caches |
| `affinity` | Nonempty list of available Linux CPU IDs |
| `warmups` | At least one per variant; retained and correctness checked |
| `pairs` | At least seven baseline/candidate pairs per workload |
| `bootstrap_seed` | Explicit integer seed |
| `bootstrap_resamples` | At least 10,000 |
| `sample_interval_seconds` | RSS sampling interval, 0.005 through 1 second |
| `timeout_seconds` | Positive per-command/checker limit, at most 3,600 seconds |
| `workloads` | Nonempty, uniquely named workload set |

Each workload has `id`, `category`, `size`, `unit`, `phase`, and `variants`.
Supported phases are `simulation`, `compile_clean`, `compile_incremental`,
`solver_startup`, and `lifecycle`. A phase label describes the command; it does
not prove that the corresponding workload implements that measurement. Review
the command and its checker before using its results. Clean and incremental
build commands must independently establish the intended build state.

`variants` contains exactly `baseline` and `candidate`, each with:

| Field | Contract |
|---|---|
| `revision` | Exact source revision, with qualification evidence among inputs |
| `command` | Structured argument list; absolute executable; no shell expansion |
| `checker` | Structured command containing separate `{stdout}` and `{result}` arguments |
| `cwd` | Absolute existing working directory |
| `environment` | Explicit string mapping; otherwise only PATH, LC_ALL and TZ are provided |
| `inputs` | Files to hash before collection and before/after every measured run |
| `artifact` | Executable to identify, or generated build artifact for compilation phases |

`{sample_dir}` in command arguments expands to the unique sample directory,
allowing coverage and other outputs to remain separate. Checker placeholders
expand to the captured stdout and the expected JSON result path. All declared
inputs, command/checker executables, and absolute checker-script arguments are
hashed. Simulation artifacts are immutable inputs; compilation artifacts are
outputs, whose sizes and hashes are recorded after the build.

The checker runs **after** the timed command and returns zero only after
independent validation. It must write:

```json
{
  "status": "pass",
  "work_units": 7,
  "semantic_sha256": "7902699be42c8a8e46fbbb4501726517e86b22c56a189f7625a6da49081b2451"
}
```

Here the digest is SHA-256 of the example meaningful value `7`. A real checker
must derive both work count and digest from validated results, not from requested
iterations or a generic success message. A zero simulation exit code alone
cannot produce a valid comparison. Both sides of each pair must agree on the
complete checker result. Failed warmups also invalidate the comparison.

`performance_soc_check.py` adapts the accepted synthetic SoC's independent
memory, physical APB/AXI traffic, interrupt, reset and register oracle. Supply
`--source-root`, `--jobs`, optional `--dpi`, then `{stdout}` and `{result}`.
It counts completed DMA commands and hashes meaningful trace/results. Assertions
must remain enabled in that checker. The initial workload retains full traces
and the regression's `-O0` binary. It is an exploratory collector control;
optimized quiet workloads and steady-state calibration remain required.

## Integrity, statistics and resource limits

Collection refuses an existing output directory. An append-only journal hashes
each sample receipt; receipts hash raw outputs, checker results and resource
samples. Reporting verifies those identities, fixed ordering, pair membership,
completed work, semantic agreement, and aggregate RSS calculations. Missing
trailing pairs produce an invalid comparison. A changed or unsealed receipt
is rejected. Failed data is retained; no outlier is silently dropped.

Pairs alternate baseline/candidate and candidate/baseline order. For valid
pairs, the reported ratio is baseline wall time divided by candidate wall
time, which is also the throughput ratio when completed work agrees. The
point estimate is the geometric mean of paired ratios. Confidence intervals
resample entire pairs using the frozen seed, with percentile order statistics
at indices `floor(0.025*n)` and `ceil(0.975*n)-1` among `n` bootstrap estimates.
Warmups are excluded from the statistic, but remain required correctness data.
The report identifies comparisons using the same artifact as controls.

The Linux sampler sums resident memory of simultaneously observed processes
in the isolated command group, including concurrent children. This is a
**sampled aggregate estimate**, not a kernel-accounted peak. `/proc` reads
are not atomic and a child creating a separate process session can escape the
group. Controlled memory tests verify that concurrent children are included;
production peak-memory acceptance still requires stronger accounting. The
wall timer includes process launch, sampling and teardown overhead. Short
samples are explicitly identified as failing the 30-second steady-state rule.

Host CPU information, memory, OS, affinity, governors, cache policy and load
observations are preserved. The tool neither proves the host is idle nor
changes host policy. Production acceptance remains pending for every report.
Representative UVM/RTL workloads, clean/incremental build measurements, solver
startup separation, lifecycle growth and leak evidence, actual optimization,
and dedicated threshold enforcement remain required by GOALS.md.

## Continuous checks

`uvm-performance-tools.yml` runs collector integrity tests on a clean checkout.
It checks the tooling, not UVM workload performance or the production target.
No SoC nightly pass, M17 acceptance, or final G-PERF credit follows merely from
adding or passing this workflow.
