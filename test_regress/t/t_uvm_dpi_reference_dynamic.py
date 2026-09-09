#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM C reference scoreboard with dynamic DPI arrays
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import shlex

test.priority(50)
test.scenarios('vlt', 'vltmt')
test.top_filename = 't/t_uvm_dpi_reference.v'

if test.have_dev_gcov:
    test.skip('Test suite intended for full dev coverage without needing this test')

reference_object = os.path.abspath(test.obj_dir + '/t_uvm_dpi_reference.o')
test.run(cmd=[
    os.environ.get('CC', 'cc'), '-std=c11', '-O0', '-Wall', '-Wextra', '-Werror',
    '-I' + shlex.quote(os.path.abspath(test.root + '/include/vltstd')),
    '-c t/t_uvm_dpi_reference.c', '-o',
    shlex.quote(reference_object)
],
         logfile=test.obj_dir + '/reference_compile.log')

test.compile(threads=2 if test.vltmt else 1,
             v_flags2=[
                 '--binary',
                 test.build_jobs_groups,
                 '--CFLAGS -O0',
                 '-Wall',
                 '+define+DPI_REFERENCE_DYNAMIC',
                 *test.uvm2020_flags(dpi=True),
                 reference_object,
             ])

test.execute(all_run_flags=['+UVM_NO_RELNOTES'])
test.file_grep_count(test.run_log_filename, r'^\*\* UVM DPI REFERENCE PASSED \*\*$', 1)

# Prove that the scoreboard detects a wrong DUT result, using the same binary.
# UVM's default fatal action calls $finish, which exits with status zero.
negative_log = test.obj_dir + '/corrupt.log'
test.execute(all_run_flags=['+UVM_NO_RELNOTES', '+DPI_CORRUPT_DUT'], logfile=negative_log)
test.file_grep(negative_log, r'UVM_FATAL .*\[DPI_SCOREBOARD\].*checksum mismatch')
test.file_grep_count(negative_log, r'^\*\* UVM DPI REFERENCE PASSED \*\*$', 0)

test.passes()
