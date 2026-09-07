#!/usr/bin/env python3
# DESCRIPTION: Verilator: Reject incomplete attribute analysis
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('dist')

if 'VERILATOR_TEST_NO_ATTRIBUTES' in os.environ:
    test.skip('Skipping due to VERILATOR_TEST_NO_ATTRIBUTES')
probe = test.run_capture('python3 -c "from clang.cindex import Index; Index.create(); print(1)"',
                         check=False)
if probe.strip() != '1':
    test.skip('No libclang installed')

valid = os.path.abspath(test.obj_dir + '/valid.cpp')
invalid = os.path.abspath(test.obj_dir + '/invalid.cpp')
header = os.path.abspath(test.obj_dir + '/valid.h')
mismatch = os.path.abspath(test.obj_dir + '/mismatch.cpp')
test.write_wholefile(valid, 'int valid() { return 1; }\n')
test.write_wholefile(invalid, 'int invalid = ;\n')
test.write_wholefile(header, 'int header_declaration();\n')
test.write_wholefile(
    mismatch, 'void mismatch();\n'
    'void mismatch() __attribute__((annotate("MT_SAFE"))) {}\n')
checker = os.path.abspath(test.root + '/nodist/clang_check_attributes')
compdb = os.path.abspath(test.obj_dir + '/compile_commands.json')
test.write_wholefile(compdb, '[]\n')

for jobs in (1, 2):
    for case, sources, flags, extra, diagnostic in (
        ('valid', [valid], '-std=c++14', [], ''),
        ('invalid', [invalid], '-std=c++14', [], r'%Error: parsing failed:'),
        ('mixed', [valid, invalid], '-std=c++14', [], r'%Error: parsing failed:'),
        ('load', [valid], '-x invalid-language', [], r'%Error: parsing failed:'),
        ('pch_valid', [valid], '-std=c++14', ['--precompile=' + header], ''),
        ('pch_invalid', [valid], '-std=c++14', ['--precompile=' + invalid],
         r'%Warning: Precompilation failed, skipping:'),
        ('missing_command', [valid], '-std=c++14',
         ['--compile-commands-dir=' + os.path.dirname(compdb)
          ], r'%Error: reading compile commands failed:'),
        ('mismatch', [mismatch], '-std=c++14', [], r'declaration does not match definition'),
    ):
        log = test.obj_dir + '/' + case + '_' + str(jobs) + '.log'
        test.run(cmd=[
            'python3', checker, '--jobs=' + str(jobs), "--cxxflags='" + flags + "'", *extra,
            *sources
        ],
                 logfile=log,
                 fails=bool(diagnostic))
        if diagnostic:
            test.file_grep(log, diagnostic)
            if case == 'mismatch':
                test.file_grep(log, r'Number of functions reported unsafe: (\d+)', 0)
            else:
                test.file_grep(log, r'Number of files that could not be analyzed: (\d+)', 1)
        else:
            test.file_grep(log, r'Number of functions reported unsafe: (\d+)', 0)

test.passes()
