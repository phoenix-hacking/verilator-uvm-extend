#!/usr/bin/env python3
# DESCRIPTION: Verilator: Performance evidence integrity and measurement controls
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
"""Exercise actual process/resource collection and deliberate evidence corruption."""

import contextlib
import copy
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from performance import (collect, collect_sample, digest, freeze_inputs, measured_command,
                         read_json, validate_plan, write_json)
from performance_report import paired_interval, render, summarize

WORKER = '''import subprocess, sys, time
if sys.argv[1] == 'child':
    allocation = bytearray(24 * 1024 * 1024)
    for i in range(0, len(allocation), 4096): allocation[i] = 1
    time.sleep(0.5)
elif sys.argv[1] == 'group':
    children = [subprocess.Popen([sys.executable, __file__, 'child']) for _ in range(2)]
    for child in children: child.wait()
elif sys.argv[1] == 'timeout':
    time.sleep(5)
elif sys.argv[1] == 'fail':
    print('PASS 7')
    sys.exit(9)
else:
    print('PASS 7')
'''

CHECKER = '''import hashlib, json, pathlib, sys
value = pathlib.Path(sys.argv[1]).read_text()
if value.strip() != 'PASS 7': sys.exit(4)
pathlib.Path(sys.argv[2]).write_text(json.dumps({
    'status': 'pass', 'work_units': 7,
    'semantic_sha256': hashlib.sha256(b'7').hexdigest()}))
'''


