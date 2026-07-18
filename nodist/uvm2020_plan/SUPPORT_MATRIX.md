# UVM 2020 Support Matrix

This matrix tracks support evidence for the UVM 2020 execution plan. It is
developer planning data, not user documentation.

Progress bars use the scale in `PLAN.md`.

Objective alignment:

| Evidence layer | Plan stage | Matrix sections |
|---|---|---|
| Baseline and source-tree reality | S0 | Known static risks, update contract, existing UVM smoke references. |
| SystemVerilog semantics | S1 | IEEE 1800 Semantic Matrix. |
| UVM API correctness | S2 | IEEE 1800.2 UVM Matrix. |
| UVM testbench idioms | S3 | Cookbook Workload Matrix. |
| Protocol verification | S4 | Protocol And SoC Matrix APB/AXI-lite rows. |
| SoC verification pressure | S5 | Protocol And SoC Matrix synthetic SoC rows. |
| Professional support envelope | S6 | Known static risks, update contract, CI/performance/dashboard rows. |

## Competitive Claim Matrix

This table defines what "competitive" means for this plan. It is intentionally
shorter than full IEEE 1800 parity: the first competitive claim is a proven UVM
2020 SoC verification envelope with documented limits.

| Claim | Progress | Required proof | Blocking gaps |
|---|---:|---|---|
| C0 tracked | `[##########] 100%` | PLAN.md, MATRIX.md, tracker.yaml, issue tree, and GitHub issues define the envelope. | None for tracking; implementation remains 0%. |
| C1 usable UVM core | `[####------] 40%` | UVM package/API tests plus scheduler, class, VIF, randomize, and coverage reduced tests. | UVM smoke capabilities, first class/factory-adjacent reduced shard, minimal UVM object factory API, typed config object/component flow, and virtual interface config DB flow pass; scheduler, clocking, randomize, coverage, resource precedence, TLM, and sequence shards are still missing. |
| C2 protocol competitive | `[----------] 0%` | APB and AXI-lite UVM environments pass with scoreboards, coverage, assertions, and RAL frontdoor. | Missing protocol agent proof or missing RAL/coverage path. |
| C3 SoC competitive | `[----------] 0%` | Synthetic SoC regression passes with multi-agent random traffic, reset/IRQ/DMA/RAL/DPI/coverage/performance. | Any unbounded performance, seed replay, CI, or undocumented limitation gap. |

## Advanced Parity Matrix

These items are tracked so the project does not overclaim "full SystemVerilog"
support. They do not block C1-C3 unless a target UVM or SoC workload requires
them.

| Area | Priority | Progress | Competitive handling | Full-parity path |
|---|---|---:|---|---|
| Gate/UDP/specify/SDF/timing-check behavior | P2 | `[----------] 0%` | Out of first competitive UVM target unless a workload depends on it. | Add focused tests or known limitations under M18. |
| Full PLI/VPI/debug database parity | P1/P2 | `[----------] 0%` | Support practical UVM HDL/backdoor subset first. | Expand VPI coverage under M14/M18. |
| Four-state commercial-simulator parity | P2 | `[----------] 0%` | Define two-state/X-initial strategy for UVM regressions. | Track divergence tests and documented limits under M18. |
| Complete SVA language/API parity | P1/P2 | `[----------] 0%` | Prove APB/AXI-lite protocol assertion subset first. | Expand assertion matrix under M15/M18. |
| Coverage API/UCIS parity | P2 | `[----------] 0%` | Prove practical covergroup sampling/report dashboards first. | Add UCIS/export/API tests under M10/M18. |
| Exotic constraint forms | P1/P2 | `[----------] 0%` | Prioritize UVM sequence-item constraints and seed replay. | Add unsupported-form tests/limits under M09/M18. |
| Transaction recording/database parity | P2 | `[----------] 0%` | Treat reporting/debug usability as P1; recording parity is optional. | Add recording tests or limitations under M03/M18. |

## IEEE 1800 Semantic Matrix

