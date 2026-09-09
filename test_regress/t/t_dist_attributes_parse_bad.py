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
import shlex
import sys

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
        ('missing_include', [valid], '-std=c++14 -include', [],
         r'%Error: reading compiler arguments failed:'),
        ('missing_define', [valid], '-std=c++14 -D', [],
         r'%Error: reading compiler arguments failed:'),
        ('missing_output', [valid], '-std=c++14 -o', [],
         r'%Error: reading compiler arguments failed:'),
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

# Inheritance contracts follow actual virtual overrides, including definitions
# outside the class, rather than another declaration with the same spelling.
inheritance_header = os.path.abspath(test.obj_dir + '/inheritance.h')
test.write_wholefile(inheritance_header,
                     'struct DisabledBase { virtual int value() const = 0; };\n')
inheritance_cases = {
    'hidden_nonvirtual': ('struct Base { int value() const PURE { return 1; } };\n'
                          'struct Derived : Base { int value() const { return unsafe(); } };\n',
                          ''),
    'cv_overload': ('struct Base { virtual int value() const PURE { return 1; } };\n'
                    'struct Derived : Base { int value() { return unsafe(); } };\n', ''),
    'nested_class': ('struct Base { virtual int value() const SAFE = 0; };\n'
                     'struct Derived : Base {\n'
                     '  struct Nested { int value() const { return unsafe(); } };\n'
                     '  int value() const override SAFE { return safe(); }\n'
                     '};\n', ''),
    'implicit_override':
    ('struct Base { virtual int value() const SAFE = 0; };\n'
     'struct Derived : Base { int value() const override { return safe(); } };\n', ''),
    'implicit_external_override': ('struct Base { virtual int value() const SAFE = 0; };\n'
                                   'struct Derived : Base { int value() const override; };\n'
                                   'int Derived::value() const { return safe(); }\n', ''),
    'nested_override_bad': ('struct Base { virtual int value() const SAFE = 0; };\n'
                            'struct Derived : Base {\n'
                            '  struct Nested {};\n'
                            '  int value() const override { return unsafe(); }\n'
                            '};\n', 'is mtsafe but calls non-mtsafe'),
    'external_override_bad': ('struct Base { virtual int value() const SAFE = 0; };\n'
                              'struct Derived : Base { int value() const override; };\n'
                              'int Derived::value() const { return unsafe(); }\n',
                              'is mtsafe but calls non-mtsafe'),
    'template_override_bad':
    ('template <typename T> struct Base { virtual int value(T) const SAFE = 0; };\n'
     'struct Derived : Base<int> { int value(int) const override { return unsafe(); } };\n',
     'is mtsafe but calls non-mtsafe'),
    'conversion_override_bad':
    ('struct Base { virtual operator bool() const SAFE = 0; };\n'
     'struct Derived : Base { operator bool() const override { return unsafe() != 0; } };\n',
     'is mtsafe but calls non-mtsafe'),
    'multiple_bases_bad': ('struct PureBase { virtual int value() const PURE = 0; };\n'
                           'struct SafeBase { virtual int value() const SAFE = 0; };\n'
                           'struct Derived : PureBase, SafeBase {\n'
                           '  int value() const override SAFE { return safe(); }\n'
                           '};\n', 'is pure but calls non-pure'),
    'multiple_bases': ('struct PureBase { virtual int value() const PURE = 0; };\n'
                       'struct SafeBase { virtual int value() const SAFE = 0; };\n'
                       'struct Derived : PureBase, SafeBase {\n'
                       '  int value() const override PURE SAFE { return 1; }\n'
                       '};\n', ''),
    'diamond_override_bad':
    ('struct Base { virtual int value() const SAFE = 0; };\n'
     'struct Left : virtual Base { int value() const override SAFE { return 1; } };\n'
     'struct Right : virtual Base { int value() const override SAFE { return 1; } };\n'
     'struct Derived : Left, Right { int value() const override { return unsafe(); } };\n',
     'is mtsafe but calls non-mtsafe'),
    'disabled_override':
    ('#define VL_MT_DISABLED_CODE_UNIT 1\n#include "inheritance.h"\n'
     'struct Derived : DisabledBase { int value() const override { return 1; } };\n', ''),
}
for jobs in (1, 2):
    for case, (body, diagnostic) in inheritance_cases.items():
        source = os.path.abspath(test.obj_dir + '/' + case + '.cpp')
        test.write_wholefile(
            source, '#define SAFE __attribute__((annotate("MT_SAFE")))\n'
            '#define PURE __attribute__((annotate("PURE")))\n'
            'int unsafe();\nint safe() SAFE;\n' + body)
        log = test.obj_dir + '/' + case + '_' + str(jobs) + '.log'
        test.run(cmd=['python3', checker, '--jobs=' + str(jobs), '--cxxflags=-std=c++14', source],
                 logfile=log,
                 fails=bool(diagnostic))
        if diagnostic:
            test.file_grep(log, diagnostic)
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
# A forced header must be read even when another compiler left an unusable
# precompiled header beside it. Analyzer-owned PCHs are tested separately above.
test.write_wholefile(prefix + '.gch', 'Foreign compiler cache; read prefix.h instead.\n')
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
joined_command = dict(
    unit_command,
    arguments=['c++', '-std=c++14', '-DUNIT_ENABLED', '-includeprefix.h', '-c', 'unit.cpp'])
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

