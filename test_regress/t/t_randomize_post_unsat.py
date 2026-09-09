#!/usr/bin/env python3
# DESCRIPTION: Verilator: Failed randomization skips post callbacks and permits recovery
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('simulator')
if not test.have_solver:
    test.skip('No constraint solver installed')

test.timeout(60)
for defines in ['', '+define+FAILED_STATE_EXPANDED']:
    test.compile(verilator_flags2=[
        '-Wall', '-Wno-DECLFILENAME', '--no-timing', '-CFLAGS', '-std=c++14', defines
    ],
                 threads=2 if test.vltmt else 1)
    test.execute()
test.passes()
