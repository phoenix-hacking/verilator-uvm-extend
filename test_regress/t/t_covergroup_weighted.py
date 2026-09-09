#!/usr/bin/env python3
# DESCRIPTION: Verilator: Weighted covergroup instance coverage
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import shutil

import vltest_bootstrap
import coverage_covergroup_common

test.scenarios('vlt', 'vltmt')

for protect in (False, True):
    test.compile(verilator_flags2=[
        '--coverage-user',
        '--no-timing',
        '-CFLAGS -std=c++14',
        *(['--protect-ids'] if protect else []),
    ],
                 threads=2 if test.vltmt else 1)
    test.execute()
    if not protect:
        report = coverage_covergroup_common.covergroup_coverage_report(test)
        test.file_grep(report, r'plain_cov\.cp_op\.zero: 1')
        test.file_grep(report, r'plain_cov\.cp_op\.high: 2')
        test.file_grep(report, r'plain_cov\.cp_addr\.addresses\[2\]: 0')
        test.file_grep(report, r'legacy_cov\.op_addr\.zero_x_addresses_0 \[cross\]: 1')
        test.file_grep(report, r'legacy_cov\.op_addr\.high_x_addresses_1 \[cross\]: 1')
        test.file_grep(report, r'legacy_cov\.op_addr\.high_x_addresses_2 \[cross\]: 0')
        test.file_grep(report, r'legacy_cov\.op_addr\.high_x_addresses_3 \[cross\]: 1')
        second = test.obj_dir + '/second.dat'
        shutil.copy(test.coverage_filename, second)
        merged = test.obj_dir + '/merged.dat'
        test.run(cmd=[
            os.environ['VERILATOR_ROOT'] + '/bin/verilator_coverage', '--write', merged,
            test.coverage_filename, second
        ],
                 verilator_run=True)
        test.file_grep(merged, r"plain_cov\.cp_op\.zero[^\n]*' 2")
        test.file_grep(merged, r"plain_cov\.cp_op\.high[^\n]*' 4")
        test.file_grep(merged, r"legacy_cov\.op_addr\.high_x_addresses_1[^\n]*' 2")

test.passes()
