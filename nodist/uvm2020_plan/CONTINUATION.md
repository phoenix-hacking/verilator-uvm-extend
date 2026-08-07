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

## 2026-08-07 fork-registration hotfix checkpoint

Recorded at: 2026-08-07T13:49:59Z

### Published state

- Repository: `phoenix-hacking/verilator-uvm-extend`
- Draft pull request: <https://github.com/phoenix-hacking/verilator-uvm-extend/pull/41>
- Branch: `agent/uvm2020-clean-lane`
- Parent: `497c491645f1e91348d9a581c25dae763173b76b`
- Functional hotfix: `9b914a223ea23650c51d699a2fef544d6c710d63`
- Functional tree: `dd014e767b544ac2b5c7e3928a06ad2251388e7a`
- Autoformat-only child: `7f58c75b65402287a7fcd8943e25b09becb8ed08`
- Autoformatted tree: `0c6a891e3c833e08366d606f0664dc452312f88e`

The connected GitHub app created the functional commit with the exact local
functional tree and advanced the verified branch without force. GitHub's
formatter child only wraps the new C++ conditions and assertions; it does not
change their operands, control flow, or data flow. A local tree-equivalent
formatter commit, `0546f03f4eb2be2e61b7640659f3e94e089e286d`, was used
only to build the exact remote tree.

### Failure found and hotfix scope

A clean build of parent `497c491645f1e91348d9a581c25dae763173b76b`
proved that the two-phase fork-launch checkpoint had one compiler-lowering
regression. Existing tests `t_disable_task_join` and
`t_disable_task_by_name` stopped in `V3SchedTiming` at the new
"process registration is not at branch entry" invariant. Sixteen other
focused regressions passed that parent.

The failing timing tree showed the exact post-`V3Task` prefix:

1. the fork kill hook;
2. a generated `std::process::self()` call;
3. one generated process-reference output-commit assignment;
4. the semantically marked named-disable queue push; and
5. the source branch body.

The launch checkpoint had recognized only the direct call-output form. The
hotfix accepts exactly one optional, non-timing output-commit assignment and
validates that its source is the `self()` result and its destination is the
sole process-reference argument to the marked queue push. It then hoists the
comment, call, optional commit, and push together, rebinds the call to the
precreated branch process, and preserves the invariant that no marked queue
push remains in the child prefix. It deliberately does not accept a general
alias chain or match generated identifier text.

This is a one-file compiler hotfix in `src/V3SchedTiming.cpp`. It changes no
runtime ABI and does not widen the named sequential task/begin claim. The
remaining general sequential-disable work still requires source-process
activation tokens rather than synthetic process wrappers.

### Exact clean build and validation

The exact autoformatted remote tree was archived before bootstrap:

- Tree: `0c6a891e3c833e08366d606f0664dc452312f88e`
- Source archive SHA-256:
  `a176acd529f8946ababd12ccfbcc12f5e6b9376c9d098c552e06872501fe5045`
- Pre-build object state: zero `.o`, `.d`, or `.gch` files
- Build command: `make -C src opt -j8 OBJCACHE=`
- Build result: pass, 163 objects
- Wall/user/system: 121.129 s / 666.082 s / 43.843 s
- Peak resident set: 619,984 KiB
- Compiler version:
  `Verilator 5.051 devel rev vUNKNOWN-built20260807-0546f03f4`
- Compiler binary size: 18,912,416 bytes
- Compiler SHA-256:
  `052e5596bfcda17026dcd9748ae759ecc02de2aee1be0f579b6a17ffa77204ad`

The version string names the local tree-equivalent commit; the archived tree
hash, source archive hash, and binary hash are the exact source and compiler
provenance. The build reused only generated configure/parser infrastructure
because this container lacks `autoconf` and `flex`; every configure,
Makefile, and generated-grammar input was first verified byte-identical to the
source state that produced it. No compiled object was reused.

All 20 requested harness checks passed against that from-zero compiler:

- `t_disable_task_join`
- `t_disable_task_by_name`
- `t_disable_fork_launch`
- `t_disable_fork1`
- `t_disable_fork2`
- `t_disable_fork3`
- `t_disable_fork_nested`
- `t_disable_inside`
- `t_disable_outside`
- `t_fork_join_none_stmt`
- `t_process_tree_ownership`
- `t_process_context_fork`
- `t_process_fork_block`
- `t_process_fork_finished`
- `t_process_phase_teardown`
- `t_timing_fork_join`
- `t_wait_fork`
- `t_dist_cppstyle`
- `t_dist_whitespace`
- `t_dist_copyright`

