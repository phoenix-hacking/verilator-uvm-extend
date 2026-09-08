#!/usr/bin/env python3
# DESCRIPTION: Verilator: Reject incomplete attribute analysis
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import json

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
safe_body = os.path.abspath(test.obj_dir + '/safe_body.cpp')
unsafe_body = os.path.abspath(test.obj_dir + '/unsafe_body.cpp')
callback_safe = os.path.abspath(test.obj_dir + '/callback_safe.cpp')
callback_unsafe = os.path.abspath(test.obj_dir + '/callback_unsafe.cpp')
test.write_wholefile(valid, 'int valid() { return 1; }\n')
test.write_wholefile(invalid, 'int invalid = ;\n')
test.write_wholefile(header, 'int header_declaration();\n')
test.write_wholefile(
    mismatch, 'void mismatch();\n'
    'void mismatch() __attribute__((annotate("MT_SAFE"))) {}\n')
for source, annotation in ((safe_body, 'MT_SAFE'), (unsafe_body, 'MT_UNSAFE')):
    test.write_wholefile(
        source, 'void callee() __attribute__((annotate("' + annotation + '"))) {}\n'
        'void caller() __attribute__((annotate("MT_SAFE_EXCLUDES"))) { callee(); }\n')
for source, annotation in ((callback_safe, 'MT_SAFE'), (callback_unsafe, 'MT_UNSAFE')):
    test.write_wholefile(
        source, '#include <functional>\n'
        'void invoke(std::function<void()> callback) __attribute__((annotate("MT_SAFE"))) { '
        'callback(); }\n'
        'void callee() __attribute__((annotate("' + annotation + '"))) {}\n'
        'void caller() __attribute__((annotate("MT_SAFE_EXCLUDES"))) { '
        'invoke([]() { callee(); }); }\n')
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
        ('safe_body', [safe_body], '-std=c++14', [], ''),
        ('unsafe_body', [unsafe_body], '-std=c++14', [], r'is mtsafe but calls non-mtsafe'),
        ('callback_safe', [callback_safe], '-std=c++14', [], ''),
        ('callback_unsafe', [callback_unsafe], '-std=c++14', [],
         r'is mtsafe but calls non-mtsafe'),
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
            elif case in ('unsafe_body', 'callback_unsafe'):
                test.file_grep(log, r'Number of functions reported unsafe: (\d+)', 1)
            else:
                test.file_grep(log, r'Number of files that could not be analyzed: (\d+)', 1)
        else:
            test.file_grep(log, r'Number of functions reported unsafe: (\d+)', 0)

# A source fragment is compiled through its including translation unit. The
# database also contains a C-suffixed file deliberately compiled as C++.
units_dir = os.path.abspath(test.obj_dir + '/units')
os.makedirs(units_dir, exist_ok=True)
unit = units_dir + '/unit.cpp'
fragment = units_dir + '/fragment.cpp'
generated = units_dir + '/generated.c'
explicit_c = units_dir + '/explicit_c.c'
prefix = units_dir + '/prefix.h'
test.write_wholefile(prefix, '#define PREFIX_VALUE 7\n')
test.write_wholefile(fragment, 'int from_fragment() { return helper(); }\n')
test.write_wholefile(
    unit, '#ifndef UNIT_ENABLED\n#error Missing compilation flags\n#endif\n'
    'int helper() { return PREFIX_VALUE; }\n#include "fragment.cpp"\n')
test.write_wholefile(generated, 'class Generated { public: int value() { return 7; } };\n')
test.write_wholefile(
    explicit_c, '#ifdef __cplusplus\n#error Expected C language\n#endif\n'
    'int c_function(void) { return 7; }\n')
unit_arguments = [
    'c++', '-std=c++14', '-DUNIT_ENABLED', '-include', 'prefix.h', '-MF', 'unit.d', '-c',
    'unit.cpp', '-o', 'unit.o'
]
unit_command = {'directory': units_dir, 'file': 'unit.cpp', 'arguments': unit_arguments}
generated_command = {
    'directory': units_dir,
    'file': 'generated.c',
    'arguments': ['c++', '-std=c++14', '-c', 'generated.c', '-o', 'generated.o']
}
explicit_c_command = {
    'directory': units_dir,
    'file': 'explicit_c.c',
    'arguments': ['c++', '-x', 'c', '-std=c11', '-c', 'explicit_c.c', '-o', 'explicit_c.o']
}
stale_command = dict(unit_command, arguments=['c++', '-std=c++14', '-c', 'unit.cpp'])
invalid_command = {
    'directory': units_dir,
    'file': invalid,
    'arguments': ['c++', '-std=c++14', '-c', invalid]
}
for jobs in (1, 2):
    for case, entries, sources, options, diagnostic in (
        ('all_commands', [stale_command, unit_command, generated_command,
                          explicit_c_command], [], ['--all-commands'], ''),
        ('explicit_cxx', [generated_command], [generated], [], ''),
        ('unrecorded_fragment', [unit_command], [fragment], [],
         r'%Error: reading compile commands failed:'),
        ('all_invalid', [unit_command,
                         invalid_command], [], ['--all-commands'], r'%Error: parsing failed:'),
        ('all_empty', [], [], ['--all-commands'], r'%Error: reading compile commands failed:'),
    ):
        test.write_wholefile(units_dir + '/compile_commands.json', json.dumps(entries) + '\n')
        log = test.obj_dir + '/' + case + '_' + str(jobs) + '.log'
        test.run(cmd=[
            'python3', checker, '--jobs=' + str(jobs), '--compile-commands-dir=' + units_dir,
            *options, *sources
        ],
                 logfile=log,
                 fails=bool(diagnostic))
        if diagnostic:
            test.file_grep(log, diagnostic)
            test.file_grep(log, r'Number of files that could not be analyzed: (\d+)', 1)
        else:
            test.file_grep(log, r'Number of functions reported unsafe: (\d+)', 0)

test.passes()