class PerformanceTest(unittest.TestCase):
    """Measurements are useful only when both data and comparison remain valid."""

    def setUp(self):
        stack = contextlib.ExitStack()
        self.addCleanup(stack.close)
        self.root = Path(stack.enter_context(tempfile.TemporaryDirectory()))
        self.worker = self.root / 'worker.py'
        self.checker = self.root / 'checker.py'
        self.worker.write_text(WORKER, encoding='utf-8')
        self.checker.write_text(CHECKER, encoding='utf-8')
        self.affinity = [min(os.sched_getaffinity(0))]
        variant = {
            'command': [sys.executable, str(self.worker), 'ok'],
            'checker': [sys.executable, str(self.checker), '{stdout}', '{result}'],
            'cwd': str(self.root),
            'environment': {},
            'revision': 'synthetic-test-control',
            'inputs': [str(self.worker), str(self.checker)],
            'artifact': str(self.worker)
        }
        self.plan = {
            'schema_version':
            1,
            'scope':
            'exploratory',
            'cache_policy':
            'inherited',
            'warmups':
            1,
            'pairs':
            7,
            'bootstrap_resamples':
            10000,
            'bootstrap_seed':
            1729,
            'sample_interval_seconds':
            0.01,
            'timeout_seconds':
            10,
            'affinity':
            self.affinity,
            'workloads': [{
                'id': 'control',
                'category': 'collector-test',
                'size': 7,
                'unit': 'operations',
                'phase': 'simulation',
                'variants': {
                    'baseline': variant,
                    'candidate': copy.deepcopy(variant)
                }
            }],
        }

    def bundle(self):
        """Collect a full checked control bundle."""
        plan = self.root / 'plan.json'
        write_json(plan, self.plan)
        output = self.root / 'bundle'
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(collect(plan, output))
        return output

    def test_collect_relocate_and_reproduce(self):
        """Collect relocate and reproduce."""
        bundle = self.bundle()
        report = read_json(bundle / 'report.json')
        self.assertEqual(report['samples_retained'], 16)
        self.assertTrue(report['workloads'][0]['comparison_valid'])
        self.assertFalse(report['workloads'][0]['steady_state_30_seconds'])
        self.assertEqual(report['performance_acceptance'], 'pending')
        self.assertEqual(read_json(bundle / '00004/sample.json')['variant'], 'candidate')
        original = {
            name: digest(bundle / name)
            for name in ['report.json', 'report.md', 'report.html']
        }
        moved = self.root / 'relocated'
        shutil.copytree(bundle, moved)
        render(moved)
        self.assertEqual(original, {name: digest(moved / name) for name in original})
        # Re-render is independent of the original executable/checker files.
        self.worker.unlink()
        self.checker.unlink()
        render(moved)
        self.assertEqual(original, {name: digest(moved / name) for name in original})

    def test_corrupted_output_and_receipt_rejected(self):
        """Corrupted output and receipt rejected."""
        bundle = self.bundle()
        path = bundle / '00000/stdout.log'
        original = path.read_bytes()
        path.write_bytes(b'PASS 8\n')
        with self.assertRaisesRegex(ValueError, 'Raw sample changed'):
            render(bundle)
        path.write_bytes(original)
        receipt = bundle / '00000/sample.json'
        record = read_json(receipt)
        record['measurement']['wall_seconds'] /= 10
        write_json(receipt, record)
        with self.assertRaisesRegex(ValueError, 'Sample receipt changed'):
            render(bundle)

    def test_missing_pair_is_invalid(self):
        """Missing pair is invalid."""
        bundle = self.bundle()
        shutil.rmtree(bundle / '00015')
        path = bundle / 'journal.jsonl'
        path.write_text('\n'.join(path.read_text(encoding='utf-8').splitlines()[:-1]) + '\n',
                        encoding='utf-8')
        report = render(bundle)
        self.assertFalse(report['workloads'][0]['comparison_valid'])
        self.assertIsNone(report['workloads'][0]['paired_throughput_ratio'])

    def test_semantic_mismatch_invalidates_comparison(self):
        """Semantic mismatch invalidates comparison."""
        bundle = self.bundle()
        records = [read_json(path) for path in sorted(bundle.glob('*/sample.json'))]
        records[3]['correctness']['work_units'] = 8
        result = summarize(self.plan['workloads'][0], records, self.plan)
        self.assertFalse(result['comparison_valid'])
        self.assertIn('baseline/candidate semantic work differs', result['invalid_reasons'])
        self.assertIsNone(result['paired_throughput_ratio'])
        records[3]['correctness']['work_units'] = 7
        records[0]['correctness']['status'] = 'fail'
        self.assertFalse(
            summarize(self.plan['workloads'][0], records, self.plan)['comparison_valid'])

    def measure(self, mode, timeout=5):
        """Run one resource or failure control."""
        directory = self.root / mode
        directory.mkdir()
        return measured_command([sys.executable, str(self.worker), mode], {
            'cwd': self.root,
            'environment': {
                'PATH': os.defpath
            }
        }, {
            **self.plan, 'timeout_seconds': timeout
        }, directory)

    def test_aggregate_concurrent_child_memory(self):
        """Aggregate concurrent child memory."""
        result = self.measure('group')
        self.assertEqual(result['exit_code'], 0)
        self.assertEqual(result['status'], 'completed')
        self.assertGreater(result['sampled_aggregate_peak_rss_bytes'], 48 * 1024 * 1024)
        rows = [
            json.loads(line)
            for line in (self.root /
                         'group/resources.jsonl').read_text(encoding='utf-8').splitlines()
        ]
        self.assertTrue(any(len(row['members']) >= 3 for row in rows))

    def test_timeout_and_nonzero_exit_preserved(self):
        """Timeout and nonzero exit preserved."""
        result = self.measure('timeout', timeout=0.05)
        self.assertEqual(result['status'], 'timeout')
        self.assertNotEqual(result['exit_code'], 0)
        result = self.measure('fail')
        self.assertEqual(result['exit_code'], 9)
        self.assertEqual((self.root / 'fail/stdout.log').read_text(encoding='utf-8'), 'PASS 7\n')

    def test_frozen_policy_and_duplicate_keys(self):
        """Frozen policy and duplicate keys."""
        for key, bad in [('pairs', 6), ('warmups', 0), ('bootstrap_resamples', 9999),
                         ('scope', 'production'), ('sample_interval_seconds', 0)]:
            plan = copy.deepcopy(self.plan)
            plan[key] = bad
            with self.assertRaises(ValueError):
                validate_plan(plan)
        path = self.root / 'bad.json'
        for text in ['{"pairs":7,"pairs":8}', '{"x":NaN}']:
            path.write_text(text, encoding='utf-8')
            with self.assertRaises(ValueError):
                read_json(path)

    def test_paired_bootstrap_known_values(self):
        """Paired bootstrap known values."""
        result = paired_interval([2.0] * 7, 1729, 10000)
        for value in result.values():
            self.assertAlmostEqual(value, 2.0)
        values = [0.8, 1.0, 1.1, 0.9, 1.2, 1.3, 1.0]
        self.assertEqual(paired_interval(values, 42, 10000), paired_interval(values, 42, 10000))
        for values in [[0], [float('inf')], []]:
            with self.assertRaises(ValueError):
                paired_interval(values, 42, 10000)

    def test_checker_rejects_actual_wrong_output(self):
        """Checker rejects actual wrong output."""
        self.worker.write_text("print('PASS 8')\n", encoding='utf-8')
        frozen = freeze_inputs(self.plan)
        record = collect_sample(self.plan, (self.plan['workloads'][0], 'baseline', 'sample', 0), 0,
                                frozen, self.root)
        self.assertNotEqual(record['correctness']['status'], 'pass')
        self.assertEqual(record['measurement']['exit_code'], 0)
        self.assertEqual(record['checker_measurement']['exit_code'], 4)

    def test_changed_input_is_rejected_before_measurement(self):
        """Changed input is rejected before measurement."""
        frozen = freeze_inputs(self.plan)
        self.worker.write_text("print('PASS 8')\n", encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Input changed'):
            collect_sample(self.plan, (self.plan['workloads'][0], 'baseline', 'sample', 0), 0,
                           frozen, self.root)
        self.assertFalse((self.root / '00000/stdout.log').exists())

    def test_compile_output_need_not_exist_before_build(self):
        """Compile output need not exist before build."""
        artifact = self.root / 'compiled.bin'
        self.worker.write_text(
            'from pathlib import Path\n'
            f'Path({str(artifact)!r}).write_bytes(b"compiled artifact")\n'
            "print('PASS 7')\n",
            encoding='utf-8')
        workload = self.plan['workloads'][0]
        workload['phase'] = 'compile_clean'
        for variant in workload['variants'].values():
            variant['artifact'] = str(artifact)
        frozen = freeze_inputs(self.plan)
        record = collect_sample(self.plan, (workload, 'baseline', 'sample', 0), 0, frozen,
                                self.root)
        self.assertEqual(record['correctness']['status'], 'pass')
        self.assertTrue(record['inputs_unchanged'])
        self.assertEqual(record['artifact_bytes'], len(b'compiled artifact'))


if __name__ == '__main__':
    unittest.main()
