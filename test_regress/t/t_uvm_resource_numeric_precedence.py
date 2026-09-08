#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM numeric resource precedence and direct lookup
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.priority(50)
test.scenarios('vlt', 'vltmt')
test.top_filename = 't/t_uvm_resource_numeric_precedence.v'

if test.have_dev_gcov:
    test.skip("Test suite intended for full dev coverage without needing this test")

for dpi in (False, True):
    test.compile(v_flags2=[
        "--binary",
        test.build_jobs_groups,
        "--CFLAGS -O0",
        "-Wall",
        *test.uvm2020_flags(dpi=dpi),
    ],
                 threads=2 if test.vltmt else 1)

    log = test.obj_dir + ('/sim_dpi.log' if dpi else '/sim_nodpi.log')
    test.execute(all_run_flags=['' if test.verbose else '+UVM_NO_RELNOTES'], logfile=log)
    test.file_grep_count(log, r'^\*\* UVM RESOURCE NUMERIC PRECEDENCE PASSED \*\*$', 1)
test.passes()
