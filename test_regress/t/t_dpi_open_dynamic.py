#!/usr/bin/env python3
# DESCRIPTION: Verilator: Dynamic and queue actual arguments to DPI open arrays
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('vlt', 'vltmt')
test.compile(threads=2 if test.vltmt else 1,
             v_flags2=['t/t_dpi_open_dynamic.cpp'],
             verilator_flags2=['-Wall -Wno-DECLFILENAME', '-CFLAGS -std=c++14'])
test.execute()
for dimension in ['OUTER', 'INNER']:
    test.execute(fails=True,
                 all_run_flags=['+DPI_BAD_' + dimension],
                 logfile=test.obj_dir + '/bad_' + dimension.lower() + '.log',
                 expect_filename='t/t_dpi_open_dynamic_size_bad.out')
test.passes()
