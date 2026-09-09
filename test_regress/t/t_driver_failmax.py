#!/usr/bin/env python3
# DESCRIPTION: Verilator: Failure limits accept numeric CLI values
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import os
from pathlib import Path
import pickle
import re
import subprocess
import sys

test.scenarios('dist')

fixtures = Path(test.obj_dir).resolve() / 'fixtures'
fixtures.mkdir(parents=True, exist_ok=True)
drivers = []
for label in 'ABCD':
    path = fixtures / ('t_limit_' + label.lower() + '.py')
    action = "test.error('intentional failure')" if label in 'AC' else 'test.passes()'
    path.write_text("test.scenarios('dist')\nprint('FAILMAX_EXECUTED_" + label + "')\n" + action +
                    '\n',
                    encoding='utf-8')
    drivers.append(str(path))

child_env = os.environ.copy()
child_env.pop('TEST_REGRESS', None)
child_env['VERILATOR_TESTS_SITE'] = str(fixtures)

for name, options, expected in (
    ('zero', ['--fail-max=0'], 'ABCD'),
    ('one', ['--fail-max=1'], 'A'),
    ('two', ['--fail-max=2'], 'ABC'),
    ('default', [], 'ABCD'),
    ('negative', ['--fail-max=-1'], ''),
    ('invalid', ['--fail-max=invalid'], ''),
):
    command = [
        sys.executable, 'driver.py', '--dist', '--jobs=1', '--driver-build-jobs=1',
        '--driver-preserve-order', '--obj-suffix=-' + name, *options, *drivers
    ]
    result = subprocess.run(command,
                            capture_output=True,
                            text=True,
                            check=False,
                            env=child_env,
                            timeout=30)
    output = result.stdout + result.stderr
    Path(test.obj_dir, name + '.log').write_text(output, encoding='utf-8')
    executed = ''.join(re.findall(r'^FAILMAX_EXECUTED_([A-D])$', output, re.MULTILINE))
    if executed != expected:
        test.error('Incorrect failure-limit execution for ' + name + ': ' + repr(executed))
    if expected:
        if result.returncode == 0 or 'Traceback' in output:
            test.error('Failure-limit run did not report the intentional fixture failures: ' +
                       name)
        if (name in ('one', 'two')) != ('exceeded --fail-max' in output):
            test.error('Failure-limit stopping behavior differs from the requested count: ' + name)
        for label in 'ABCD':
            stem = 't_limit_' + label.lower()
            status_path = Path(test.obj_dir, 'obj_dist', stem + '-' + name, 'V' + stem + '.status')
            status = pickle.loads(status_path.read_bytes())
            actual = (bool(status['_ok']), bool(status['_skips']), bool(status['errors']))
            wanted = (label in expected and label in 'BD', label not in expected, label in expected
                      and label in 'AC')
            if actual != wanted:
                test.error('Incorrect child status for ' + name + '/' + label + ': ' +
                           repr(actual))
    elif result.returncode != 2 or '--fail-max' not in result.stderr or 'Traceback' in output:
        test.error('Invalid failure limit was not rejected by argument parsing: ' + name)

test.passes()