A direct multithreaded-codegen/debug-check run also passed:

```sh
bin/verilator --binary --timing --threads 2 --debug-check \
  --Mdir "$hotfix_mt_dir" --top-module t \
  test_regress/t/t_disable_task_join.v
"$hotfix_mt_dir/Vt"
```

It reported two runtime threads and reached `$finish` at 94 ps. The tracked
tree stayed clean throughout bootstrap, build, and validation. Concise local
evidence is retained under `/tmp/hotfix-tree-0c6a-evidence/`; generated objects
and logs are not repository content.

The semantic GitHub Actions run is
<https://github.com/phoenix-hacking/verilator-uvm-extend/actions/runs/31183497819>.
At this recording time, its Ubuntu 22/24/26 GCC builds, Ubuntu 24 clang build,
Ubuntu 26 clang/ASAN build, macOS GCC and clang builds, and Python lint were
green. The Linux regression shards and Windows build were still running or
queued, so current-head CI is explicitly pending rather than claimed green.
The separate Contributor Agreement failure is expected pending human DCO
certification; the agent did not add a `Signed-off-by` line.

### Standards anchor and claim boundary

IEEE Std 1800-2012, 9.3.2, printed page 175, defines concurrent fork branch
execution and the three join modes. Clause 9.6.2, printed pages 190-192,
requires named parallel-block disable to terminate all activities enabled
within the block. Precreating every real fork branch and preregistering it
before any eager branch call is necessary to satisfy those rules at time zero.

This hotfix proves that the preregistration transform also handles the
one-assignment task-output form produced by the existing compiler pipeline. It
does not prove general named sequential task/begin cancellation. In particular,
IEEE 1800-2012 9.6.2 also makes a disable of an inactive sequential target a
no-op, while 9.7, printed pages 193-194, and 18.14, printed pages 503-504,
require preserving source process identity/status and per-thread RNG state.

### Next exact action

Start the runtime-only named-activation/cancelable-suspension foundation from
autoformatted tree `0c6a891e3c83...`. Keep the existing compiler lowering
unchanged in that checkpoint. First prove dynamic registry generations,
recursive/concurrent activation records, aggregate mark-before-callback order,
normal-exit unregister, source-process identity/RNG preservation, and active
activation descendant ownership through a direct runtime regression. Then add
the cancellation-aware one-shot coroutine state needed for delay, event, and
`wait(0)` wake/unwind before replacing the synthetic sequential wrappers.

## 2026-08-07 two-phase fork-launch checkpoint

Recorded at: 2026-08-07T13:17:29Z

### Published state

- Repository: `phoenix-hacking/verilator-uvm-extend`
- Draft pull request: <https://github.com/phoenix-hacking/verilator-uvm-extend/pull/41>
- Branch: `agent/uvm2020-clean-lane`
- Parent: `f5d010120de4e62032c7378137250530c565878f`
- Functional commit: `ab4abf18b32ff68941e3255c66239fc82d7a28ae`
- Functional tree: `5374accca8f9abf30f478fd643ca9974622aa2e4`
- Autoformat-only child: `881e7c075df2d2a7238036dfeef24a706fbee168`
- Autoformatted tree: `9eefa37da928b2ddd3c759059e47cc3bbb265371`
- Remote verification:
  `git ls-remote origin refs/heads/agent/uvm2020-clean-lane` returned
  `881e7c075df2d2a7238036dfeef24a706fbee168`.
- The local functional commit was `974cb1271055f03864709613cf294f292e4f923a`
  with the same functional tree. The connected GitHub app created the exact
  three blobs and exact tree, parented it to the verified remote head, and
  advanced the branch without force. GitHub's formatter child changes only C++
  layout and the new Python driver's mode from `100644` to `100755`.

### Scope and claim boundary

The functional checkpoint contains three files and 336 insertions. It:

- pre-allocates every process-backed branch handle before invoking any fork
  coroutine, because timing coroutines start eagerly;
- preserves the SystemVerilog process forest by using
  `VlProcess::createChild(vlProcess)` when the enclosing process is represented,
  and creates independent roots only where no source parent process exists;
- hoists every compiler-generated named-disable queue registration so all named
  fork branches are visible before any zero-time branch can drain the queue;
