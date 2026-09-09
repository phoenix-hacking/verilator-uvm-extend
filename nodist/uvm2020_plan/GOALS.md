<!-- DESCRIPTION: Verilator: full UVM compliance and performance goals
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM compliance and performance goals

These are the two explicit project goals requested on 2026-09-07. Both are
**in progress, not achieved**. `tracker.yaml` records their acceptance checks
and evidence. The existing 21 program criteria and 46 milestone gates remain
the implementation plan; passing them alone does not waive the stricter
acceptance requirements below. No new completion percentage is inferred.

## G-UVM: Full UVM compliance

Tracked in [issue #43](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/43).

Implement and verify the behavior required by IEEE 1800.2-2020, using
unmodified Accellera UVM 2020.3.1 as the initial reference library, including
the SystemVerilog semantics needed to execute those requirements correctly.
Record exact library revisions, simulator revisions, compiler flags, solver
versions, supported hosts, and DPI configuration for each result. A later
library release requires an explicit version change and revalidation.

Acceptance requires all of the following:

1. **Normative inventory.** Map every applicable normative UVM requirement
   and API, including requirements outside the current P0 inventory, to
   positive and negative tests with independently justified expected results.
   Record clause identifiers, applicability, test paths, results, and evidence.
   A documented implementation limitation is an open requirement, not a pass.
1. **Unmodified library execution.** Build and execute source-tree tests in
   DPI and no-DPI configurations. Check the pinned library commit and clean
   source tree. DPI-dependent requirements remain required in the DPI mode;
   `UVM_NO_DPI` cannot waive them from the overall goal.
1. **Semantic correctness.** Cover event regions, process lifetime, classes,
   virtual interfaces, clocking, containers, randomization, coverage, SVA,
   DPI, and the HDL-access behavior required by the UVM APIs. Use reduced
   causal regressions before attributing an integration failure to UVM.
1. **Integrated verification.** Pass factory/reporting/phasing/objections,
   config/resource, synchronization, TLM/sequences, randomized items, class
   coverage and merge, APB, AXI-lite, RAL, DPI reference models, HDL backdoor,
   and synthetic SoC tests. Include reset, cancellation, error paths, multiple
   seeds, deterministic replay, and repeated teardown without growing memory.
1. **Independent correctness evidence.** Derive oracles from the normative
   requirements and compare semantic traces with an independent simulator
   where available. Document unavailable comparisons and resolve conflicting
   results. Verilator agreeing with its own output is insufficient evidence.
1. **Release closure.** All 21 program criteria pass, every applicable
   requirement passes, and clean-checkout host/compiler CI, relevant sanitizer
   checks, and the complete regression pass at the exact release revision.
   No unresolved correctness failure, required-test skip, or required-feature
   XFAIL is allowed. An upstream library defect remains a compliance blocker
   until its resolution is verified; never change standard language behavior
   merely to accommodate it.

The current direct resource-lookup XFAIL blocks this goal. The accumulated
115/115 declared compatibility oracles include negative/unsupported tests and
bounded XFAIL handling; that count is not a compliance percentage. Earlier
C0-C3 support levels remain useful intermediate deliveries. They cannot be
renamed full compliance while mandatory deviations remain. This goal does not
claim complete support for unrelated parts of IEEE 1800.

## G-PERF: Performance optimization suitable for production

Tracked in [issue #44](https://github.com/phoenix-hacking/verilator-uvm-extend/issues/44).

Establish reproducible baselines, profile the compiler and runtime, implement
measured improvements, and continuously guard correctness and performance.
Measure compilation wall time, aggregate build peak RSS, executable size,
simulation throughput, simulation peak RSS, and memory growth during repeated
construction, cancellation, and teardown. Report solver startup separately
from sustained randomized-transaction throughput.

Acceptance requires all of the following:

1. **Frozen, correct baselines.** Pin a correct reference revision per
   workload before optimization, with the same inputs, seeds, host, compiler,
   solver, flags, parallelism, and output checks as the candidate. A reference
   that cannot execute a feature gives no speedup comparison. Preserve a
   separate upstream RTL baseline and identify every comparison revision.
1. **Representative workloads.** Cover allocation/factory/config lookup,
   event/process/phasing, TLM/sequence traffic, constrained randomization,
   coverage, RAL, APB/AXI-lite, and a scalable synthetic SoC. Use multiple
   sizes and an RTL control suite. Microbenchmarks alone cannot satisfy this
   goal; all workloads must check results and actual completed work.
1. **Controlled measurements.** Use an otherwise idle host with recorded CPU,
   memory, OS, affinity, governor, and cache policy. Measure clean compilation
   separately from incremental builds. Use at least one warmup and seven
   paired, interleaved baseline/candidate samples. Calibrate steady-state
   workloads to at least 30 seconds per sample. Retain every sample, output
   digest, command, and resource measurement; investigate outliers instead of
   deleting inconvenient results.
1. **Measured improvement.** The initial engineering target is at least 10%
   higher geometric-mean UVM throughput across the preregistered workload
   set, with a paired 95% confidence interval excluding no improvement, plus
   at least 20% improvement in one profiled bottleneck. State each workload's
   result so an aggregate cannot hide regressions. These are project targets,
   not results or an industry certification.
1. **Regression and memory limits.** For every acceptance workload, the upper
   95% confidence bound for runtime slowdown must be at most 5%; compilation
   time and measured aggregate peak RSS must grow by at most 10%. RTL control
   runtime uses the same 5% bound. Inconclusive/noisy results remain pending.
   No linear memory growth across repeated steady-state teardown is allowed;
   investigate retained allocations and corroborate with leak checking.
1. **Continuous evidence.** Publish a reproducible machine-readable benchmark
   report and dashboard, enforce thresholds in dedicated performance CI, and
   rerun the semantic and integration checks after optimization. A code
   correctness failure invalidates the corresponding performance result.

Freeze workload membership, thresholds, and statistical procedures before
collecting acceptance data. Record any later policy change with its rationale
and rerun both sides; do not move thresholds to turn a failure into a pass.
Use paired bootstrap intervals with a recorded resampling seed and at least
10,000 resamples. Peak-RSS accounting must include concurrent build children;
timing a shell wrapper alone does not measure aggregate memory. Results from
the current shared, busy development host are exploratory only.

Current performance evidence is **not established**. Regression durations and
successful compilation do not constitute a performance grade. The immediate
sequence is correctness closure, frozen benchmark fixtures, baseline capture,
profiling, measured optimizations, then acceptance on an isolated host.

## Evidence and issue policy

Keep the two goal issues, this contract, `tracker.yaml`, `PROGRESS.md`, and
each owning milestone consistent. Link source revisions and retained results
when accepting a check. Do not close a capability issue merely because its
test was added, an expected failure was documented, or an environment was
installed. A supported subset may ship with accurate limits while both goals
remain open.
