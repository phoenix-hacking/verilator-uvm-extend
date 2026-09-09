#!/usr/bin/env python3
# DESCRIPTION: Verilator: Regression scheduling preserves explicit lane order
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import runpy
import types
from unittest import mock

test.scenarios('dist')

# Exercise the real prefilter and scheduler with existing drivers. Intercept
# submission and waiting so this harness regression needs no HDL compiler.
driver = runpy.run_path('driver.py')
run_them = driver['run_them']
runner = driver['Runner']
reduced_first = 't/t_uvm_lrm_sched_wait_zero.py'
package = 't/t_uvm_core_factory_basic.py'
reduced_last = 't/t_class_param_static_identity.py'
filtered = 't/t_driver_timeout.py'
requested = [reduced_first, package, filtered, reduced_last]


def check_order(preserve, scenarios, expected_tests):
    arguments = types.SimpleNamespace(driver_preserve_order=preserve,
                                      quiet=True,
                                      rerun=False,
                                      scenarios=scenarios,
                                      test_dirs=['t'])
    with mock.patch.dict(run_them.__globals__, {'Args': arguments, 'Arg_Tests': requested}), \
            mock.patch.object(runner, 'one_test') as submit, \
            mock.patch.object(runner, 'wait_and_report'):
        run_them()
    expected = [
        mock.call(py_filename=filename, scenario=scenario) for filename in expected_tests
        for scenario in ('vlt', 'vltmt') if scenario in scenarios
        if filename != package or scenario == 'vlt'
    ]
    if submit.call_args_list != expected:
        test.error('Unexpected scheduling order: got ' + repr(submit.call_args_list) +
                   ', expected ' + repr(expected))


# The ordinary throughput-oriented priority policy remains the default.
check_order(False, ['vlt'], [package, reduced_first, reduced_last])
# Explicit order puts the reduced semantic test ahead of priority-50 UVM.
check_order(True, ['vlt'], [reduced_first, package, reduced_last])
# Filtering and scenario deduplication must not reorder the selected tests.
check_order(False, ['vltmt', 'vlt', 'vlt'], [package, reduced_first, reduced_last])
check_order(True, ['vltmt', 'vlt', 'vlt'], [reduced_first, package, reduced_last])

test.passes()