- hoists every `join`/`join_any` kill hook after all registrations but before all
  branch calls, and asserts that every blocking process-backed branch supplied a
  hook;
- guards branch coroutine entry so a process killed during setup cannot execute
  declarations, user statements, or a second completion path; and
- recognizes registration groups by the queue's semantic `processQueue` marker,
  the producer/value dataflow, and the standard process class rather than by a
  generated identifier.

The compiler emits setup in this order: existing fork initialization, every
process assignment, every named-disable registration, every kill hook, and only
then the branch calls. No public runtime ABI or runtime file changes in this
checkpoint.

This closes the zero-time launch race for real fork branches, including named
parallel blocks under `join`, `join_any`, and `join_none`. It does not implement
general named sequential begin/task cancellation. Those bodies must remain in
their source process and control-flow scope; a synthetic process wrapper is
still rejected because it changes process identity/RNG/status/`wait fork` and
strands outward `return`, `break`, and `continue` targets.

### Build and test provenance

The isolated incremental optimized compiler root was
`/tmp/verilator-fork-launch-build`. It started as a reflink of the verified
process-tree build at parent `f5d010120de4e62032c7378137250530c565878f`, then
overlaid the changed files. The final rebuild used the exact autoformatted
`V3SchedTiming.cpp` blob from tree `9eefa37da928b2ddd3c759059e47cc3bbb265371`.

- Version:
  `Verilator 5.051 devel rev vUNKNOWN-built20260807-20075c4 (mod)`
- Final binary SHA-256:
  `638064ca88f7c69212f7308f52e4a09b2228d0c2e14314b5bc21240da8442e21`
- Rebuild command:

```sh
make -C src opt -j8 OBJCACHE= LDFLAGS= LIBS='-lpthread -latomic -lm'
```

This was an incremental rebuild of the changed compiler unit, not a clean
current-head build. A clean exact-head compiler and the full regression remain
required before promotion.

The final self-checking regression was also compiled against the unpatched
parent compiler:

```sh
fork_base_dir=$(mktemp -d /tmp/verilator-fork-baseline-final.XXXXXX)
/tmp/verilator-process-forest-build/bin/verilator \
  --binary --timing --debug-check --Mdir "$fork_base_dir" --top-module t \
  test_regress/t/t_disable_fork_launch.v
"$fork_base_dir/Vt"
```

That run exited 1 at the named-`join` conditional-entry assertion with
`got=1 exp=0`: the first branch disabled the only registered process, then the
old eager launch created and ran a later victim. This is the direct behavioral
red for the patch.

The exact autoformatted checkpoint passed the harness in debug-check mode:

```sh
cd /tmp/verilator-fork-launch-build/test_regress
VERILATOR_ROOT=/tmp/verilator-fork-launch-build \
PYTHONPATH=/tmp/uvm_run_shim \
/workspace/scratch/965baf652559/artifacts/test-venv/bin/python \
  t/t_disable_fork_launch.py --driver-build-jobs=1 \
  --obj-suffix=-forklaunch-auto
```

It also passed a direct multithreaded-codegen run:

```sh
fork_mt_dir=$(mktemp -d /tmp/verilator-fork-auto-mt.XXXXXX)
bin/verilator --binary --timing --threads 2 --debug-check \
  --Mdir "$fork_mt_dir" --top-module t \
  test_regress/t/t_disable_fork_launch.v
"$fork_mt_dir/Vt"
```

Both runs printed `*-* All Finished *-*` at 2 ps; the latter reported two
runtime threads. The focused matrix checks:

- parent-side `disable fork` after a zero-time `join_any` winner;
- child-side `disable fork` leaving its sibling alive;
- named `join`, `join_any`, and `join_none` self-disable at time zero;
- no entry after disable for delayed and zero-time victims;
- no disabler fallthrough; and
- correct parent resumption time and completion bookkeeping.

The following fresh neighbor regressions passed on the functional sources; the
formatter child is semantic-only formatting and the focused test was rerun on
that exact child:

- `t_disable`
- `t_disable_inside`
- `t_disable_fork1`
- `t_disable_fork2`
- `t_disable_fork3`
- `t_disable_task_join`
- `t_fork_join_none_stmt`
- `t_timing_fork_join`
- `t_process_fork_finished`
- `t_process_phase_teardown`
- `t_process_tree_ownership`

Static/distribution evidence passed:

- `git diff --check`
- Python source compilation without writing bytecode
- `t_dist_cppstyle`
- `t_dist_whitespace`
- `t_dist_copyright`
- `t_dist_portability`
- `t_dist_untracked`

