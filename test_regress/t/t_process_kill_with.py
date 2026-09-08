#!/usr/bin/env python3
# DESCRIPTION: Verilator: Process cancellation in array method with expressions
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('simulator')
for lift in ((True, False) if test.vlt or test.vltmt else (True, )):
    for protect in ((False, True) if test.vlt or test.vltmt else (False, )):
        flags = ['--binary'] + (['--protect-ids'] if protect else [])
        if not lift:
            flags += ['-fno-lift-expr']
        test.compile(verilator_flags2=flags, threads=2 if test.vltmt else 1)
        name = ('protected' if protect else 'plain') + ('' if lift else '_no_lift')
        test.execute(logfile=f'{test.obj_dir}/sim_{name}.log')
test.passes()