| Clause | Priority | UVM dependency | Progress | Verilator anchors | First proof |
|---|---|---|---:|---|---|
| 3 design and verification building blocks | P0 | packages, programs, modules, interfaces, checkers | `[####------] 40%` | parser, `V3LinkParse`, `V3LinkDot` | UVM-CONFIG-VIF-0001 passed virtual interface handle propagation and live interface field access; generic interfaces/checkers remain open. |
| 4 scheduling semantics | P0 | phasing, objections, TLM, driver/monitor timing | `[----------] 0%` | `V3Sched.cpp`, `V3SchedTiming.cpp`, `V3Timing.cpp` | zero delay, reactive/observed/NBA order. |
| 5 lexical conventions | P1 | UVM macros, string/report text | `[----------] 0%` | `verilog.l`, preprocessor | macro/string lexical smoke. |
| 6 data types | P0 | class fields, sequence items, RAL data | `[----------] 0%` | `V3Width.cpp`, AST dtype nodes | two-state/four-state documented behavior tests. |
| 7 aggregate data types | P0 | queues, dynamic arrays, associative arrays | `[----------] 0%` | `V3Width.cpp`, `V3EmitC*` | queue/dynamic/assoc method smoke. |
| 8 classes | P0 | factory, components, sequences, RAL | `[####------] 40%` | `V3Class.cpp`, `V3LinkDot.cpp`, `V3EmitC*` | C1 class/factory-adjacent shard passed existing reduced tests, UVM-FACTORY-0001 passed real UVM object factory create/override through base handles, and UVM-CONFIG-0001 passed component construction plus typed config object access; sequences/RAL remain open. |
| 9 processes | P0 | phase processes, sequence threads, kill/stop | `[----------] 0%` | `V3Timing.cpp`, `V3Fork.cpp`, `verilated_timing.*` | fork/join/process::kill smoke. |
| 10 assignments | P0 | class tasks driving DUT, NBA behavior | `[----------] 0%` | `V3Width.cpp`, `V3Delayed.cpp`, `V3Sched*` | blocking/NBA through class task and VIF. |
| 11 operators and expressions | P0 | constraints, RAL masks, coverage bins | `[#---------] 10%` | `V3Width.cpp`, `V3Const.cpp`, `V3Randomize.cpp` | Initial `t_castdyn.py` dynamic-cast smoke passed inside C1-CLASS-0001; broader expression and constraint-linked cases remain open. |
| 12 procedural statements | P0 | build/connect code, driver loops | `[----------] 0%` | parser, `V3Width.cpp`, `V3Timing.cpp` | loop, foreach, wait, disable smoke. |
| 13 tasks and functions | P0 | UVM methods and driver tasks | `[----------] 0%` | `V3Task.cpp`, `V3Timing.cpp`, `V3EmitCFunc.cpp` | virtual task, suspendable method, DPI-export limits. |
| 14 clocking blocks | P0 | protocol agents and monitors | `[----------] 0%` | `V3AssertPre.cpp`, `V3Width.cpp`, `V3Sched*` | VIF clocking drive/sample. |
| 15 interprocess synchronization | P0 | UVM events, barriers, semaphores, mailboxes | `[----------] 0%` | parser/link/runtime as needed | event/mailbox/semaphore reduced tests. |
| 16 assertions | P1 | protocol assertions, end-of-test checks | `[----------] 0%` | `V3Assert.cpp`, `V3AssertNfa.cpp`, `V3AssertPre.cpp` | APB/AXI-lite assertion subset. |
| 17 checkers | P1 | reusable protocol checks | `[----------] 0%` | parser/link/assertion passes | checker smoke or limitation. |
| 18 constrained randomization | P0 | sequence item generation | `[----------] 0%` | `V3Randomize.cpp`, `verilated_random.*` | rand fields, inline constraints, arrays, seed replay. |
| 19 functional coverage | P0/P1 | subscribers, coverage closure | `[----------] 0%` | `V3Covergroup.cpp`, `verilated_covergroup.*` | class covergroup subscriber and coverage report. |
| 20 utility system tasks/functions | P0 | UVM reports, plusargs, finish/stop | `[----------] 0%` | system task handling, runtime | report/finish/plusargs smoke. |
| 21 I/O and command-line input | P0 | UVM command-line processor | `[----------] 0%` | runtime plusargs, file I/O | `+UVM_TESTNAME`, verbosity, file I/O smoke. |
| 22 compiler directives | P0 | UVM macros and package guards | `[----------] 0%` | preprocessor | UVM macro expansion and source map proof. |
| 23 modules and hierarchy | P1 | DUT connection and RAL paths | `[----------] 0%` | `V3LinkCells.cpp`, `V3LinkDot.cpp`, VPI | hierarchy and bind path smoke. |
| 24 programs | P1 | legacy verification code | `[----------] 0%` | parser/link/scheduler | program block smoke or limitation. |
| 25 interfaces | P0 | virtual interfaces, modports, clocking | `[----------] 0%` | `V3LinkDotIfaceCapture.cpp`, `V3SchedVirtIface.cpp`, `V3Width.cpp` | VIF, modport, sub-interface, trigger smoke. |
| 26 packages | P0 | `uvm_pkg`, imports, typedefs | `[####------] 40%` | `V3LinkParse.cpp`, `V3Param.cpp` | UVM 2020.3.1 no-DPI and DPI package hello workloads compile/build/run with manual `--build-jobs 1`; default harness resource policy remains open. |
| 27 generate constructs | P1 | parameterized DUT and agent harnesses | `[----------] 0%` | `V3Param.cpp`, `V3LinkDot.cpp` | generate hierarchy in SoC smoke. |
| 28-34 primitives/timing specify/etc. | P2 | limited SoC dependency | `[----------] 0%` | parser/runtime as needed | document unsupported or add specific tests. |
| 35 DPI | P1 | UVM DPI and C reference models | `[###-------] 25%` | DPI runtime, generated C++ | UVM 2020.3.1 DPI hello and DPI HDL API smoke build/run under manual `--build-jobs 1`. |
| 36-38 PLI/VPI | P1/P2 | UVM HDL backdoor, debug, force/release | `[###-------] 25%` | `verilated_vpi.*`, public/forceable attrs | `uvm_hdl_check_path/read/deposit/force/release` smoke reaches `*-* All Finished *-*`; RAL backdoor remains unproven. |
| 39 assertion API | P2 | assertion control/debug | `[----------] 0%` | assertion runtime | assertion API smoke or documented limit. |
| 40 coverage API | P2 | coverage merge/export parity | `[----------] 0%` | coverage runtime/tools | coverage API smoke or documented limit. |

