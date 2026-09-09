#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2024 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import json
import vltest_bootstrap

test.scenarios('dist')


def have_clang_check():
    cmd = 'python3 -c "from clang.cindex import Index; index = Index.create(); print(\\"Clang imported\\")";'
    if test.verbose:
        print("\t" + cmd)
    nout = test.run_capture(cmd, check=False)
    if not nout or not re.search(r'Clang imported', nout):
        return False
    return True


if 'VERILATOR_TEST_NO_ATTRIBUTES' in os.environ:
    test.skip("Skipping due to VERILATOR_TEST_NO_ATTRIBUTES")
if not os.path.exists(test.root + "/.git"):
    test.skip("Not in a git repository")
if not have_clang_check():
    test.skip("No libclang installed")

aroot = os.path.abspath(test.root)
ccjson_file = test.obj_dir + "/compile_commands.json"

aroot_dir = os.path.abspath(test.root)
srcs_dir = os.path.abspath("./t/t_dist_attributes")
common_args = [
    "clang++", "-std=c++14", "-I" + aroot_dir + "/include", "-I" + aroot_dir + "/src", "-c"
]

ccjson = [
    {
        "directory": srcs_dir,
        "file": srcs_dir + "/mt_enabled.cpp",
        "output": srcs_dir + "/mt_enabled.o",
        "arguments":
        [*common_args, "-o", srcs_dir + "/mt_enabled.o", srcs_dir + "/mt_enabled.cpp"]
    },
    {
        "directory": srcs_dir,
        "file": srcs_dir + "/mt_disabled.cpp",
        "output": srcs_dir + "/mt_disabled.o",
        "arguments":
        [*common_args, "-o", srcs_dir + "/mt_disabled.o", srcs_dir + "/mt_disabled.cpp"]
    },
]
ccjson_str = json.dumps(ccjson)

srcfiles = []
for entry in ccjson:
    srcfiles.append(entry["file"])
srcfiles_str = ' '.join(srcfiles)

test.write_wholefile(ccjson_file, ccjson_str)

test.run(
    logfile=test.run_log_filename,
    tee=True,
    fails=True,
    # With `--verilator-root` set to the current directory
    # (i.e. `test_regress`) the script will skip annotation issues in
    # headers from the `../include` directory.
    cmd=[
        "python3", aroot + "/nodist/clang_check_attributes", "--verilator-root=.",
        "--compile-commands-dir=" + test.obj_dir, "--jobs=1", srcfiles_str
    ])

# MT_SAFE_EXCLUDES bodies must receive the same call checks as MT_SAFE bodies.
test.file_grep(
    test.run_log_filename, r'"sfc_test_caller_func_VL_MT_SAFE_EXCLUDES\(VerilatedMutex &\)"'
    r' is mtsafe but calls non-mtsafe function\(s\)')
test.files_identical(test.run_log_filename, test.golden_filename)

# The actual DPI runtime must preserve the contracts of its typed array-access
# callbacks when storing and calling them through function pointers.
dpi_log = test.obj_dir + '/dpi_attributes.log'
test.run(logfile=dpi_log,
         tee=True,
         cmd=[
             'python3', aroot + '/nodist/clang_check_attributes', '--verilator-root=' + aroot,
             '--jobs=1',
             "--cxxflags='-I" + aroot + '/include -I' + aroot + "/include/vltstd -std=c++14'",
             aroot + '/include/verilated_dpi.cpp'
         ])
test.file_grep(dpi_log, r'Number of functions reported unsafe: +(\d+)', 0)

test.passes()
