#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM synthetic SoC firmware, DMA and reset regression
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import os
import shlex

import vltest_bootstrap
from uvm_soc_common import expected_bins, read_bins, verify_fault, verify_oracle_controls, verify_report, verify_soc

test.priority(50)
test.scenarios('vlt', 'vltmt')
test.timeout(300)

reference_object = os.path.abspath(test.obj_dir + '/soc_reference.o')
test.run(cmd=[
    os.environ.get('CC', 'cc'), '-std=c11 -O0 -Wall -Wextra -Werror', '-c t/t_uvm_soc.c -o',
    shlex.quote(reference_object)
],
         logfile=test.obj_dir + '/reference_compile.log')
for dpi in (False, True):
    test.compile(threads=2 if test.vltmt else 1,
                 v_flags2=[
                     '--binary', test.build_jobs_groups, '--CFLAGS -O0', '-Wall',
                     '--assert --coverage-user', '-Wno-DECLFILENAME', '-Wno-SYNCASYNCNET',
                     '-Wno-UNUSEDSIGNAL', '-Wno-VARHIDDEN', '-Wno-UNDRIVEN',
                     *test.uvm2020_flags(dpi=dpi), *([reference_object] if dpi else [])
                 ])
    mode = 'dpi' if dpi else 'nodpi'
    prefix = test.obj_dir + '/' + mode + '_'
    traces = []
    coverage_files = []
    counts = []
    for ordinal, (seed, jobs) in enumerate(((1729, 4), (1729, 4), (2718, 4), (314159, 9))):
        log = prefix + 'replay_' + str(ordinal) + '.log'
        coverage_file = prefix + 'replay_' + str(ordinal) + '.dat'
        test.execute(all_run_flags=[
            '+UVM_NO_RELNOTES', '+verilator+seed+' + str(seed), '+SOC_JOBS=' + str(jobs),
            '+APB_PROTOCOL_TRACE', '+AXI_PROTOCOL_TRACE',
            '+verilator+coverage+file+' + coverage_file
        ],
                     logfile=log)
        text = test.file_contents(log)
        _, trace = verify_soc(text, dpi, jobs)
        if ordinal == 0:
            verify_oracle_controls(text, dpi, jobs)
        traces.append(trace)
        bins = expected_bins(text)
        if read_bins(coverage_file) != bins:
            test.error('SoC subscriber bins differ from independently checked observations')
        coverage_files.append(coverage_file)
        counts.append(bins)
    if traces[0] != traces[1] or traces[0] == traces[2]:
        test.error('SoC seed replay or seed diversity failed')
    tool = os.environ['VERILATOR_ROOT'] + '/bin/verilator_coverage'
    merged = prefix + 'merged.dat'
    test.run(cmd=[tool, '--write', merged, coverage_files[0], coverage_files[2]])
    if read_bins(merged) != counts[0] + counts[2]:
        test.error('SoC coverage merge did not sum independent seed counts')
    report = prefix + 'coverage.info'
    test.run(cmd=[tool, '--write-info', report, merged])
    verify_report(report, counts[0] + counts[2], test.root + '/test_regress/t/t_uvm_soc.v')
    faults = ['CORRUPT_DATA', 'SUPPRESS_IRQ', 'SPURIOUS_IRQ', 'RESUME_CANCELED']
    if dpi:
        faults.append('CORRUPT_REFERENCE')
    for fault in faults:
        log = prefix + fault.lower() + '.log'
        test.execute(all_run_flags=[
            '+UVM_NO_RELNOTES', '+verilator+seed+1729', '+SOC_' + fault, '+APB_PROTOCOL_TRACE',
            '+AXI_PROTOCOL_TRACE', '+verilator+coverage+file+' + prefix + fault.lower() + '.dat'
        ],
                     logfile=log)
        verify_fault(test.file_contents(log), fault)
test.passes()
