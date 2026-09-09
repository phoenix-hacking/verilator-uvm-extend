<!-- DESCRIPTION: Verilator: UVM sequence-item randomization profile and limits
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM sequence-item randomization profile

M09 requires random sequence items with deterministic seed replay and precise
documentation of unsupported constraint forms. Its scope includes random
fields, inline constraints, arrays, modes and diagnostics needed by UVM
sequence items. This profile maps those requirements to executable checks;
it does not establish full IEEE 1800 randomization or UVM conformance.

## Executable requirements

The [UVM fixture](../../test_regress/t/t_uvm_sequence_randomize.v) sends
64 randomized requests through a real sequencer and driver, checking response
ordinals and transaction IDs. The library is unmodified Accellera UVM
2020.3.1 at `78c06547a2a0a29b3dc9dcafae62b75b2ff61544`.

| Requirement | Checked behavior |
|---|---|
| Random fields and declared constraints | A 15-bit address is aligned, with constrained tag and payload length; every item is checked before and after transport. |
| Inline constraints | Each request address is within 128-892; a successful inline request for 132 proves recovery after an unsatisfiable solve. |
| Dynamic arrays and foreach | Payload size equals a length in 1-7; every byte equals `(tag + 3 * index) & 255`. |
| Nested random objects | The allocated metadata handle remains identical; its channel is within 1-19 and at most `length + 12`. |
| Variable modes | Disabled tag and length retain the assigned values 99 and 3; querying modes and restoring randomization are checked. |
| Constraint modes | Disabling the address constraint permits address 1; enabling it makes the same inline constraint unsatisfiable. |
| Callbacks | Each successful solve calls both callbacks; the failed solve calls `pre_randomize` but not `post_randomize`. Final counts are 68 and 67. |
| Failed-solve state | Address, tag, length, payload size and every byte, nested channel and handle remain unchanged. Callback side effects are checked separately. |
| Variation and seed replay | Each run observes at least eight tags and three lengths. Seeds 1729/1729 must yield identical 64-item traces; seed 2718 must change them. |
| Independent transaction oracle | Python checks ordinals, field bounds, address alignment, the cross-object constraint and a recomputed payload checksum. UVM error/fatal reports reject the run. |

The [driver](../../test_regress/t/t_uvm_sequence_randomize.py) runs DPI off/on
with one or two simulation threads. The named target additionally requires
an installed solver, checks cleanup safety, seeds stale artifacts and proves
their removal. Preserve the full build log: each simulator scenario compiles
twice, so its final `vlt_compile.log` alone cannot prove both DPI modes.

```sh
make -C test_regress uvm2020-randomize-source \
  UVM_SOURCE_ROOT=/path/to/uvm-2020.3.1
```

The constraint solver must report an unsatisfiable solve for the intentionally
contradictory address constraint. That expected diagnostic is distinct from
an ignored constraint. The successful transactions and failed-solve state
must still satisfy all of their ordinary checks.

## Current diagnostic limits

Twenty existing compile-only drivers were rerun on 2026-09-09 with the same
compiler as this profile. The table records their exact relevant diagnostics,
including `CONSTRAINTIGN`. Some tests deliberately configure a smaller
resource limit or supply invalid input; a row describes that specific case,
not every use of its operator or type. Driver options and goldens are linked.

`CONSTRAINTIGN` means the compiler does not solve the indicated constraint
normally. Messages saying "treating as state" describe a fixed input to the
solver, not a supported random relation. The default warning policy rejects
these fixtures. Suppressing the diagnostic does not make the missing
semantics conformant. These limitations remain open under the full language
and UVM goals; they earn no conformance credit.

