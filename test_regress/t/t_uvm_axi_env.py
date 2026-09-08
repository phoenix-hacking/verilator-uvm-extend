#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM AXI4-Lite independent channel and reset environment
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.priority(50)
test.scenarios('vlt', 'vltmt')
test.timeout(600)

test.compile(
    threads=2 if test.vltmt else 1,
    v_flags2=[
        '--binary',
        test.build_jobs_groups,
        '--CFLAGS -O0',
        '-Wall -Wno-DECLFILENAME -Wno-SYNCASYNCNET',
        # Typed clocking modports create currently unreported uses.
        '-Wno-UNUSEDSIGNAL -Wno-UNDRIVEN',
        '--assert',
        *test.uvm2020_flags(),
    ])

traces = []
for run_number, seed in enumerate((1729, 1729, 2718)):
    log = test.obj_dir + '/replay_' + str(run_number) + '.log'
    test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+verilator+seed+' + str(seed)], logfile=log)
    test.file_grep_count(log, r'^\*\* UVM AXI ENV PASSED \*\*$', 1)
    test.file_grep_count(log, r'^AXI_SENTINEL reads=146 writes=50 errors=4 resets=2 ', 1)
    # AXI defines ordering within each direction, without ordering read vs write.
    lines = test.file_contents(log).splitlines()
    trace = tuple(
        tuple(line for line in lines if line.startswith('AXI_TRACE ' + direction))
        for direction in ('W', 'R'))
    if tuple(map(len, trace)) != (50, 146):
        test.error('Replay did not record every completed AXI transaction')
    traces.append(trace)
if traces[0] != traces[1]:
    test.error('Identical seeds did not replay the same AXI traffic')
if traces[0] == traces[2]:
    test.error('Different seeds did not change AXI traffic')

negative_log = test.obj_dir + '/corrupt_data.log'
test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+AXI_CORRUPT_DATA'], logfile=negative_log)
test.file_grep(negative_log, r'UVM_FATAL .*\[AXI_SCOREBOARD\].*read mismatch')
test.file_grep_count(negative_log, r'^\*\* UVM AXI ENV PASSED \*\*$', 0)

# Independently establish the SVA and monitor oracles against the same real
# response instability. Assertions remain enabled in every positive run.
assert_log = test.obj_dir + '/corrupt_sva.log'
test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+AXI_CORRUPT_PROTOCOL'],
             logfile=assert_log,
             fails=True)
test.file_grep(assert_log, r'AXI_SVA_R_STABLE')
test.file_grep_count(assert_log, r'^\*\* UVM AXI ENV PASSED \*\*$', 0)
monitor_log = test.obj_dir + '/corrupt_monitor.log'
test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+AXI_CORRUPT_PROTOCOL', '+AXI_MONITOR_ONLY'],
             logfile=monitor_log)
test.file_grep(monitor_log, r'UVM_FATAL .*\[AXI_PROTOCOL\].*R payload changed')
test.file_grep_count(monitor_log, r'^\*\* UVM AXI ENV PASSED \*\*$', 0)

reset_assert_log = test.obj_dir + '/corrupt_reset_sva.log'
test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+AXI_CORRUPT_RESET'],
             logfile=reset_assert_log,
             fails=True)
test.file_grep(reset_assert_log, r'AXI_SVA_RESET_VALID')
test.file_grep_count(reset_assert_log, r'^\*\* UVM AXI ENV PASSED \*\*$', 0)
reset_monitor_log = test.obj_dir + '/corrupt_reset_monitor.log'
test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+AXI_CORRUPT_RESET', '+AXI_MONITOR_ONLY'],
             logfile=reset_monitor_log)
test.file_grep(reset_monitor_log, r'UVM_FATAL .*\[AXI_PROTOCOL\].*VALID was asserted during reset')
test.file_grep_count(reset_monitor_log, r'^\*\* UVM AXI ENV PASSED \*\*$', 0)
test.passes()
