#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import re

import vltest_bootstrap

test.scenarios('vlt')
test.compile(verilator_flags2=['--coverage-user', '--exe', test.pli_filename, '-CFLAGS -std=c++14'],
             make_flags=['CPPFLAGS_ADD=-DTEST_OBJ_DIR="' + test.obj_dir + '"'],
             make_top_shell=False,
             make_main=False)
test.execute()

# Confirm report pointers still address the retained instance after handle release.
counts = {}
for entry, count in re.findall(r"C '([^']+)' (\d+)", test.file_contents(test.coverage_filename)):
    name = re.search(r'\x01bin\x02([^\x01]+)', entry)
    if name:
        counts[name.group(1)] = int(count)
if counts != {'lo': 1, 'hi': 0, 'ignored': 0}:
    test.error(f'Unexpected retained instance bins: {counts}')
test.passes()