## IEEE 1800.2 UVM Matrix

| Clause/API group | Priority | Progress | First UVM test | Required larger proof |
|---|---|---:|---|---|
| 5 base classes | P0 | `[####------] 40%` | `t_uvm_factory_basic_v2020_3_1_nodpi.py` | `uvm_object_utils`, `type_id::create`, base-handle `$cast`, and object naming pass; clone/compare/print and sequence-item/RAL object proof remain open. |
| 6 reporting | P0 | `[#---------] 10%` | severity, verbosity, file/line | UVM hello and DPI smoke emit expected UVM report summaries; broader verbosity/file routing remains unproven. |
| 7 recording | P2 | `[----------] 0%` | compile smoke or limitation | Transaction recording strategy documented. |
| 8 factory | P0 | `[####------] 40%` | `t_uvm_factory_basic_v2020_3_1_nodpi.py` | Object factory type override, wrapper create, base-handle cast, and `create_object_by_name` pass; component factory and Cookbook overrides remain open. |
| 9 phasing | P0 | `[----------] 0%` | build/connect/run/report, objections | UVM phase ordering and end-of-test in protocol envs. |
| 10 synchronization | P0 | `[----------] 0%` | uvm_event/barrier/semaphore usage | Sequence/driver waits and reset coordination. |
| 11 containers | P0 | `[----------] 0%` | queues, pools, resource DB structures | Config/resource DB and RAL maps. |
| 12 UVM TLM | P0 | `[----------] 0%` | analysis port/export/imp/FIFO | Monitor to scoreboard and predictor. |
| 13 component classes | P0 | `[####------] 40%` | minimal `uvm_test` to child `uvm_component` build/report hierarchy | APB and AXI-lite active/passive agents. |
| 14 sequence classes | P0 | `[----------] 0%` | sequence item randomize, start/stop | Protocol sequences and SoC virtual sequences. |
| 15 sequencer classes | P0 | `[----------] 0%` | get_next_item/item_done | APB/AXI-lite sequencer-driver operation. |
| 16 policy classes | P1 | `[----------] 0%` | comparer/printer/packer smoke | RAL and scoreboard object operations. |
| 17-19 register layer | P1 | `[----------] 0%` | reg/block/model/adapter build | Frontdoor APB/AXI-lite RAL and predictor. |
| Annex B macros | P0 | `[####------] 40%` | `uvm_object_utils` and `uvm_component_utils` in factory/config DB tests | Object macro registration, component macro registration, and type_id flow pass; field macros need dedicated API/workload tests. |
| Annex C config/resource | P0 | `[####------] 40%` | typed object and virtual interface set/get through `uvm_config_db` | `uvm_resource_db`, precedence, wildcard, and Cookbook config flows remain open. |
| Annex D convenience classes | P1 | `[----------] 0%` | selected compile/runtime smoke | Protocol and SoC examples. |
| Annex E test sequences | P1 | `[----------] 0%` | selected RAL built-in sequence smoke | reset/access/bit-bash smoke. |
| Annex F package-scope functionality | P0 | `[####------] 40%` | run_test, report globals, plusargs | UVM 2020.3.1 no-DPI and DPI hello tests run `run_test` and finish with `** UVM TEST PASSED **`. |
| Annex G command-line arguments | P1 | `[#---------] 10%` | `+UVM_TESTNAME`, verbosity, phase trace | `+UVM_NO_RELNOTES` works on DPI hello; complete command-line processor proof remains open. |

