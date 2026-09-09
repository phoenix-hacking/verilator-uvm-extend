#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM constrained-random traffic and deterministic replay
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

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
        trace = [
            line for line in test.file_contents(log).splitlines()
            if line.startswith('UVM_RANDOM_TRACE ')
        ]
        if len(trace) != 64:
            test.error('Replay did not record all 64 completed transactions')
        traces.append(trace)
    if traces[0] != traces[1]:
        test.error('Identical process seeds did not replay the same random traffic')
    if traces[0] == traces[2]:
        test.error('Different process seeds did not change random traffic')

test.passes()
