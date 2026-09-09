#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM constrained-random traffic and deterministic replay
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import re

import vltest_bootstrap


def checked_trace(log):
    """Check transaction constraints and payload checksum independently of SV."""
    text = test.file_contents(log)
    if re.search(r'^UVM_(?:ERROR|FATAL) (?!:)', text, re.M):
        test.error('Unexpected UVM error during random sequence replay')
    trace = [line for line in text.splitlines() if line.startswith('UVM_RANDOM_TRACE ')]
    if len(trace) != 64:
        test.error('Replay did not record all 64 completed transactions')
    for ordinal, line in enumerate(trace):
        _, index, address, tag, length, channel, checksum = line.split()
        index, address, tag, length, channel = map(int, (index, address, tag, length, channel))
        if (index != ordinal or not 128 <= address <= 892 or address % 4 or not 1 <= tag <= 200
                or not 1 <= length <= 7 or not 1 <= channel <= min(19, length + 12)):
            test.error('Random transaction violates declared or inline constraints: ' + line)
        expected = address ^ (tag << 16) ^ (length << 8) ^ channel
        for offset in range(length):
            expected = (((expected << 5) | (expected >> 27)) ^
                        ((tag + 3 * offset) & 255)) & 0xffffffff
        if int(checksum, 16) != expected:
            test.error('Random payload checksum disagrees with independent constraint oracle')
    return trace


test.priority(50)
test.scenarios('vlt', 'vltmt')

if not test.have_solver:
    test.skip('No constraint solver installed')

test.timeout(300)
for dpi in (False, True):
    test.compile(v_flags2=[
        '--binary',
        test.build_jobs_groups,
        '--CFLAGS -O0',
        '-Wall',
        *test.uvm2020_flags(dpi=dpi),
    ],
                 threads=2 if test.vltmt else 1)

    traces = []
    for run_number, seed in enumerate((1729, 1729, 2718)):
        mode = 'dpi' if dpi else 'nodpi'
        log = test.obj_dir + '/replay_' + mode + '_' + str(run_number) + '.log'
        test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+verilator+seed+' + str(seed)],
                     logfile=log)
        test.file_grep_count(log, r'^\*\* UVM RANDOM SEQUENCE PASSED \*\*$', 1)
        test.file_grep_count(log, r'^UVM_RANDOM_STATE pre=68 post=67 failures=1$', 1)
        trace = checked_trace(log)
        traces.append(trace)
    if traces[0] != traces[1]:
        test.error('Identical process seeds did not replay the same random traffic')
    if traces[0] == traces[2]:
        test.error('Different process seeds did not change random traffic')

test.passes()