# Exercise a recorded compiler whose default differs from libclang's, using a
# real compiler behind a wrapper. The source checks both the C++ version and
# strict/GNU mode; compiling it first establishes the expected semantics.
dialect = units_dir + '/dialect.cpp'
test.write_wholefile(
    dialect, '#if __cplusplus != EXPECTED_STANDARD\n#error Wrong C++ standard\n#endif\n'
    '#if defined(__STRICT_ANSI__) != EXPECTED_STRICT\n#error Wrong C++ dialect\n#endif\n'
    'int dialect_value() { return 7; }\n')
compiler = shlex.split(os.environ['CXX'])
default_commands = {}
for case, standard, explicit in (
    ('default_gnu', 'gnu++14', ''),
    ('default_strict', 'c++14', ''),
    ('explicit_standard', 'gnu++14', '-std=gnu++17'),
):
    wrapper = units_dir + '/' + case + '-c++'
    test.write_wholefile(
        wrapper, '#!' + sys.executable + '\nimport os\nimport sys\n'
        'compiler = ' + repr(compiler + ['-std=' + standard]) + '\n'
        'os.execvp(compiler[0], compiler + sys.argv[1:])\n')
    os.chmod(wrapper, 0o755)
    arguments = [wrapper]
    if explicit:
        arguments.append(explicit)
    arguments += [
        '-DEXPECTED_STANDARD=' + ('201703L' if explicit else '201402L'),
        '-DEXPECTED_STRICT=' + ('1' if standard == 'c++14' else '0'), '-fsyntax-only', dialect
    ]
    test.run(cmd=[shlex.join(arguments)], logfile=test.obj_dir + '/' + case + '_compiler.log')
    default_commands[case] = {'directory': units_dir, 'file': dialect, 'arguments': arguments}

missing_compiler = units_dir + '/missing-c++'
missing_compiler_command = dict(
    default_commands['default_gnu'],
    arguments=[missing_compiler, *default_commands['default_gnu']['arguments'][1:]])
common_standard_command = dict(
    default_commands['explicit_standard'],
    arguments=[missing_compiler, *default_commands['explicit_standard']['arguments'][2:]])
for jobs in (1, 2):
    for case, entries, sources, options, diagnostic in (
        ('all_commands', [stale_command, unit_command, generated_command,
                          explicit_c_command], [], ['--all-commands'], ''),
        ('explicit_cxx', [generated_command], [generated], [], ''),
        ('joined_include', [joined_command], [unit], [], ''),
        ('default_gnu', [default_commands['default_gnu']], [dialect], [], ''),
        ('default_strict', [default_commands['default_strict']], [dialect], [], ''),
        ('explicit_standard', [default_commands['explicit_standard']], [dialect], [], ''),
        ('common_standard', [common_standard_command], [dialect], ['--cxxflags=-std=gnu++17'], ''),
        ('missing_compiler', [missing_compiler_command], [dialect], [],
         r'%Error: reading compiler defaults failed:'),
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

# The same implementation header can contain different functions in different
# translation units. Macros set after the first include must not let a prior
# safe instantiation hide the later unsafe one (as with trace format backends).
context_dir = os.path.abspath(test.obj_dir + '/header_context')
os.makedirs(context_dir, exist_ok=True)
test.write_wholefile(context_dir + '/common.h',
                     'void safe() __attribute__((annotate("MT_SAFE")));\nvoid unsafe();\n')
test.write_wholefile(context_dir + '/leaf.h', '// Included by the implementation fragment.\n')
test.write_wholefile(
    context_dir + '/implementation.h', '#include "leaf.h"\n'
    'void NAME() __attribute__((annotate("MT_SAFE"))) { CALLEE(); }\n')
context_sources = []
for name, callee in (('first', 'safe'), ('second', 'unsafe')):
    source = context_dir + '/' + name + '.cpp'
    test.write_wholefile(
        source, '#include "common.h"\n#define NAME ' + name + '\n#define CALLEE ' + callee +
        '\n#include "implementation.h"\n')
    context_sources.append(source)
for jobs in (1, 2):
    for order, sources in (('forward', context_sources), ('reverse', context_sources[::-1])):
        log = context_dir + '/' + order + '_' + str(jobs) + '.log'
        test.run(cmd=[
            'python3', checker, '--jobs=' + str(jobs), '--verilator-root=' + context_dir,
            '--cxxflags=-std=c++14', *sources
        ],
                 logfile=log,
                 fails=True)
        test.file_grep(log, r'"second\(\)" is mtsafe but calls non-mtsafe')
        test.file_grep(log, r'Number of functions reported unsafe: (\d+)', 1)

test.passes()
