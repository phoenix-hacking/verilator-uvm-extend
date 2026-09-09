#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2024 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('vlt')
test.top_filename = "t/t_uvm_dpi.v"

if re.search(r'clang', test.cxx_version):
    test.skip("uvm_regex.cc from upstream has clang warnings")

test.compile(verilator_flags2=[
    "--binary",
    test.build_jobs_groups,
    "+define+T_V2020_3_1",
    *test.uvm2020_flags(package=False, dpi=True),
])

test.execute(expect_filename=test.golden_filename)

test.passes()
