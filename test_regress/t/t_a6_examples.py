#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2024 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import shlex

test.priority(180)
test.scenarios('dist')

test.clean_command = '/bin/rm -rf ../examples/*/build ../examples/*/obj*'

if not os.path.exists(test.root + "/.git"):
    test.skip("Not in a git repository")

examples = sorted(test.glob_some(test.root + "/examples/*"))
for example in examples:
    command = [os.environ["MAKE"], "-C", example]
    if os.path.basename(example) == 'make_uvm':
        source_root = os.environ.get('UVM_SOURCE_ROOT', os.environ.get('UVM_HOME', ''))
        if source_root:
            source_root = os.path.abspath(source_root)
        command.append(shlex.quote('UVM_SOURCE_ROOT=' + source_root))
    test.run(logfile=test.obj_dir + '/' + os.path.basename(example) + '.log', cmd=command)

test.passes()
