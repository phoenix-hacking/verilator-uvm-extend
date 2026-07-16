#!/usr/bin/env python3
# mypy: disallow-untyped-defs
# pylint: disable=C0114,C0116
######################################################################
#
# DESCRIPTION: Verilator: Validate and run the repo-native UVM baseline
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import argparse
import shlex
import subprocess
import sys
from collections import Counter
from pathlib import Path

######################################################################

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("baseline-tests.txt")
TEST_REGRESS = REPO_ROOT / "test_regress"

PACKAGE_TESTS = (
    "test_regress/t/t_uvm_hello_all_v2020_3_1_nodpi.py",
    "test_regress/t/t_uvm_hello_all_v2020_3_1_dpi.py",
    "test_regress/t/t_uvm_dpi_v2020_3_1.py",
)

QUICK_REDUCED_TESTS = (
    "test_regress/t/t_uvm_return_type.py",
    "test_regress/t/t_uvm_return_type2.py",
    "test_regress/t/t_uvm_return_type3.py",
    "test_regress/t/t_uvm_static_func1.py",
    "test_regress/t/t_uvm_typeof_type.py",
)

EXPECTED_COUNTS = {
    "quick": 8,
    "reduced": 69,
    "full": 72,
}

######################################################################


def positive_int(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return number


def read_manifest() -> list[str]:
    entries = []
    with MANIFEST.open(encoding="utf-8") as manifest_file:
        for line in manifest_file:
            entry = line.strip()
            if entry and not entry.startswith("#"):
                entries.append(entry)
    return entries


def validate_manifest() -> list[str]:
    entries = read_manifest()
    errors = []

    if len(entries) != EXPECTED_COUNTS["full"]:
        errors.append(
            f"manifest has {len(entries)} entries, expected {EXPECTED_COUNTS['full']}")

    duplicates = sorted(entry for entry, count in Counter(entries).items() if count != 1)
    if duplicates:
        errors.append("duplicate entries: " + ", ".join(duplicates))

    if tuple(entries[:len(PACKAGE_TESTS)]) != PACKAGE_TESTS:
        errors.append("the three package tests must be first and in lane order")

    reduced_entries = entries[len(PACKAGE_TESTS):]
    if reduced_entries != sorted(reduced_entries):
        errors.append("reduced tests must remain sorted")

    for entry in entries:
        entry_path = Path(entry)
        if entry_path.is_absolute() or ".." in entry_path.parts:
            errors.append(f"entry must be repository-relative: {entry}")
        elif entry_path.suffix != ".py":
            errors.append(f"entry is not a Python test: {entry}")
        elif entry_path.parts[:2] != ("test_regress", "t"):
            errors.append(f"entry is outside test_regress/t: {entry}")
        elif not (REPO_ROOT / entry_path).is_file():
            errors.append(f"test does not exist: {entry}")

    quick_expected = set(PACKAGE_TESTS + QUICK_REDUCED_TESTS)
    missing_quick = sorted(quick_expected - set(entries))
    if missing_quick:
        errors.append("quick tests missing from manifest: " + ", ".join(missing_quick))

    reduced_count = len(reduced_entries)
    if reduced_count != EXPECTED_COUNTS["reduced"]:
        errors.append(
            f"manifest has {reduced_count} reduced tests, expected {EXPECTED_COUNTS['reduced']}")

    if errors:
        sys.exit("%Error: Invalid baseline manifest:\n  " + "\n  ".join(errors))
    return entries


def select_tests(entries: list[str], selection: str) -> list[str]:
    if selection == "full":
        selected = entries
    elif selection == "reduced":
        selected = entries[len(PACKAGE_TESTS):]
    else:
        quick_tests = set(PACKAGE_TESTS + QUICK_REDUCED_TESTS)
        selected = [entry for entry in entries if entry in quick_tests]

    if len(selected) != EXPECTED_COUNTS[selection]:
        sys.exit(f"%Error: Selection {selection} has unexpected size {len(selected)}")
    return selected


def driver_command(selected: list[str], selection: str, jobs: int,
                   build_jobs: int) -> list[str]:
    driver_tests = [str(Path(entry).relative_to("test_regress")) for entry in selected]
    return [
        sys.executable,
        "driver.py",
        f"--jobs={jobs}",
        f"--driver-build-jobs={build_jobs}",
        "--driver-clean-before",
        f"--obj-suffix=-uvm-baseline-{selection}",
        "--vlt",
        *driver_tests,
    ]


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        allow_abbrev=False,
        description="Validate, list, or run the repo-native UVM compatibility baseline.")
    subparsers = parser.add_subparsers(dest="action", required=True)

    subparsers.add_parser("validate", help="validate the frozen manifest")

    list_parser = subparsers.add_parser("list", help="print one selected test per line")
    list_parser.add_argument("selection", choices=EXPECTED_COUNTS)

    run_parser = subparsers.add_parser("run", help="run a clean, explicitly capped selection")
    run_parser.add_argument("selection", choices=EXPECTED_COUNTS)
    run_parser.add_argument("--jobs", type=positive_int, default=1, help="test process cap")
    run_parser.add_argument("--build-jobs",
                            type=positive_int,
                            default=1,
                            help="generated build job cap")
    return parser


def main() -> int:
    args = make_parser().parse_args()
    entries = validate_manifest()

    if args.action == "validate":
        print("baseline manifest valid: full=72 reduced=69 quick=8")
        return 0

    selected = select_tests(entries, args.selection)
    if args.action == "list":
        print("\n".join(selected))
        return 0

    command = driver_command(selected, args.selection, args.jobs, args.build_jobs)
    print(shlex.join(command), flush=True)
    return subprocess.run(command, cwd=TEST_REGRESS, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
