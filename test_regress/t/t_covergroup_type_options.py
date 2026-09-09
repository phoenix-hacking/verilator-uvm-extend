#!/usr/bin/env python3
# DESCRIPTION: Verilator: Static covergroup options and merged queries
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

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
        test.file_grep(report, r'threshold_cov\.point\.low: 2')
        test.file_grep(report, r'threshold_cov\.point\.high: 2')
test.passes()
