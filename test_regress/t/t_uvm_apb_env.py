#!/usr/bin/env python3
# DESCRIPTION: Verilator: Active/passive UVM APB environment with clocking and reset
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
    """Read the seven subscriber bins, independently of coverage percentages."""
    bins = {}
    for metadata, count in re.findall(r"C '([^']+)' (\d+)", test.file_contents(filename)):
        fields = dict(
            field.split('\x02', 1) for field in metadata.split('\x01') if '\x02' in field)
        hierarchy = fields.get('h', '')
        if 'transfers.' in hierarchy:
            bins[hierarchy.split('transfers.', 1)[1]] = int(count)
    if len(bins) != 7:
        test.error('Coverage database did not contain all seven APB subscriber bins')
    return bins


test.priority(50)
test.scenarios('vlt', 'vltmt')
test.timeout(300)

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
    test.file_grep_count(log, r'^\*\* UVM APB ENV PASSED \*\*$', 1)
    trace = [
        line for line in test.file_contents(log).splitlines() if line.startswith('APB_TRACE ')
    ]
    if len(trace) != 2436:
        test.error('Replay did not record all 2436 completed APB transfers')
    test.file_grep_count(
        log, r'^APB_RAL_SENTINEL registers=16 reads=1120 writes=1152 '
        r'resets=3 backdoor_reads=32 backdoor_writes=16$', 1)
    traces.append(trace)
    expected = Counter()
    for line in trace:
        _, direction, _, _, _, error, waits = line.split()
        expected['direction.auto_' + direction] += 1
        expected['response.auto_' + error] += 1
        expected['wait_states.delays[' + waits + ']'] += 1
    actual = read_bins(coverage_file)
    if actual != expected:
        test.error('Subscriber coverage bin counts did not match completed APB traffic')
    coverage_files.append(coverage_file)
    bin_counts.append(Counter(actual))
if traces[0] != traces[1]:
    test.error('Identical seeds did not replay the same APB transfers')
if traces[0] == traces[2]:
    test.error('Different seeds did not change APB transfers')

coverage_tool = os.environ['VERILATOR_ROOT'] + '/bin/verilator_coverage'
merged = test.obj_dir + '/merged.dat'
test.run(cmd=[coverage_tool, '--write', merged, coverage_files[0], coverage_files[2]])
if read_bins(merged) != bin_counts[0] + bin_counts[2]:
    test.error('Merged coverage did not sum the independent seed bin counts')
test.run(cmd=[coverage_tool, '--write-info', test.obj_dir + '/coverage.info', merged])
test.file_grep(test.obj_dir + '/coverage.info', r'SF:.*t_uvm_apb_env.v')

negative_log = test.obj_dir + '/corrupt.log'
test.execute(all_run_flags=[
    '+UVM_NO_RELNOTES', '+APB_CORRUPT_DUT',
    '+verilator+coverage+file+' + test.obj_dir + '/corrupt.dat'
],
             logfile=negative_log)
test.file_grep(negative_log, r'UVM_FATAL .*\[APB_SCOREBOARD\].*read mismatch')
test.file_grep_count(negative_log, r'^\*\* UVM APB ENV PASSED \*\*$', 0)
for rule in ('setup', 'wait', 'select', 'strobe'):
    negative_log = test.obj_dir + '/corrupt_' + rule + '.log'
    test.execute(all_run_flags=[
        '+UVM_NO_RELNOTES', '+APB_CORRUPT_' + rule.upper(),
        '+verilator+coverage+file+' + test.obj_dir + '/corrupt_' + rule + '.dat'
    ],
                 logfile=negative_log)
    test.file_grep_count(negative_log, '^APB_ASSERTION ' + rule + '$', 1)
    test.file_grep_count(negative_log, r'^\*\* UVM APB ENV PASSED \*\*$', 0)
test.passes()