Local `nodist/verilog_format` could not start because
`verible-verilog-format` is absent; GitHub's formatter subsequently formatted
the published checkpoint. `make lint-py` and `make cppcheck` were attempted in
the isolated configured build but its regenerated Makefile path requires the
absent `autoconf`; the underlying `pylint`, `ruff`, `mypy`, and `cppcheck`
binaries are also absent. These are environment blocks, not passes. Current-head
GitHub Actions and the complete `uvm2020` lane are pending.

### Standards anchor

IEEE Std 1800-2012, 9.3.2, printed page 175, defines fork branch concurrency
and the `join`, `join_any`, and `join_none` parent rules. In particular,
`join_none` children do not start until the parent blocks or terminates. Clause
9.6.2, printed pages 190-192, requires a named block disable to terminate the
block and all activities enabled within it, then resume after the block. Clause
9.6.3, printed page 192, limits `disable fork` to descendants of the calling
process; it does not let one child kill a sibling. The regression keeps those
two disable scopes distinct.

### Next exact action

Start from autoformatted head `881e7c075df2...`. First perform a clean optimized
compiler build and rerun the focused and neighboring lanes from that exact
source. Then implement dynamic activation tokens for named sequential tasks and
begins without moving their bodies into synthetic fork processes. Required
coverage remains concurrent and recursive activations, per-object/per-instance
ownership, cancellation through delay/event/`wait(0)`, detached `join_none`
children, outward task/function return and loop break/continue, and preserved
process identity/RNG/status.

## 2026-08-07 process-tree ownership checkpoint

Recorded at: 2026-08-07T12:27:57Z

### Published state

- Repository: `phoenix-hacking/verilator-uvm-extend`
- Draft pull request: <https://github.com/phoenix-hacking/verilator-uvm-extend/pull/41>
- Branch: `agent/uvm2020-clean-lane`
- Parent: `fb04ec4b9959fc9295d3806770d1ff35dc50cf1a`
- Functional commit: `8b8ccbd28efe2168a32ae3a17dac940cf6aaa28b`
- Functional tree: `755028cc9a1edf39e29b2bd7ac7f898a22e5399b`
- Autoformat-only child: `5fc3a9265928a892b5530e16cf26b722be5a4d11`
- Autoformatted tree: `13edf0b01f3968400ca4ab1ee6fee283c008da09`
- Remote verification:
  `git ls-remote origin refs/heads/agent/uvm2020-clean-lane` returned
  `5fc3a9265928a892b5530e16cf26b722be5a4d11`.
- The local implementation commit was `b928a306e...` with tree
  `755028cc9a1e...`. The connected GitHub app created `8b8ccbd28e...` with
  that exact tree and parent, then advanced the branch without force. GitHub's
  formatter created `5fc3a92659...`; its diff contains formatting plus the
  executable-bit correction for the new Python driver. The direct regression
  passed again against the autoformatted runtime sources.

### Scope and claim boundary

This checkpoint contains seven files, 376 insertions, and 49 deletions before
the formatter-only child. It:

- makes each process own its child subtrees strongly while children reference
  parents weakly, avoiding both premature destruction and ownership cycles;
- retains a terminal immediate child until its whole subtree is terminal;
- keeps `wait fork` based on immediate-child state while recursive disable still
  traverses through a finished child to live descendants;
- marks the full disabled forest before releasing the topology lock or invoking
  any fork-sync callback;
- retains process and callback state through callback delivery;
- makes terminal state win over later nonterminal state transitions; and
- emits `VlProcess::createChild(vlProcess)` for generated child coroutines.

`VlProcess::createChild` and `VlForkSync::onKill` setup are explicitly
`VL_MT_UNSAFE`: generated scheduling must not overlap child/hook setup with
kill or completion on the same structures. The mutex and atomics protect tree
transitions and callback ordering; this checkpoint does not claim arbitrary
host-thread mutation safety. Moving the internal child constructor behind the
factory is an intentional source-API change to compiler-internal runtime
machinery.

Named fork registration and named sequential begin/task cancellation are not in
this checkpoint.

### Build and test provenance

The clean optimized compiler build root was
`/tmp/verilator-process-forest-build`. Its functional source tree was
`755028cc9a1edf39e29b2bd7ac7f898a22e5399b`; the later autoformat child does not
change compiler semantics.

