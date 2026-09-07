#!/usr/bin/env python3
# DESCRIPTION: Verilator: Explicit UVM source selection cannot fall back to packed artifacts
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import os
import runpy
import shlex
import subprocess
import sys
import types
from unittest import mock

test.scenarios('dist')

driver = runpy.run_path('driver.py')
select_flags = driver['VlTest'].uvm2020_flags
source_root = '/tmp/uvm source with spaces'

for package in (False, True):
    for dpi in (False, True):
        with mock.patch.dict(select_flags.__globals__,
                             {'Args': types.SimpleNamespace(driver_uvm_source_root=source_root)}):
            flags = shlex.split(' '.join(select_flags(None, package=package, dpi=dpi)))
        if '+incdir+' + source_root + '/src' not in flags:
            test.error('Upstream include path did not survive shell tokenization')
        if (source_root + '/src/uvm_pkg.sv' in flags) != package:
            test.error('Package selection differs from the requested mode')
        if ('t/t_uvm_source_dpi.cpp' in flags) != dpi:
            test.error('DPI adapter selection differs from the requested mode')
        if dpi:
            cflags = shlex.split(flags[flags.index('-CFLAGS') + 1])
            if cflags != ['-I' + source_root + '/src/dpi']:
                test.error('DPI components did not use the requested upstream source tree')
        if ('+define+UVM_NO_DPI' in flags) != (package and not dpi):
            test.error('No-DPI mode was not applied to the upstream package')
        if any('t/uvm/' in flag for flag in flags):
            test.error('An upstream-source run fell back to a bundled artifact')

with mock.patch.dict(select_flags.__globals__,
                     {'Args': types.SimpleNamespace(driver_uvm_source_root=None)}):
    flags = select_flags(None)
    if flags != ['+incdir+t/uvm', 't/uvm/uvm_pkg_all_v2020_3_1_nodpi.svh']:
        test.error('Ordinary UVM regressions changed their default source')

# A typo must fail before scheduling, rather than quietly testing the bundled
# package and attributing that success to the requested upstream source tree.
child_env = os.environ.copy()
child_env.pop('TEST_REGRESS', None)
for invalid_root, diagnostic in ((test.obj_dir + '/missing-uvm-source', 'src/uvm_pkg.sv'),
                                 ('', 'a nonempty path')):
    result = subprocess.run([
        sys.executable, 'driver.py', '--driver-uvm-source-root', invalid_root, '--dist',
        't/t_driver_order.py'
    ],
                            capture_output=True,
                            text=True,
                            check=False,
                            env=child_env)
    if result.returncode != 2 or '--driver-uvm-source-root requires ' + diagnostic not in result.stderr:
        test.error('An invalid upstream source path was not rejected before execution: ' +
                   repr((result.returncode, result.stdout, result.stderr)))

test.passes()
