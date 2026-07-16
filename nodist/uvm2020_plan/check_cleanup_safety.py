#!/usr/bin/env python3
# DESCRIPTION: Verilator: Negative checks for clean-before symlink safety
#
# Copyright 2026 by Wilson Snyder. This program is free software; you can
# redistribute it and/or modify it under the terms of either the GNU Lesser
# General Public License Version 3 or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import os
import pathlib
import subprocess
import sys
import tempfile


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST_REGRESS = REPO_ROOT / 'test_regress'
DRIVER = TEST_REGRESS / 'driver.py'
TESTS = TEST_REGRESS / 't'
SUFFIX = '-clean-safety'


def run_driver(work_directory: pathlib.Path,
               python_shim: pathlib.Path) -> subprocess.CompletedProcess:
    command = [
        sys.executable,
        str(DRIVER),
        '--jobs=1',
        '--driver-build-jobs=1',
        '--driver-clean-before',
        '--driver-clean-before-seed=interrupted.gch',
        '--obj-suffix=' + SUFFIX,
        '--vlt',
        't/t_math_arith.py',
    ]
    environment = os.environ.copy()
    environment.setdefault('VERILATOR_ROOT', str(REPO_ROOT))
    environment.setdefault('MAKE', 'make')
    inherited_pythonpath = environment.get('PYTHONPATH')
    environment['PYTHONPATH'] = str(python_shim)
    if inherited_pythonpath:
        environment['PYTHONPATH'] += os.pathsep + inherited_pythonpath
    return subprocess.run(command,
                          cwd=work_directory,
                          env=environment,
                          capture_output=True,
                          text=True,
                          check=False)


def require_rejection(result: subprocess.CompletedProcess, diagnostic: str) -> None:
    output = result.stdout + result.stderr
    if result.returncode == 0 or diagnostic not in output:
        raise RuntimeError('clean-before safety probe did not reject as expected:\n' + output)


def prepare_work_directory(root: pathlib.Path, name: str) -> pathlib.Path:
    work_directory = root / name
    work_directory.mkdir()
    (work_directory / 't').symlink_to(TESTS, target_is_directory=True)
    return work_directory


def check_symlinked_ancestor(root: pathlib.Path, python_shim: pathlib.Path) -> None:
    outside = root / 'outside-ancestor'
    outside.mkdir()
    guard = outside / 'guard'
    guard.write_text('preserve ancestor target\n', encoding='utf-8')
    work_directory = prepare_work_directory(root, 'ancestor-work')
    (work_directory / 'obj_vlt').symlink_to(outside, target_is_directory=True)

    result = run_driver(work_directory, python_shim)
    require_rejection(result, 'symlinked path component')
    if guard.read_text(encoding='utf-8') != 'preserve ancestor target\n':
        raise RuntimeError('symlinked ancestor target was modified')
    if (outside / ('t_math_arith' + SUFFIX)).exists():
        raise RuntimeError('clean-before created content through a symlinked ancestor')


def check_symlinked_seed(root: pathlib.Path, python_shim: pathlib.Path) -> None:
    outside = root / 'outside-seed'
    outside.mkdir()
    seed_target = outside / 'seed-target'
    seed_target.write_text('preserve seed target\n', encoding='utf-8')
    work_directory = prepare_work_directory(root, 'seed-work')
    object_directory = work_directory / 'obj_vlt' / ('t_math_arith' + SUFFIX)
    object_directory.mkdir(parents=True)
    (object_directory / 'interrupted.gch').symlink_to(seed_target)

    result = run_driver(work_directory, python_shim)
    require_rejection(result, 'symlinked clean-before seed')
    if seed_target.read_text(encoding='utf-8') != 'preserve seed target\n':
        raise RuntimeError('symlinked seed target was modified')


def check_dangling_symlink_postcondition(root: pathlib.Path) -> None:
    dangling = root / 'dangling-sentinel'
    dangling.symlink_to(root / 'missing-target')
    result = subprocess.run([
        'sh', '-c', 'test -e "$1" || test -L "$1"', 'sh', str(dangling)
    ],
                            capture_output=True,
                            text=True,
                            check=False)
    if result.returncode != 0:
        raise RuntimeError('cleanup postcondition missed a dangling sentinel symlink')


def prepare_python_shim(root: pathlib.Path) -> pathlib.Path:
    python_shim = root / 'python-shim'
    python_shim.mkdir()
    (python_shim / 'distro.py').write_text(
        "def name(pretty=False):\n    return 'cleanup-safety-probe'\n", encoding='utf-8')
    (python_shim / 'sitecustomize.py').write_text(
        "import multiprocessing\n"
        "_get_context = multiprocessing.get_context\n"
        "def _probe_context(method=None):\n"
        "    if method == 'forkserver':\n"
        "        method = 'fork'\n"
        "    return _get_context(method)\n"
        "multiprocessing.get_context = _probe_context\n",
        encoding='utf-8')
    return python_shim


def main() -> None:
    with tempfile.TemporaryDirectory(prefix='verilator-clean-safety-') as temp_directory:
        root = pathlib.Path(temp_directory)
        python_shim = prepare_python_shim(root)
        check_symlinked_ancestor(root, python_shim)
        check_symlinked_seed(root, python_shim)
        check_dangling_symlink_postcondition(root)
    print('uvm2020: clean-before symlink safety PASSED')


if __name__ == '__main__':
    main()
