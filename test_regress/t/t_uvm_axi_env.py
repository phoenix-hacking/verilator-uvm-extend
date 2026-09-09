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
from uvm_protocol_common import compare_faults, first_violation, samples, verify_positive


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
    logfile = test.obj_dir + ('/dpi_' if dpi else '/nodpi_') + name + '.log'
    test.execute(all_run_flags=[
        '+UVM_NO_RELNOTES', '+verilator+seed+1729', '+verilator+coverage+file+' + test.obj_dir +
        ('/dpi_' if dpi else '/nodpi_') + name + '.dat', *flags
    ],
                 logfile=logfile,
                 fails=fails)
    test.file_grep(logfile, pattern)
    test.file_grep_count(logfile, r'^\*\* UVM AXI ENV PASSED \*\*$', 0)
    return test.file_contents(logfile)


test.priority(50)
test.scenarios('vlt', 'vltmt')
test.timeout(600)

for dpi in (False, True):
    prefix = test.obj_dir + ('/dpi_' if dpi else '/nodpi_')
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
            *test.uvm2020_flags(dpi=dpi),
        ])

    traces = []
    coverage_files = []
    bin_counts = []
    for run_number, seed in enumerate((1729, 1729, 2718)):
        log = prefix + 'replay_' + str(run_number) + '.log'
        coverage_file = prefix + 'replay_' + str(run_number) + '.dat'
        test.execute(all_run_flags=[
            '+UVM_NO_RELNOTES', '+AXI_PROTOCOL_TRACE', '+verilator+seed+' + str(seed),
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
        verify_positive(test.file_contents(log), 'AXI')
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
    merged = prefix + 'merged.dat'
    test.run(cmd=[coverage_tool, '--write', merged, coverage_files[0], coverage_files[2]])
    if read_bins(merged) != bin_counts[0] + bin_counts[2]:
        test.error('Merged AXI coverage did not sum the independent seed bin counts')
    test.run(cmd=[coverage_tool, '--write-info', prefix + 'coverage.info', merged])
    test.file_grep(prefix + 'coverage.info', r'SF:.*t_uvm_axi_env.v')

    execute_negative('corrupt_data', ['+AXI_CORRUPT_DATA'],
                     r'UVM_FATAL .*\[AXI_SCOREBOARD\].*read mismatch')

    # Every declared hold rule is exercised by both a payload fault and VALID
    # withdrawal. Both oracles see the same real sampled signals and failure cycle.
    for channel in ('AW', 'W', 'B', 'AR', 'R'):
        for fault in ('PAYLOAD', 'VALID', 'RESET'):
            name = channel.lower() + '_' + fault.lower()
            flags = [
                '+AXI_PROTOCOL_TRACE', '+AXI_CORRUPT_' +
                ('RESET_' + channel if fault == 'RESET' else channel + '_' + fault)
            ]
            rule = 'RESET_VALID' if fault == 'RESET' else channel + '_STABLE'
            sva_text = execute_negative('corrupt_' + name + '_sva', [*flags, '+AXI_SVA_ONLY'],
                                        r'AXI_SVA_' + rule,
                                        fails=True)
            monitor_text = execute_negative('corrupt_' + name + '_monitor',
                                            [*flags, '+AXI_MONITOR_ONLY'],
                                            r'UVM_FATAL .*\[AXI_PROTOCOL\]')
            compare_faults(sva_text, monitor_text, 'AXI', rule)
            if fault == 'RESET':
                rows = samples(sva_text, 'AXI')
                first, _ = first_violation(rows, 'AXI')
                active = [
                    name for name in ('aw', 'w', 'b', 'ar', 'r') if rows[first][name + 'valid']
                ]
                if active != [channel.lower()]:
                    test.error('Reset fault did not isolate the selected AXI channel')
    # The bus and predictor observe correct data, but RAL receives a corrupt response.
    # This proves the frontdoor response oracle independently of the bus scoreboard.
    execute_negative('corrupt_ral_response', ['+AXI_CORRUPT_RAL_RESPONSE'],
                     r'UVM_FATAL .*\[AXI_RAL_VALUE\].*frontdoor read')

test.passes()
