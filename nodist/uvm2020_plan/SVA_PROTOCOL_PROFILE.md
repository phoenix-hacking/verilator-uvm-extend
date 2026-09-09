<!-- DESCRIPTION: Verilator: Practical APB and AXI-lite assertion profile
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# Practical APB and AXI-lite assertion profile

M15 requires APB and AXI-lite assertions to agree with monitor-observed
behavior, with unsupported SVA constructs documented precisely. This profile
defines that acceptance boundary. It does not establish complete SVA language
parity, full UVM compliance or performance acceptance.

## Protocol rules

The fixtures use a single clock, 8-bit addresses and 32-bit data. APB has one
peripheral select. AXI-lite has independent AW, W, B, AR and R channels; it has
no burst or transaction-ID interface. The assertions and the procedural UVM
monitors sample the rising edge through separate implementations.

| Rule | Required sampled behavior | Paired injected fault |
|---|---|---|
| APB setup | Selected setup advances to selected access; address, direction, strobes and active write bytes remain stable. | Change address between setup and access. |
| APB wait | An incomplete access retains select, enable and the same request through the completion edge; reset cancels the obligation. | Change address during a wait state. |
| APB select | Enable requires select in this single-peripheral fixture. | Assert enable while idle with select low. |
| APB read strobe | Strobes are zero during a selected read. | Drive a nonzero strobe only on reads. |
| AXI reset | All five VALID signals are low during reset. | Assert each channel's VALID separately during reset. |
| AXI AW hold | A stalled AW retains VALID, address and protection through its handshake. | Change address; separately withdraw VALID. |
| AXI W hold | A stalled W retains VALID, data and strobes through its handshake. | Change data; separately withdraw VALID. |
| AXI B hold | A stalled B retains VALID and response through its handshake. | Change response; separately withdraw VALID. |
| AXI AR hold | A stalled AR retains VALID, address and protection through its handshake. | Change address; separately withdraw VALID. |
| AXI R hold | A stalled R retains VALID, data and response through its handshake. | Change data; separately withdraw VALID. |

