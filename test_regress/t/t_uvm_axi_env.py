#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM AXI4-Lite transport, class coverage, and RAL environment
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

from collections import Counter
import os
import re

import vltest_bootstrap


def read_bins(filename):
    """Check all 27 subscriber bins, including the direction/response cross."""
    bins = {}
    for metadata, count in re.findall(r"C '([^']+)' (\d+)", test.file_contents(filename)):
        fields = dict(
            field.split('\x02', 1) for field in metadata.split('\x01') if '\x02' in field)
        hierarchy = fields.get('h', '')
        if 'transfers.' in hierarchy:
            name = hierarchy.split('transfers.', 1)[1]
            if name in bins:
                test.error('Duplicate AXI coverage bin: ' + name)
            bins[name] = int(count)
    if len(bins) != 27:
        test.error('Coverage database did not contain all 27 AXI subscriber bins')
    return Counter(bins)


def execute_negative(name, flags, pattern, fails=False):
    logfile = test.obj_dir + '/' + name + '.log'
    test.execute(all_run_flags=[
        '+UVM_NO_RELNOTES', '+verilator+coverage+file+' + test.obj_dir + '/' + name + '.dat',
        *flags
    ],
                 logfile=logfile,
                 fails=fails)
    test.file_grep(logfile, pattern)
    test.file_grep_count(logfile, r'^\*\* UVM AXI ENV PASSED \*\*$', 0)


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
        # Clocking and covergroup lowering currently reports generated
        # unused members, hidden sample arguments and an undriven __Vint.
        '-Wno-UNUSEDSIGNAL -Wno-VARHIDDEN -Wno-UNDRIVEN',
        '--assert --coverage-user',
        *test.uvm2020_flags(),
    ])

traces = []
coverage_files = []
bin_counts = []
for run_number, seed in enumerate((1729, 1729, 2718)):
    log = test.obj_dir + '/replay_' + str(run_number) + '.log'
    coverage_file = test.obj_dir + '/replay_' + str(run_number) + '.dat'
    test.execute(all_run_flags=[
        '+UVM_NO_RELNOTES', '+verilator+seed+' + str(seed),
        '+verilator+coverage+file+' + coverage_file
    ],
                 logfile=log)
    test.file_grep_count(log, r'^\*\* UVM AXI ENV PASSED \*\*$', 1)
    test.file_grep_count(log, r'^AXI_SENTINEL reads=1266 writes=1202 errors=4 resets=5 ', 1)
    test.file_grep_count(
        log, r'^AXI_RAL_SENTINEL registers=16 reads=1120 writes=1152 '
        r'resets=3 backdoor_reads=32 backdoor_writes=16$', 1)
    # AXI defines ordering within each direction, without ordering read vs write.
    lines = test.file_contents(log).splitlines()
    trace = tuple(
        tuple(line for line in lines if line.startswith('AXI_TRACE ' + direction))
        for direction in ('W', 'R'))
    if tuple(map(len, trace)) != (1202, 1266):
        test.error('Replay did not record every completed AXI transaction')
    traces.append(trace)
    expected = Counter()
    for direction_trace in trace:
        for line in direction_trace:
            _, direction, _, _, strobes, response, order = line.split()
            wr = int(direction == 'W')
            err = int(response != '0')
            expected['direction.auto_' + str(wr)] += 1
            expected['response.auto_' + str(err)] += 1
            expected['outcome.auto_' + str(wr) + '_x_auto_' + str(err)] += 1
            if wr:
                expected['byte_enables.masks[' + str(int(strobes, 16)) + ']'] += 1
                expected['channel_order.orders[' + order + ']'] += 1
    actual = read_bins(coverage_file)
    if actual != expected:
        test.error('AXI coverage bins did not match independent driver handshakes: ' +
                   repr((actual, expected)))
    coverage_files.append(coverage_file)
    bin_counts.append(actual)
if traces[0] != traces[1]:
    test.error('Identical seeds did not replay the same AXI traffic')
if traces[0] == traces[2]:
    test.error('Different seeds did not change AXI traffic')

coverage_tool = os.environ['VERILATOR_ROOT'] + '/bin/verilator_coverage'
merged = test.obj_dir + '/merged.dat'
test.run(cmd=[coverage_tool, '--write', merged, coverage_files[0], coverage_files[2]])
if read_bins(merged) != bin_counts[0] + bin_counts[2]:
    test.error('Merged AXI coverage did not sum the independent seed bin counts')
test.run(cmd=[coverage_tool, '--write-info', test.obj_dir + '/coverage.info', merged])
test.file_grep(test.obj_dir + '/coverage.info', r'SF:.*t_uvm_axi_env.v')

execute_negative('corrupt_data', ['+AXI_CORRUPT_DATA'],
                 r'UVM_FATAL .*\[AXI_SCOREBOARD\].*read mismatch')

# Independently establish SVA and monitor oracles against the same real faults.
# Assertions remain enabled in every positive run.
execute_negative('corrupt_sva', ['+AXI_CORRUPT_PROTOCOL'], r'AXI_SVA_R_STABLE', fails=True)
execute_negative('corrupt_monitor', ['+AXI_CORRUPT_PROTOCOL', '+AXI_MONITOR_ONLY'],
                 r'UVM_FATAL .*\[AXI_PROTOCOL\].*R payload changed')
execute_negative('corrupt_reset_sva', ['+AXI_CORRUPT_RESET'], r'AXI_SVA_RESET_VALID', fails=True)
execute_negative('corrupt_reset_monitor', ['+AXI_CORRUPT_RESET', '+AXI_MONITOR_ONLY'],
                 r'UVM_FATAL .*\[AXI_PROTOCOL\].*VALID was asserted during reset')
# The bus and predictor observe correct data, but RAL receives a corrupt response.
# This proves the frontdoor response oracle independently of the bus scoreboard.
execute_negative('corrupt_ral_response', ['+AXI_CORRUPT_RAL_RESPONSE'],
                 r'UVM_FATAL .*\[AXI_RAL_VALUE\].*frontdoor read')
test.passes()
