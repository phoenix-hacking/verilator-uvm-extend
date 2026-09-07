#!/usr/bin/env python3
# DESCRIPTION: Verilator: Full UVM HDL backdoor integration with clocked RTL
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.priority(50)
test.scenarios('vlt', 'vltmt')

if test.have_dev_gcov:
    test.skip('Test suite intended for full dev coverage without needing this test')

test.compile(
    threads=2 if test.vltmt else 1,
    v_flags2=[
        '--binary',
        test.build_jobs_groups,
        '--CFLAGS -O0',
        # Forceable signals change through both clocked RTL and asynchronous DPI.
        '-Wall -Wno-DECLFILENAME -Wno-SYNCASYNCNET',
        *test.uvm2020_flags(dpi=True),
    ])

test.execute(all_run_flags=['+UVM_NO_RELNOTES'])
test.file_grep_count(test.run_log_filename, r'^\*\* UVM HDL BACKDOOR PASSED \*\*$', 1)

# The same oracle must reject a one-bit error in the clocked DUT.
# UVM's default fatal action calls $finish and exits with status zero.
negative_log = test.obj_dir + '/corrupt.log'
test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+BACKDOOR_CORRUPT_DUT'], logfile=negative_log)
test.file_grep(negative_log, r'UVM_FATAL .*\[HDL_BACKDOOR\].*value mismatch')
test.file_grep_count(negative_log, r'^\*\* UVM HDL BACKDOOR PASSED \*\*$', 0)

test.passes()