APB request and signal-validity rules follow Arm IHI 0024D, sections 3.1-3.4,
4.1 and Appendix A. Read PWDATA and inactive write bytes are not request data;
the positive controls vary those values through setup and wait states. The
enable/select rule is specific to this fixture: a shared APB bus may assert
PENABLE while a different peripheral is selected.
[Arm APB specification](https://documentation-service.arm.com/static/60d5b505677cf7536a55c245)

AXI reset and hold rules follow Arm IHI 0022H, A3.1.2 and A3.2.1-A3.2.2,
within the AXI4-Lite profile of B1.1. Reset disables the five hold obligations.
The profile does not impose a fixed maximum response latency.
[Arm AXI specification](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf)

## Independent agreement checks

[APB](../../test_regress/t/t_uvm_apb_env.py) and
[AXI-lite](../../test_regress/t/t_uvm_axi_env.py) each run identical fault
stimulus twice: assertions alone, then procedural monitors alone. Both runs
emit the physical bus values on falling edges. These fixtures only drive
signals at rising edges, so those values are the next rising edge's sampled
inputs. The Python [protocol oracle](../../test_regress/t/uvm_protocol_common.py)
checks the bus independently of both SystemVerilog implementations. It
requires identical physical prefixes and the intended diagnostic at the
first invalid cycle. The AXI reset cases also require exactly the selected
channel's VALID to be high. Each of the five hold rules has both a payload
mutation and a premature VALID withdrawal case.

Positive runs keep assertions and active/passive monitors enabled. Seeds
1729, 1729 and 2718 must reproduce identical traffic for equal seeds and
different traffic for the third seed. Each APB run completes 2,436 transfers;
each AXI run completes 2,468, including 1,202 writes and 1,266 reads. Existing
scoreboard, error response, reset cancellation/recovery, RAL predictor,
frontdoor and built-in sequence checks remain required. Every individual
coverage bin is compared with the completed-transaction histogram, then the
two different seeds' bin counts are summed and exported to LCOV. Separate
corrupt-data and AXI RAL-response cases prove those error paths.

The source-library acceptance matrix is APB/AXI-lite, one/two simulation
threads, and DPI disabled/enabled: eight configurations. It uses clean,
unmodified Accellera UVM 2020.3.1 at
`78c06547a2a0a29b3dc9dcafae62b75b2ff61544`. DPI configuration coverage here
does not replace M14's HDL access and C-reference acceptance requirements.
The profile's SVA subset is clocked `assert property`, overlapping and
non-overlapping implication, `disable iff`, Boolean/concatenation expressions
and `$stable`. Other constructs require their own evidence.

From a configured checkout with the native compiler and coverage utility
built, reproduce the source runs with the following command. Run it again
with `--vltmt` in place of `--vlt`; each driver runs both DPI variants.

```sh
cd test_regress
python driver.py --vlt --jobs=1 --driver-build-jobs=1 \
  --driver-uvm-source-root=/path/to/uvm-2020.3.1 \
  t/t_uvm_apb_env.py t/t_uvm_axi_env.py
```

## Precisely retained SVA limits

On 2026-09-09, 24 existing compile-only drivers passed their expected-error
goldens against the same native compiler as the protocol matrix. The table
below lists the exact `Unsupported:` diagnostics they exercise. The linked
driver fixes the source, defines and compiler options; its golden records
the rejected expression and location. Mixed `_bad` fixtures also contain
ordinary input errors; only their unsupported diagnostics are listed here.
These are specific rejected forms, not a claim that every use of an operator
is unsupported or a complete inventory of IEEE 1800 requirements.

The `pexpr_parse` and `sexpr_parse` drivers set `PARSING_TIME`. Their sources
explicitly describe some grammar examples as unchecked against other
simulators; those rows establish current parser rejection, not independent
proof that every example is legal SystemVerilog.

| Existing driver / golden | Rejected form (`Unsupported:` text) |
|---|---|
| [t_assert_always_unsup](../../test_regress/t/t_assert_always_unsup.py) / [golden](../../test_regress/t/t_assert_always_unsup.out) | `eventually[] (in property expression)` |
| [t_assert_clock_event_unsup](../../test_regress/t/t_assert_clock_event_unsup.py) / [golden](../../test_regress/t/t_assert_clock_event_unsup.out) | `Clock event before property call and in its body` |
| [t_assert_consec_rep_bad](../../test_regress/t/t_assert_consec_rep_bad.py) / [golden](../../test_regress/t/t_assert_consec_rep_bad.out) | `[*0] consecutive repetition`; `[*N:0] consecutive repetition with zero max count` |
| [t_assert_consec_rep_unsup](../../test_regress/t/t_assert_consec_rep_unsup.py) / [golden](../../test_regress/t/t_assert_consec_rep_unsup.out) | `multi-cycle sequence expression inside consecutive repetition (IEEE 1800-2023 16.9.2)` |
| [t_assert_ctl_arg_unsup](../../test_regress/t/t_assert_ctl_arg_unsup.py) / [golden](../../test_regress/t/t_assert_ctl_arg_unsup.out) | `assert control assertion_type`; `non-const assert directive type expression` |
| [t_assert_procedural_clk_bad](../../test_regress/t/t_assert_procedural_clk_bad.py) / [golden](../../test_regress/t/t_assert_procedural_clk_bad.out) | `Procedural concurrent assertion with clocking event inside always (IEEE 1800-2023 16.14.6)` |
| [t_assert_rep_bad_count](../../test_regress/t/t_assert_rep_bad_count.py) / [golden](../../test_regress/t/t_assert_rep_bad_count.out) | `zero repetition count (IEEE 1800-2023 16.9.2)` |
| [t_assert_rep_range_unsup](../../test_regress/t/t_assert_rep_range_unsup.py) / [golden](../../test_regress/t/t_assert_rep_range_unsup.out) | `[=M:N] nonconsecutive range repetition (IEEE 1800-2023 16.9.2)` |
| [t_assert_rep_range_zero_min_unsup](../../test_regress/t/t_assert_rep_range_zero_min_unsup.py) / [golden](../../test_regress/t/t_assert_rep_range_zero_min_unsup.out) | `zero min count in Goto repetition range (IEEE 1800-2023 16.9.2)`; `zero min count in Nonconsecutive repetition range (IEEE 1800-2023 16.9.2)` |
| [t_assert_seq_clocking_unsup](../../test_regress/t/t_assert_seq_clocking_unsup.py) / [golden](../../test_regress/t/t_assert_seq_clocking_unsup.out) | `clocking event inside sequence expression`; `multiclocked sequence or property`; `non-edge clocking event on a sequence; use an edge such as @(posedge clk)` |
| [t_property_clock_collision_unsup](../../test_regress/t/t_property_clock_collision_unsup.py) / [golden](../../test_regress/t/t_property_clock_collision_unsup.out) | `Clock event before property call and in its body` |
| [t_property_disable_iff_unsup](../../test_regress/t/t_property_disable_iff_unsup.py) / [golden](../../test_regress/t/t_property_disable_iff_unsup.out) | `$sampled inside disabled condition of a sequence` |
| [t_property_local_var_range_unsup](../../test_regress/t/t_property_local_var_range_unsup.py) / [golden](../../test_regress/t/t_property_local_var_range_unsup.out) | `property local variable used across composite sequence operator in consequent (IEEE 1800-2023 16.10)`; `property local variable used across non-constant cycle delay in consequent (IEEE 1800-2023 16.10)` |
| [t_property_pexpr_parse_unsup](../../test_regress/t/t_property_pexpr_parse_unsup.py) / [golden](../../test_regress/t/t_property_pexpr_parse_unsup.out) | `nexttime (in property expression)`; `nexttime[] (in property expression)`; `property argument data type`; `s_eventually[] (in property expression)`; `s_nexttime (in property expression)`; `s_nexttime[] (in property expression)`; `sequence argument data type`; `strong (in property expression)`; `weak (in property expression)` |
| [t_property_recursive_unsup](../../test_regress/t/t_property_recursive_unsup.py) / [golden](../../test_regress/t/t_property_recursive_unsup.out) | `Recursive property call: 'check'` |
| [t_property_s_eventually_unsup](../../test_regress/t/t_property_s_eventually_unsup.py) / [golden](../../test_regress/t/t_property_s_eventually_unsup.out) | `cycle delay in s_eventually` |
| [t_property_sexpr_parse_unsup](../../test_regress/t/t_property_sexpr_parse_unsup.py) / [golden](../../test_regress/t/t_property_sexpr_parse_unsup.out) | `'until' in complex property expression`; `s_until (in property expression)`; `s_until_with (in property expression)` |
| [t_property_sexpr_unsup](../../test_regress/t/t_property_sexpr_unsup.py) / [golden](../../test_regress/t/t_property_sexpr_unsup.out) | `'until' in complex property expression`; `s_until (in property expression)`; `s_until_with (in property expression)` |
| [t_property_unsup](../../test_regress/t/t_property_unsup.py) / [golden](../../test_regress/t/t_property_unsup.out) | `eventually[] (in property expression)` |
| [t_property_var_unsup](../../test_regress/t/t_property_var_unsup.py) / [golden](../../test_regress/t/t_property_var_unsup.out) | `property variable default value` |
| [t_sequence_intersect_range_unsup](../../test_regress/t/t_sequence_intersect_range_unsup.py) / [golden](../../test_regress/t/t_sequence_intersect_range_unsup.out) | `intersect of two sequences that each vary in length over a range with internal structure`; `intersect operand is not a plain boolean sequence`; `intersect with this variable-length operand` |
| [t_sequence_ref_unsup](../../test_regress/t/t_sequence_ref_unsup.py) / [golden](../../test_regress/t/t_sequence_ref_unsup.out) | `sequence referenced outside assertion property` |
| [t_sequence_sexpr_unsup](../../test_regress/t/t_sequence_sexpr_unsup.py) / [golden](../../test_regress/t/t_sequence_sexpr_unsup.out) | `first_match with sequence_match_items`; `sequence argument data type` |
| [t_sequence_within_range_unsup](../../test_regress/t/t_sequence_within_range_unsup.py) / [golden](../../test_regress/t/t_sequence_within_range_unsup.out) | `within with ranged cycle-delay operand` |

## Excluded stale evidence and remaining scope

`t_assert_ctl_unsup.v/.out` has no matching Python driver and no other driver
references it. A direct `--lint-only --assert` probe with this compiler exits
zero. Its old expected rejections of assertion-control actions therefore do
not describe current unsupported behavior. That lint result alone establishes
no runtime assertion-control semantics. The active
`t_assert_ctl_arg_unsup.py` cases in the table remain reproducible limits.

The profile covers sampled behavior in these synchronous fixtures. It does
not claim asynchronous glitch checking, four-state/X propagation, every APB
optional signal, full AXI bursts/IDs, arbitrary concurrent property forms,
checker constructs or full assertion-control/debug APIs. Those requirements,
the synthetic SoC workload, source-library deviations and complete release
validation retain their separate program gates. Local protocol evidence
does not supply current-revision CI or a controlled performance measurement.
