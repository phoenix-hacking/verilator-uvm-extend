#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2025-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('vlt_all')

test.compile(verilator_flags2=["--binary"], threads=2 if test.vltmt else 1)

for case in ('loops', 'block_loop', 'loop_block', 'blocks', 'read', 'sync_loops', 'sync_branch',
             'timing_branch'):
    log = f'{test.obj_dir}/sim_{case}.log'
    test.execute(all_run_flags=['+LIFE_CASE=' + case], logfile=log)
    test.file_grep_count(log, '^LIFE_NESTED CHECKED case=' + case + '$', 1)

test.passes()