## Cookbook Workload Matrix

| Workload | Priority | Progress | Reduced dependency | Acceptance |
|---|---|---:|---|---|
| Testbench build flow | P0 | `[####------] 40%` | classes, factory, config DB | Minimal test creates config object and child component; nested agent env remains open. |
| Build/connect ordering | P0 | `[----------] 0%` | phasing, component hierarchy | Top-down build and bottom-up connect order observed. |
| Virtual interface config DB | P0 | `[####------] 40%` | virtual interface handles and typed config DB | Reduced component retrieves VIF and performs live read/write; driver/monitor agent use remains open. |
| Active/passive agent | P0 | `[----------] 0%` | factory, VIF, sequencer, monitor | Active connects driver/sequencer; passive monitor only. |
| Analysis connections | P0 | `[----------] 0%` | TLM analysis ports/exports | Monitor fans out to scoreboard and coverage. |
| Scoreboards and predictors | P1 | `[----------] 0%` | TLM FIFO, object compare | Expected/actual protocol transactions match. |
| Objections and end-of-test | P0 | `[----------] 0%` | scheduler/process/phasing | Test terminates deterministically. |
| Sequences/items/API | P0 | `[----------] 0%` | randomize, sequencer handshake | Protocol driver receives sequence items. |
| Virtual sequences/sequencer | P1 | `[----------] 0%` | class handles, sequence scheduling | SoC virtual sequence coordinates multiple agents. |
| Driver unidirectional/bidirectional | P0 | `[----------] 0%` | VIF clocking, waits | APB and AXI-lite drivers operate. |
| Arbitration/priority/lock/grab | P1 | `[----------] 0%` | sequencer internals and process waits | Sequence arbitration behaves deterministically. |
| Slave/responder sequences | P1 | `[----------] 0%` | sequencer and TLM | AXI-lite responder handles backpressure. |
| Stimulus signal waits/interrupts | P1 | `[----------] 0%` | events, waits, VIF | SoC interrupt tests coordinate with UVM. |
| Register abstraction layer | P1 | `[----------] 0%` | RAL, protocol agents, TLM | Frontdoor RAL and predictor pass. |
| Functional coverage monitors | P1 | `[----------] 0%` | covergroups in classes | Subscriber coverage samples and reports. |
| Debug/reporting/verbosity | P1 | `[----------] 0%` | reports and source locations | Engineers can triage without generated C++ spelunking. |
| Command-line processor | P1 | `[----------] 0%` | plusargs and UVM globals | Standard `+UVM_*` flags work. |

## Protocol And SoC Matrix

