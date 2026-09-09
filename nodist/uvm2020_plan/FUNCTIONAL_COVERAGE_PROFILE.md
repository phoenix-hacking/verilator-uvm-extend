<!-- DESCRIPTION: Verilator: UVM class coverage, query, report and merge profile
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM functional coverage profile

M10 requires class covergroups, UVM subscribers, coverage reporting and merge
behavior. This profile defines the executable acceptance cases. The stricter
full-language and UVM requirements remain tracked under [GOALS.md](GOALS.md).
Implementation or diagnostic limits below remain open requirements there.

## Subscriber and database checks

The APB and AXI-lite fixtures use real `uvm_subscriber` components connected to
the passive monitors' analysis ports. Reset notifications do not sample the
covergroups. Each fixture executes with unmodified Accellera UVM 2020.3.1 at
`78c06547a2a0a29b3dc9dcafae62b75b2ff61544`, with DPI off/on and one/two simulation
threads. Seeds 1729, 1729 and 2718 check exact replay and changed traffic.

| Fixture | Coverage items | Expected normal bins | Transfers per seeded run |
|---|---|---:|---:|
| [APB](../../test_regress/t/t_uvm_apb_env.py) | Direction, response, wait states | 7 | 2,436 |
| [AXI-lite](../../test_regress/t/t_uvm_axi_env.py) | Direction, response, byte enables, channel order, direction/response cross | 27 | 2,468 |

The Python drivers derive each expected hit count from completed driver
transactions and compare every database bin, rejecting duplicates and missing
bins. The independent protocol oracle also checks the physical bus samples,
monitor/assertion agreement, legal reset behavior and injected faults.

Each subscriber reports instance and type percentages and both methods' covered/
total bin outputs at sample counts 0, 1, 2, 17, 257 and the final count.
[The query oracle](../../test_regress/t/uvm_coverage_common.py) reconstructs the
observed bins from independent driver traffic. AXI reads and writes have separate
ordered streams. With the declared unit weights, IEEE 1800-2017 19.11 requires
the arithmetic mean of the item bin ratios; 19.8 requires unweighted bin counts.
Both methods must agree for the single instance in each protocol fixture.

The coverage utility merges the two different-seed database files. Every merged
bin must equal the sum of its two independently checked input counts. The utility
also emits an LCOV report for the fixture. Acceptance verification checks its
branch counts against the expected merged bins and its source locations against
the coverpoint/cross declarations. Live queries must not change report counters.

## Reduced semantic cases

| Area | Executable evidence |
|---|---|
| Weighted instance/type queries, released/recreated handles, whole instance-option assignment and references, skipped/aliased count outputs | [t_covergroup_weighted](../../test_regress/t/t_covergroup_weighted.py) |
| Static group options before construction, persistent procedural changes, whole static-option assignment/references, merged vs instance queries and summed hit thresholds | [t_covergroup_type_options](../../test_regress/t/t_covergroup_type_options.py) |
| Nonconstant type-option declaration initializer | [t_covergroup_type_option_bad](../../test_regress/t/t_covergroup_type_option_bad.py) |
| Retained coverage-only data, independent registries, unequal bin names, overflow-safe merged sums and retained report pointers | [t_covergroup_type_runtime](../../test_regress/t/t_covergroup_type_runtime.py) |

These reduced positive tests include C++14 and protected identifiers, one/two
threads where applicable, and sanitizer runs. A saved failing parent establishes
that type coverage formerly returned zero, count outputs were not assigned,
whole-option writes did not reach coverage state, static type-option access
emitted invalid C++, and merged queries did not apply elaborated hit thresholds.
Those individual proofs do not by themselves establish UVM subscriber acceptance.

## Remaining full-coverage requirements

| Requirement outside this profile | Current boundary |
|---|---|
| Coverpoint/cross type-option storage and scoped item access | Item storage currently exposes instance weight only; static item weights and complete item methods remain unfinished. [The current item-method diagnostic driver](../../test_regress/t/t_covergroup_coverpoint_method_unsup.py) records its rejected calls. |
| Complete option defaults and reporting metadata | Only the implemented weight, query-mode and elaborated threshold/bin-layout paths are claimed. Full name/comment propagation and the remaining instance/type options need implementation and validation. |
| Sampling controls and scheduling | The generated `start`, `stop` and `set_inst_name` methods still have empty bodies; full strobe behavior is unfinished. Parsing an option is not evidence that its behavior is implemented. |
| Dynamic bin layouts and runtime threshold changes | The current compiler paths elaborate supported layouts and hit thresholds. Constructor-dependent layouts and complete post-construction option behavior remain open. |
| All language/API combinations and model lifetimes | The focused retained-data and registry tests do not establish every covergroup/cross/lifecycle/context case. Full requirement mapping and regression remain necessary. |

No documented limit grants full conformance credit. Final release acceptance still
requires complete current-source regression/CI, all applicable requirements and
controlled performance evidence. Full-release annotation-check failures remain
separate open work; this profile does not waive them.
