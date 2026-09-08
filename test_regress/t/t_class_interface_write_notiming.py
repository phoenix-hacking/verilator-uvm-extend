#!/usr/bin/env python3
# DESCRIPTION: Verilator: Class writes in a simulation without timing
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('vlt', 'vltmt')
test.top_filename = 't/t_class_interface_write.v'
test.compile(threads=2 if test.vltmt else 1,
             v_flags2=['--no-timing', '+define+CLASS_WRITE_NOTIMING', '--stats'])
test.execute()
test.file_grep(test.stats, r'Scheduling, class write change detect triggers\s+(\d+)', 6)
test.passes()
