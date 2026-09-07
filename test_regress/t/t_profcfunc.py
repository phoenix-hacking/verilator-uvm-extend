#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2024 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('dist')

test.run(cmd=[
    "cd " + test.obj_dir + " && " + os.environ["VERILATOR_ROOT"] + "/bin/verilator_profcfunc",
    test.t_dir + "/t_profcfunc.gprof > profcfuncs.log"
],
         check_finished=False)

test.files_identical(test.obj_dir + "/profcfuncs.log", test.golden_filename)

# Profiles need not contain the public evaluation entry points after optimization.
profile = test.file_contents(test.t_dir + "/t_profcfunc.gprof")
profile = re.sub(r'^.*::eval(?:_step)?\(.*\n', '', profile, flags=re.MULTILINE)
test.write_wholefile(test.obj_dir + "/no_eval.gprof", profile)
test.run(cmd=[
    "cd " + test.obj_dir + " && " + os.environ["VERILATOR_ROOT"] +
    "/bin/verilator_profcfunc no_eval.gprof > profcfuncs_no_eval.log"
],
         check_finished=False)
test.files_identical(test.obj_dir + "/profcfuncs_no_eval.log",
                     test.golden_filename.replace(".out", "_no_eval.out"))

test.passes()
