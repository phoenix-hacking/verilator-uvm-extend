<!-- DESCRIPTION: Verilator: UVM 2020 development continuation ledger
     SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
     SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0 -->

# UVM 2020 continuation ledger

This file is the durable handoff record for pull request #41. It records
published checkpoints, exact evidence boundaries, unresolved design issues, and
the next reproducible action. It deliberately does not treat historical CI as
proof of later source changes.

Do not commit extracted standards text, rendered standards pages, generated
test objects, or temporary compiler trees. In particular, the repository-local
`tmp/` directory is scratch material and is not part of any checkpoint.

## 2026-08-07 process-lifecycle checkpoint

Recorded at: 2026-08-07T11:27:28Z

### Published state

- Repository: `phoenix-hacking/verilator-uvm-extend`
- Draft pull request: <https://github.com/phoenix-hacking/verilator-uvm-extend/pull/41>
- Branch: `agent/uvm2020-clean-lane`
- Parent: `f0b5ddb93bee1d7716b261da352681dac4119e9f`
- Published commit: `8058c2a202af0a5575fb773dd2251a74a8e8c7d3`
- Published tree: `33a0baecaa610ce35f5ff5c391a4ebbf9984ff5a`
- Remote verification:
  `git ls-remote origin refs/heads/agent/uvm2020-clean-lane` returned
  `8058c2a202af0a5575fb773dd2251a74a8e8c7d3`.
- The first local commit object was
  `0dfac40a5f8bf55c3c43e65095b59c0bb2238356`. Non-interactive HTTPS
  authentication rejected the direct push before writing anything. The
  connected GitHub app then created commit `8058c2a202...` with the exact same
  tree and parent and advanced the branch without force. The local branch was
  aligned to that verified remote object.

### Scope

The checkpoint contains 36 files, 1,131 insertions, and 50 deletions. It:

- restores dynamic caller process and RNG context across coroutine suspension
  and nested resume;
- gives process-aware scheduled procedures independent or persistent
  `VlProcess` identities as appropriate;
- preserves child `FINISHED` state before fork parents resume;
- stops killed initial blocks and constructor expressions before later
  statements or assignment commits;
- preserves process cancellation boundaries through depth, CFunc split,
  inlining, scheduling, and ordering passes;
- gives recurring non-suspendable `always_comb` procedures one persistent
  process handle; and
- adds focused regressions for these behaviors.

Named task/block disable registry changes are intentionally not in this
checkpoint.

### Compiler evidence

The final exact-tree compiler was built under
`/tmp/verilator-core-build-KScN7O`.

- Version:
  `Verilator 5.051 devel rev vUNKNOWN-built20260807-20075c4 (mod)`
- Binary SHA-256:
  `857d047831d1327a0ca0c7332955265f55fefb452649792fb60dc99ab47ab3d2`
- Source tree:
  `33a0baecaa610ce35f5ff5c391a4ebbf9984ff5a`

The optimized compiler build command was:

```sh
make -C src/obj_opt -f ../Makefile_obj clean
make -C src opt -j8 OBJCACHE= LDFLAGS= LIBS='-lpthread -latomic -lm'
```

The isolated configured tree had `LEX=true` and `YACC=true`, while the
environment had neither flex nor bison. After `clean`, the tracked-source build
therefore reused the five generated parser/lexer files from the exact-parent
configured build and refreshed their timestamps before invoking `make`:

```sh
cp -p /tmp/verilator-test-audit-f0-copy/src/obj_opt/V3ParseBison.c \
      /tmp/verilator-test-audit-f0-copy/src/obj_opt/V3ParseBison.h \
      /tmp/verilator-test-audit-f0-copy/src/obj_opt/V3ParseBison.output \
      /tmp/verilator-test-audit-f0-copy/src/obj_opt/V3Lexer_pregen.yy.cpp \
      /tmp/verilator-test-audit-f0-copy/src/obj_opt/V3PreLex_pregen.yy.cpp \
      src/obj_opt/
touch src/obj_opt/V3ParseBison.c src/obj_opt/V3ParseBison.h \
      src/obj_opt/V3ParseBison.output src/obj_opt/V3Lexer_pregen.yy.cpp \
      src/obj_opt/V3PreLex_pregen.yy.cpp
```

The final `V3EmitCFunc.cpp` and `V3Split.cpp` corrections were rebuilt
incrementally in that otherwise clean tree. A new clean build from the published
commit remains required before promotion.

### Focused regression evidence

The direct-test command form was:

```sh
cd /tmp/verilator-core-build-KScN7O/test_regress
VERILATOR_ROOT=/tmp/verilator-core-build-KScN7O \
PYTHONPATH=/tmp/uvm_run_shim \
/workspace/scratch/965baf652559/artifacts/test-venv/bin/python \
  t/TEST.py --driver-build-jobs=1 --obj-suffix=UNIQUE_SUFFIX
```

The aggregate driver could not create its forkserver Unix socket in the
sandbox, so tests were invoked directly with unique object suffixes. All of the
following passed:

- `t_process_self_kill_initial`
- `t_process_context_fork`
- `t_process_fork_finished`
- `t_process_self_kill_ctor`
- `t_process_self_kill_ctor_expr`
- `t_process_self_kill_ctor_depth`
- `t_process_self_kill_initial_split`
- `t_process_always_comb_identity`
- `t_process_always_comb_kill`
- `t_process_always_comb_self`
- `t_process_phase_teardown` with
  `PHASE_TEARDOWN_SENTINEL phases=1000 winners=1000 cleanups=1000`
- `t_always_split`
- `t_always_splitord`
- `t_always_nosplit`

