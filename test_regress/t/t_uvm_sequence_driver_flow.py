#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM sequence/sequencer/driver response and cancellation flow
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.priority(50)
test.scenarios('vlt', 'vltmt')
test.top_filename = 't/t_uvm_sequence_driver_flow.v'

if test.have_dev_gcov:
    test.skip("Test suite intended for full dev coverage without needing this test")

test.compile(v_flags2=[
    "--binary",
    test.build_jobs_groups,
    "--CFLAGS -O0",
    "-Wall",
    "+incdir+t/uvm",
    "t/uvm/uvm_pkg_all_v2020_3_1_nodpi.svh",
])

test.execute(all_run_flags=['' if test.verbose else '+UVM_NO_RELNOTES'])
test.file_grep_count(
    test.run_log_filename, r'^\*\* UVM SEQUENCE DRIVER FLOW PASSED \*\*$', 1)
test.passes()
