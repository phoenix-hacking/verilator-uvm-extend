#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2025 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('simulator')

for protect in ((False, True) if test.vlt or test.vltmt else (False, )):
    test.compile(verilator_flags2=['--binary'] + (['--protect-ids'] if protect else []),
                 threads=2 if test.vltmt else 1)
    test.execute(logfile=test.obj_dir + ('/sim_protected.log' if protect else '/sim_plain.log'))

test.passes()