| Driver / golden | Relevant diagnostic text |
|---|---|
| [t_constraint_array_limit](../../test_regress/t/t_constraint_array_limit.py) / [golden](../../test_regress/t/t_constraint_array_limit.out) | `Constraint array reduction ignored (array size 32 exceeds --constraint-array-limit of 16), treating as state` |
| [t_constraint_assoc_arr_bad](../../test_regress/t/t_constraint_assoc_arr_bad.py) / [golden](../../test_regress/t/t_constraint_assoc_arr_bad.out) | `Unsupported: Constrained randomization of associative array keys of 144bits, limit is 128 bits` |
| [t_constraint_countbits_unsup](../../test_regress/t/t_constraint_countbits_unsup.py) / [golden](../../test_regress/t/t_constraint_countbits_unsup.out) | `Unsupported: non-constant control in $countbits inside constraint` |
| [t_constraint_func_call_unsup](../../test_regress/t/t_constraint_func_call_unsup.py) / [golden](../../test_regress/t/t_constraint_func_call_unsup.out) | `Unsupported: complex function in constraint, treating as state` |
| [t_constraint_global_arr_unsup](../../test_regress/t/t_constraint_global_arr_unsup.py) / [golden](../../test_regress/t/t_constraint_global_arr_unsup.out) | `Unsupported: Array element access in global constraint`; `Unsupported: Nested array element access in global constraint` |
| [t_constraint_global_cls_arr_2d_unsup](../../test_regress/t/t_constraint_global_cls_arr_2d_unsup.py) / [golden](../../test_regress/t/t_constraint_global_cls_arr_2d_unsup.out) | `Unsupported: Nested array element access in global constraint` |
| [t_constraint_non_base2_pow_unsup](../../test_regress/t/t_constraint_non_base2_pow_unsup.py) / [golden](../../test_regress/t/t_constraint_non_base2_pow_unsup.out) | `Unsupported: Power (**) expression with non-2 base in constraint` |
| [t_constraint_non_const_exp_pow_unsup](../../test_regress/t/t_constraint_non_const_exp_pow_unsup.py) / [golden](../../test_regress/t/t_constraint_non_const_exp_pow_unsup.out) | `Unsupported: Power (**) expression with non-constant exponent in constraint` |
| [t_constraint_unq_arr_derived_inline_unsup](../../test_regress/t/t_constraint_unq_arr_derived_inline_unsup.py) / [golden](../../test_regress/t/t_constraint_unq_arr_derived_inline_unsup.out) | `Unsupported: Unique constraint in randomize() with {}` |
| [t_constraint_unsup_unq_arr](../../test_regress/t/t_constraint_unsup_unq_arr.py) / [golden](../../test_regress/t/t_constraint_unsup_unq_arr.out) | `Unsupported: Unique constraint on other than static arrays`; `Unsupported: Unique constraint on static arrays of size > 100` |
| [t_randomize_assoc_size_unsup](../../test_regress/t/t_randomize_assoc_size_unsup.py) / [golden](../../test_regress/t/t_randomize_assoc_size_unsup.out) | `Unsupported: associative array size with a random array selection.` |
| [t_randomize_complex_member_bad](../../test_regress/t/t_randomize_complex_member_bad.py) / [golden](../../test_regress/t/t_randomize_complex_member_bad.out) | `Unsupported: 'randomize() with' on complex expressions` |
| [t_randomize_inline_var_ctl_unsup_1](../../test_regress/t/t_randomize_inline_var_ctl_unsup_1.py) / [golden](../../test_regress/t/t_randomize_inline_var_ctl_unsup_1.out) | `Unsupported: Non-variable expression as 'randomize()' argument` |
| [t_randomize_inline_var_ctl_unsup_2](../../test_regress/t/t_randomize_inline_var_ctl_unsup_2.py) / [golden](../../test_regress/t/t_randomize_inline_var_ctl_unsup_2.out) | `Unsupported: Inline random variable control with 'randomize()' called on complex expressions` |
| [t_randomize_method_types_unsup](../../test_regress/t/t_randomize_method_types_unsup.py) / [golden](../../test_regress/t/t_randomize_method_types_unsup.out) | `Unsupported: random member variable with the type of the containing class`; `Unsupported: randomizing this expression, treating as state` |
| [t_randomize_nested_unsup](../../test_regress/t/t_randomize_nested_unsup.py) / [golden](../../test_regress/t/t_randomize_nested_unsup.out) | `Unsupported: randomize() nested in inline randomize() constraints` |
| [t_randomize_null_unsup](../../test_regress/t/t_randomize_null_unsup.py) / [golden](../../test_regress/t/t_randomize_null_unsup.out) | `Unsupported: 'randomize(null)' on class with rand container or class member` |
| [t_randomize_rand_mode_unsup](../../test_regress/t/t_randomize_rand_mode_unsup.py) / [golden](../../test_regress/t/t_randomize_rand_mode_unsup.out) | `Unsupported: 'rand_mode()' on dynamic array element`; `Unsupported: 'rand_mode()' on unpacked array element`; `Unsupported: 'rand_mode()' on unpacked struct element` |
| [t_randomize_recursive_unsup](../../test_regress/t/t_randomize_recursive_unsup.py) / [golden](../../test_regress/t/t_randomize_recursive_unsup.out) | `Unsupported: random member variable with the type of the containing class`; `Unsupported: recursive rand class member 'child'.` |
| [t_std_randomize_unsup_unq_arr](../../test_regress/t/t_std_randomize_unsup_unq_arr.py) / [golden](../../test_regress/t/t_std_randomize_unsup_unq_arr.out) | `Unsupported: Unique constraint in std::randomize() with {}` |

## Module-function array-reference limitation

A fresh direct lint probe still reports `IMPURE` for scope randomization of
a fixed-array reference in a module function. The diagnostic names the
generated `stdrand` helper as an external reference. A compact reproducer is:

```systemverilog
module t;
  function automatic int fixed_alias(ref bit [14:0] first,
                                     ref bit [14:0] data[3:1]);
    bit [14:0] previous_value = first;
    int result = std::randomize(first, data) with {1 == 0;};
    if (first != previous_value) $stop;
    return result;
  endfunction
  initial begin
    bit [14:0] data[3:1];
    int result;
    foreach (data[i]) data[i] = 15'(i + 20);
    result = fixed_alias(data[1], data);
    if (result != 0) $stop;
    $finish;
  end
endmodule
```

Run with `verilator --lint-only --top-module t probe.v`. The corresponding
static-class-method alias cases are covered by
[the scope-randomization regression](../../test_regress/t/t_randomize_std_unsat.v).
Those passing cases do not establish module-function support.

## Evidence boundaries

Compiler revision `71b9a0a173bf3f62cd5ec2683986cc91929ebde8` has a passing
named-target CI run with four configurations, 12 seeded positives and 768
transactions. Its raw log also passes the independent transaction oracle.
The newer complete failed-solve state checks require their own candidate
results: the older CI fixture did not check all those values. Preserve this
distinction when accepting M09 or reporting current-revision CI.

The program's synthetic SoC replay criterion also depends on M16. Complete
language/UVM conformance, broader solver/distribution semantics, whole-project
release validation and controlled performance acceptance remain separate
requirements. Regression wall-clock durations are not performance results.