| Target | Priority | Progress | Required components | Acceptance |
|---|---|---:|---|---|
| APB active agent | P0 | `[----------] 0%` | interface, item, config, driver, sequencer | Single read/write and back-to-back transfers pass. |
| APB passive agent | P0 | `[----------] 0%` | monitor, analysis port, coverage | Passive monitor observes bus accurately. |
| APB wait/error support | P0 | `[----------] 0%` | clocking, scoreboard, error item fields | Wait states and PSLVERR behavior pass. |
| APB RAL frontdoor | P1 | `[----------] 0%` | adapter, reg model, slave model | RAL write/read/mirror through APB passes. |
| AXI-lite active master | P0 | `[----------] 0%` | AW/W/B/AR/R channel driver | Ready/valid and single read/write pass. |
| AXI-lite passive monitor | P0 | `[----------] 0%` | monitor and transaction reconstruction | Interleaved read/write observations pass. |
| AXI-lite responder | P1 | `[----------] 0%` | slave responder, backpressure | Backpressure and error response pass. |
| AXI-lite RAL frontdoor | P1 | `[----------] 0%` | adapter, reg model | RAL write/read/mirror through AXI-lite passes. |
| AXI-style SoC smoke | P1 | `[----------] 0%` | outstanding tracking, scoreboard | Multiple outstanding/backpressure smoke passes. |
| Synthetic SoC reset/boot | P1 | `[----------] 0%` | clock/reset, ROM/status | Boot/reset-to-idle and status pass. |
| Synthetic SoC CSR/RAL | P1 | `[----------] 0%` | APB/AXI-lite bridge, RAL model | Reset/access/bit-bash smoke passes. |
| Synthetic SoC DMA | P1 | `[----------] 0%` | DMA stub, memory model, scoreboard | Single and random descriptor memcopy pass. |
| Synthetic SoC interrupts | P1 | `[----------] 0%` | interrupt controller, timer, GPIO | Trigger/clear/nested interrupt tests pass. |
| Synthetic SoC clocks/resets | P1 | `[----------] 0%` | multi-clock agents, async reset | clock ratios and reset-mid-traffic pass. |
| Synthetic SoC coverage | P1 | `[----------] 0%` | functional/protocol/RAL coverage | Coverage report and merge pass. |
| Synthetic SoC DPI | P1 | `[----------] 0%` | C reference/memory model | DPI scoreboard path passes. |
| Synthetic SoC performance | P1 | `[----------] 0%` | perf harness | Long random tests complete without unbounded growth. |

## Known Static Risks

| Risk | Progress | Evidence | Required handling |
|---|---:|---|---|
| Class support is not documented as complete. | `[####------] 40%` | `docs/guide/languages.rst` says limited and active development; C1-CLASS-0001, UVM-FACTORY-0001, and UVM-CONFIG-0001 pass. | Treat every new UVM class failure as suspect until reduced; extend next into VIF config, phasing, TLM, and sequences. |
| Covergroup aggregation is incomplete. | `[----------] 0%` | `src/V3Covergroup.cpp` TODOs for static `get_coverage()` and type aggregation. | Add reduced coverage tests and limitation records. |
| VIF trigger types have unsupported cases. | `[----------] 0%` | `src/V3SchedTrigger.cpp` warns on event/string/chandle and other unsupported types. | Add tests for protocol-relevant members and document gaps. |
| Randomization has many unsupported constraint forms. | `[----------] 0%` | `src/V3Randomize.cpp` has unsupported unique, nested array, complex function cases. | Prioritize sequence-item constraints and record P2 gaps. |
| Timing controls inside DPI-exported tasks are unsupported. | `[----------] 0%` | `src/V3Timing.cpp` emits unsupported warning. | Verify UVM DPI path and document if not needed. |
| Public docs describe assertion support as partial. | `[----------] 0%` | `docs/guide/languages.rst` says assertions are partially supported. | Define and test APB/AXI-lite assertion subset before broad claims. |
| Verilator is mostly two-state. | `[----------] 0%` | `docs/guide/languages.rst` unknown-state section. | Document impact on UVM/SoC tests and add seed/X-initial strategy. |
| Local WSL default UVM package build fanout is unstable. | `[###-------] 25%` | Default no-DPI Python harness attempts using 8 build jobs reset/interrupted WSL during generated C++ build; manual `--build-jobs 1` passed. | Add resource-capped harness/CI lane before treating default local smoke as clean. |

## Update Contract

For every row changed above, update:

| Artifact | Progress | Update requirement |
|---|---:|---|
| `MATRIX.md` | `[##########] 100%` | Human-readable progress and evidence. |
| `tracker.yaml` | `[##########] 100%` | Machine-readable state, result, test names, owner. |
| `PLAN.md` GitHub issue coverage | `[##########] 100%` | Milestone-level issue status, issue number, or blocked repository status. |
| `github_issues/ISSUE_TREE.md` | `[##########] 100%` | Single integrated issue tree with source references, issue body, and live issue link. |
| Known limitation record | `[----------] 0%` | Required for `WAIVED_DOCUMENTED` or P2 deferral. |
| Regression test | `[----------] 0%` | Required before a semantic fix is complete. |
| User docs | `[----------] 0%` | Only after support is implemented and stable. |