During checkpoint isolation, the first runs of
`t_process_context_fork` and `t_process_fork_finished` exposed an accidental
dependency on the held-back registry helper `VlProcess::createChild`. The core
checkpoint restored ordinary child construction and both tests then passed.
The first runs of the three `always_comb` tests exposed a misplaced
`alwaysNeedsProcess` guard that let `AstSplitPlaceholder` reach emission.
Moving the guard to `SplitVisitor` and keeping placeholder cleanup
unconditional fixed the internal error; all three focused tests and the three
neighboring split regressions then passed.

No persistent test log was committed. The exact commands, tree, binary digest,
per-test object suffixes, and console results above are the available local
provenance. Current-head GitHub Actions and the complete `uvm2020` lane are
still pending.

### Parent baseline

An exact `f0b5ddb93...` optimized compiler was built separately under
`/tmp/verilator-test-audit-f0-copy`. The same direct-test command form used
`--obj-suffix=-f0audit3`. The parent was red for the ten new semantic tests:

- self-killed initial process timed out at the old fall-through path;
- fork-child context changed the wrong RNG stream;
- fork parent observed a completed child as `WAITING`;
- self-killing constructors overwrote destinations or fell through;
- deep constructor splitting failed generated C++ compilation;
- split initial code executed after self-kill; and
- the three `always_comb` tests exposed shared identity, reactivation after
  kill, or RNG-context corruption.

The new direct registry C++ test is not behavioral parent evidence: it fails at
the parent only because the proposed `VlProcessRegistry` API is absent. A
temporary SystemVerilog-only registry scenario passed on the parent.

### Standards anchors

The current claim boundaries use:

- IEEE Std 1800-2012, 9.2.2 and 9.2.2.2, printed pages 170-172, for
  `always` and `always_comb`;
- IEEE Std 1800-2012, 9.3.2, printed page 175, for fork/join completion;
- IEEE Std 1800-2012, 9.6.2, printed pages 190-192, for named task/block
  disable;
- IEEE Std 1800-2012, 9.7, printed pages 193-194, for process states and
  control; and
- IEEE Std 1800-2012, 18.14, printed pages 503-504, for process-local random
  stability.

For UVM teardown only, IEEE Std 1800.2-2020, 9.6, printed page 92, is the
normative task-phase-thread kill reference. The UVM Cookbook printed page 50 and
pages 185-187 are secondary phase/objection background, not normative proof.

### Held-back registry design blockers

The working tree contains an unpublished registry prototype. Do not commit its
current `completedTree` lifetime model. The next implementation must resolve
all of these together:

1. A named sequential begin/task activation is disable-eligible only while that
   activation is executing. A later disable of a completed activation has no
   effect.
2. A named fork needs its own tree-completion lifetime so a disable can still
   reach live branches and descendants.
3. Concurrent and recursive activations need distinct membership groups.
   Process-identity dedup alone cannot represent overlapping activations.
4. Dynamically created descendants must inherit the activation token while the
   target remains active.
5. Registry membership must not be the only strong owner of the general process
   tree. A finished named block may leave a `join_none` descendant blocked in
   `wait(0)`; dropping named-disable membership must not let a later
   `wait fork` complete incorrectly.
6. `disableAll` must atomically drain activation groups and deduplicate the
   process forest before callbacks can resume or destroy frames.
7. Direct `PROCESS_DISABLE_ALL` operations inside `always` procedures must
   also be visible to the split/reorder barriers.
8. An in-scope disable of a named begin inside an automatic task must reach all
   concurrent activations, not just perform a local `AstJumpGo` in the caller.
9. Any compiler-generated child boundary around a named begin must not strand
   `return`, `break`, or `continue` jumps whose targets remain outside that
   boundary.

Required registry regressions include active begin/task disable, late disable
after completion, named fork join/join_any/join_none behavior, concurrent and
recursive activations, registry clear/reuse, direct disable from recurring
procedures, and the `wait(0)` descendant plus `wait fork` ownership case.
Also cover two concurrent automatic-task activations and named begin bodies
that return from a task or break/continue an enclosing loop.

### Other open work

- Replace the repeated per-`always` call-graph walk in `V3Split` and
  `V3Reorder` with a pass-wide safe closure/SCC result. Naively memoizing a
  false result through a cycle can misclassify other SCC members.
- Re-run a clean optimized build from published commit `8058c2a202...`, then
  the complete focused set, the exclusive current `uvm2020` lane, and
  current-head CI.
- Update `PLAN.md`, `MATRIX.md`, `PROGRESS.md`, both trackers, and the
  support/roadmap documents with page-level citations, exact commands, retained
  log or CI links, and explicit historical-versus-current result scope.
- Remove the stale claim that `stash@{0}` exists.
- Do not describe the 20-test integration lane as direct proof of tests that it
  does not run; expand the lane or define a mandatory focused target.
- Keep the pull request draft. Human review and human DCO certification remain
  required before readiness or merge.

### Next exact action

Start by adding the ownership/lifetime regressions against the published head,
without staging the current registry prototype:

```sh
git status --short --branch
git diff 8058c2a202af0a5575fb773dd2251a74a8e8c7d3 -- \
  include/verilated_timing.cpp include/verilated_types.h \
  src/V3AstAttr.h src/V3AstNodeDType.h src/V3AstNodes.cpp \
  src/V3EmitCFunc.cpp src/V3Hasher.cpp src/V3LinkJump.cpp \
  src/V3Reorder.cpp src/V3Split.cpp src/V3Timing.cpp src/V3Width.cpp \
  test_regress/t/t_process_disable_registry.cpp \
  test_regress/t/t_process_disable_registry.py \
  test_regress/t/t_process_disable_registry.v
```

Then write the activation-token and independent process-tree-ownership design
against those tests. Rebuild and publish it as a separate checkpoint only after
the active, completed, concurrent, recursive, named-fork, and `wait fork`
cases all pass.
