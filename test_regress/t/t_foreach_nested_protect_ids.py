#!/usr/bin/env python3
# DESCRIPTION: Verilator: Nested foreach with protected identifiers
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('vlt', 'vltmt')
test.top_filename = 't/t_foreach_nonzero_nested.v'
test.compile(
    threads=2 if test.vltmt else 1,
    verilator_flags2=['-Wall -Wno-DECLFILENAME', '--protect-ids', '--protect-key FOREACH'])
test.execute()
test.passes()