- Version:
  `Verilator 5.051 devel rev vUNKNOWN-built20260807-20075c4 (mod)`
- Binary SHA-256:
  `e37ff6ddc840e927e0f22facda67453a2222ae54deda2f6aaf7cbbf39e989bc5`
- Build command:

```sh
make -C src/obj_opt -f ../Makefile_obj clean
make -C src opt -j8 OBJCACHE= LDFLAGS= LIBS='-lpthread -latomic -lm'
```

As in the preceding checkpoint, the five generated parser/lexer files were
copied from the exact configured parent build and timestamp-refreshed after
`clean`, because the isolated configure state uses `LEX=true` and `YACC=true`
without flex or bison installed.

The focused regression command was:

```sh
cd /tmp/verilator-process-forest-build/test_regress
VERILATOR_ROOT=/tmp/verilator-process-forest-build \
PYTHONPATH=/tmp/uvm_run_shim \
/workspace/scratch/965baf652559/artifacts/test-venv/bin/python \
  t/t_process_tree_ownership.py --driver-build-jobs=1 \
  --obj-suffix=-forest-autoformat
```

It passed with `PROCESS_TREE_OWNERSHIP_SENTINEL pass=1`. The direct C++ portion
proves:

- retention and release of a `wait(0)` child after its local handle is gone;
- immediate-child completion with a live grandchild;
- bottom-up release without a shared-pointer cycle;
- recursive disable through both running and finished ancestors;
- KILLED state on the descendant below a finished ancestor;
- all targets marked before the first kill callback resumes; and
- exactly one completion when a kill hook is installed after termination.

The SystemVerilog portion is behavioral compiler evidence. An automatic task
launches a `join_none` child that blocks in `wait(0)` and returns, destroying
the task-local fork state; its caller then executes `wait fork`. The previous
published compiler/runtime exited at the test's `$stop` because `wait fork`
returned. The ownership build kept the child alive, observed
`waiter_started == 1`, and correctly left the caller blocked.

The following fresh neighbor tests passed against the ownership build:

- `t_wait_fork`
- `t_disable_fork1`
- `t_disable_fork2`
- `t_disable_fork_nested`
- `t_process_fork_finished`
- `t_process_context_fork`
- `t_process_self_kill_initial`
- `t_process_phase_teardown`

Static/distribution evidence also passed:

- `git diff --check`
- Python source compilation without writing bytecode
- a direct C++14/no-timing compile of `include/verilated.cpp`
- `t_dist_cppstyle`
- `t_dist_whitespace`
- `t_dist_header_cc`

Current-head GitHub Actions and the complete `uvm2020` lane are pending. Do not
attribute the preceding head's CI results to this checkpoint.

### Standards anchor

IEEE Std 1800-2012, 9.6.1, printed page 189, specifies that `wait fork` waits
for all immediate child subprocesses, excluding descendants. IEEE Std
1800-2012, 9.3.2, printed page 175, owns fork/join process creation and
completion. This checkpoint separates that immediate-child completion rule
from the runtime ownership needed to retain a finished child's live subtree.

### Remaining named-disable design

Do not revive the transparent synthetic-process wrapper for sequential named
begins or tasks. It changes source process identity, RNG, status, `wait fork`,
and `disable fork`, and it strands legal `return`, `break`, and `continue`
targets across generated coroutine CFuncs. The sequential design needs one
dynamic activation token per invocation while the source body stays in its
original process and control-flow scope.

Named fork remains process-based, but branch-local registration is too late.
Fork coroutines start eagerly and serially, so a zero-time first branch can
execute `disable fork` or disable the named fork before later branch processes
exist. The next compiler checkpoint must use two-phase launch: create all branch
processes, register tree roots and kill callbacks, then invoke the branch
coroutines with killed-entry guards.

Required sequential-activation coverage includes concurrent and recursive
automatic-task activations, two module/class instances, cancellation through
delay/event/`wait(0)`, live `join_none` descendants, outward task/function
return, enclosing-loop break/continue, process identity/RNG/status, and local
disable canceling all concurrent activations of the same named begin.

### Next exact action

Start from autoformatted head `5fc3a9265928...`. Add the zero-time fork-launch
matrix first, covering plain `disable fork` and named fork under `join`,
`join_any`, and `join_none`. Implement and publish the two-phase real-branch
launch independently. Then introduce the sequential activation-token runtime
and compiler markers without moving begin/task bodies into synthetic processes.

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
