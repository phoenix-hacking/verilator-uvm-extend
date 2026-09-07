#!/usr/bin/env python3
# DESCRIPTION: Verilator: UVM goal completion requires evidence and prerequisites
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import copy
from pathlib import Path
import runpy
import yaml

test.scenarios('dist')

checker_module = runpy.run_path('../nodist/uvm2020_plan/check_tracker.py')
Checker = checker_module['TrackerChecker']
document = yaml.load(Path('../nodist/uvm2020_plan/tracker.yaml').read_text(),
                     Loader=checker_module['UniqueKeySafeLoader'])
errors, computed = Checker(document).check()
if errors:
    test.error('The real tracker must validate before goal mutation checks: ' + repr(errors))


def check_goals(changed, program=None, milestones=None):
    checker = Checker(changed)
    checker.check_evidence(changed)
    checker.check_goals(changed, program or computed['program'], milestones
                        or computed['milestones'])
    return checker.errors


for goal_id in ('G-UVM', 'G-PERF'):
    changed = copy.deepcopy(document)
    changed['goals'][goal_id]['status'] = 'pass'
    if not check_goals(changed):
        test.error(goal_id + ' accepted an unsupported completion claim')

    # Accepting every checklist row still cannot bypass unfinished program
    # criteria or the dedicated RTL and UVM performance prerequisites.
    for check in changed['goals'][goal_id]['checks'].values():
        check['status'] = 'pass'
        check['evidence'] = ['LOCAL-TRACKER-MANIFEST-0001']
    if not check_goals(changed):
        test.error(goal_id + ' bypassed incomplete prerequisites')

    for check_id in document['goals'][goal_id]['checks']:
        missing = copy.deepcopy(document)
        del missing['goals'][goal_id]['checks'][check_id]
        if not check_goals(missing):
            test.error(goal_id + ' allowed an acceptance check to be deleted')

        unsupported = copy.deepcopy(document)
        unsupported['goals'][goal_id]['checks'][check_id]['status'] = 'pass'
        unsupported['goals'][goal_id]['checks'][check_id]['evidence'] = []
        if not check_goals(unsupported):
            test.error(goal_id + ' accepted a check without evidence')

# The guard must also accept complete synthetic prerequisites. This verifies
# the acceptance path without changing any real project completion status.
changed = copy.deepcopy(document)
for goal in changed['goals'].values():
    goal['status'] = 'pass'
    for check in goal['checks'].values():
        check['status'] = 'pass'
        check['evidence'] = ['LOCAL-TRACKER-MANIFEST-0001']
program = copy.deepcopy(computed['program'])
program['complete'] = 21
milestones = copy.deepcopy(computed['milestones'])
for milestone_id, gate_id in (('M04', 'M04-G06-RTL-PERFORMANCE'), ('M17', 'M17-G03-PERFORMANCE')):
    milestones['by_id'][milestone_id]['gates'][gate_id]['status'] = 'pass'
if check_goals(changed, program, milestones):
    test.error('Complete synthetic goal evidence and prerequisites were rejected')
for milestone_id, gate_id in (('M04', 'M04-G06-RTL-PERFORMANCE'), ('M17', 'M17-G03-PERFORMANCE')):
    partial = copy.deepcopy(milestones)
    partial['by_id'][milestone_id]['gates'][gate_id]['status'] = 'pending'
    if not check_goals(changed, program, partial):
        test.error('Performance completion bypassed ' + gate_id)

test.passes()
