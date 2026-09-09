#!/usr/bin/env python3
# DESCRIPTION: Verilator: Deterministic checked performance dashboard
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
"""Validate raw bundles and report paired exploratory results without acceptance."""

from __future__ import annotations

import html
import json
import math
from pathlib import Path
import random
import statistics

from performance_common import digest, read_json, require, schedule, write_json


def paired_interval(ratios, seed, resamples):
    """Paired percentile bootstrap interval of the geometric mean ratio."""
    if not ratios or any(not math.isfinite(value) or value <= 0 for value in ratios):
        raise ValueError('Ratios must be finite and positive')
    if resamples < 10000:
        raise ValueError('At least 10000 bootstrap resamples are required')
    logs = [math.log(value) for value in ratios]
    rng = random.Random(seed)
    means = sorted(
        math.exp(statistics.fmean(rng.choices(logs, k=len(logs)))) for _ in range(resamples))
    # Fixed order statistics, frozen in the archived report implementation.
    return {
        'geomean': math.exp(statistics.fmean(logs)),
        'low95': means[int(0.025 * resamples)],
        'high95': means[math.ceil(0.975 * resamples) - 1]
    }


def variant_metrics(samples):
    """Preserve every paired metric value for both comparison variants."""
    variants = {}
    for name in ('baseline', 'candidate'):
        selected = [record for record in samples if record['variant'] == name]
        variants[name] = {
            'wall_seconds': [record['measurement']['wall_seconds'] for record in selected],
            'sampled_aggregate_peak_rss_bytes':
            [record['measurement']['sampled_aggregate_peak_rss_bytes'] for record in selected],
            'artifact_bytes': [record['artifact_bytes'] for record in selected],
            'units_per_second': [
                record['correctness']['work_units'] / record['measurement']['wall_seconds']
                if record['correctness']['status'] == 'pass' else None for record in selected
            ],
        }
    return variants


def summarize(workload, records, plan):
    """Reject failed warmups, missing pairs and mismatched semantic work."""
    reasons = []
    if len(records) != 2 * (plan['pairs'] + plan['warmups']):
        reasons.append('missing samples or warmups')
    for record in records:
        measurement = record['measurement']
        if (record['correctness']['status'] != 'pass' or not record['inputs_unchanged']
                or measurement['status'] != 'completed' or measurement['exit_code'] != 0):
            reasons.append('failed correctness, command or input identity')
        if not math.isfinite(measurement['wall_seconds']) or measurement['wall_seconds'] <= 0:
            reasons.append('invalid measured duration')
    samples = [record for record in records if record['kind'] == 'sample']
    pairs = {}
    for record in samples:
        pair = pairs.setdefault(record['pair'], {})
        if record['variant'] in pair:
            reasons.append('duplicate paired sample')
        pair[record['variant']] = record
    ratios = []
    for pair in pairs.values():
        if set(pair) != {'baseline', 'candidate'}:
            reasons.append('unpaired measurement')
            continue
        baseline, candidate = pair['baseline'], pair['candidate']
        if baseline['correctness'] != candidate['correctness']:
            reasons.append('baseline/candidate semantic work differs')
        ratios.append(baseline['measurement']['wall_seconds'] /
                      candidate['measurement']['wall_seconds'])
    variants = variant_metrics(samples)
    valid = not reasons
    return {
        'id':
        workload['id'],
        'category':
        workload['category'],
        'size':
        workload['size'],
        'phase':
        workload['phase'],
        'unit':
        workload['unit'],
        'comparison_valid':
        valid,
        'invalid_reasons':
        sorted(set(reasons)),
        'variants':
        variants,
        'same_artifact_control':
        bool(samples) and len({record['artifact_sha256']
                               for record in samples}) == 1,
        'paired_throughput_ratio':
        paired_interval(ratios, plan['bootstrap_seed'], plan['bootstrap_resamples'])
        if valid else None,
        'steady_state_30_seconds':
        bool(samples) and all(record['measurement']['wall_seconds'] >= 30 for record in samples),
        'performance_acceptance':
        'pending'
    }


def check_raw_sample(path, record):
    """Recalculate raw identities and process-group resource accounting."""
    for name, identity in record['files'].items():
        require(Path(name).name == name, 'Invalid sample file path')
        raw = path.parent / name
        require(raw.stat().st_size == identity['bytes'] and digest(raw) == identity['sha256'],
                f'Raw sample changed: {raw}')
    if record['correctness']['status'] == 'pass':
        require(
            read_json(path.parent / 'checked.json') == record['correctness'],
            'Checked result differs from sample')
    resources = [
        json.loads(line)
        for line in (path.parent / 'resources.jsonl').read_text(encoding='utf-8').splitlines()
    ]
    require(
        len(resources) == record['measurement']['resource_samples'] and resources,
        'Missing resource samples')
    for resource in resources:
        require(
            sum(member['rss_bytes']
                for member in resource['members']) == resource['aggregate_rss_bytes'],
            'Incorrect aggregate RSS')
    require(
        max(resource['aggregate_rss_bytes'] for resource in resources) == record['measurement']
        ['sampled_aggregate_peak_rss_bytes'], 'Incorrect RSS peak')


def check_sample(path, ordinal, expected_item, journal_entry):
    """Validate one sealed receipt against the frozen schedule."""
    require(journal_entry == {
        'ordinal': ordinal,
        'sha256': digest(path)
    }, 'Sample receipt changed')
    record = read_json(path)
    require(
        math.isfinite(record['measurement']['wall_seconds'])
        and record['measurement']['wall_seconds'] > 0, 'Invalid wall time')
    workload, side, kind, pair = expected_item
    require(path.parent.name == f'{ordinal:05d}' and record['ordinal'] == ordinal,
            'Missing or reordered sample')
    require((record['workload'], record['variant'], record['kind'],
             record['pair']) == (workload['id'], side, kind, pair), 'Frozen interleaving changed')
    check_raw_sample(path, record)
    return record


def read_bundle(bundle):
    """Read a frozen bundle and validate its sample ordering and identities."""
    bundle = Path(bundle)
    manifest = read_json(bundle / 'bundle.json')
    require(
        manifest['schema_version'] == 1 and set(manifest['files']) == {
            'plan.json', 'inputs.json', 'host.json', 'performance.py', 'performance_report.py',
            'performance_common.py'
        }, 'Incomplete bundle provenance')
    for name, expected in manifest['files'].items():
        require(Path(name).name == name, 'Invalid bundle path')
        require(digest(bundle / name) == expected, f'Bundle input changed: {name}')
    plan = read_json(bundle / 'plan.json')
    expected = list(schedule(plan))
    paths = sorted(bundle.glob('[0-9]*/sample.json'))
    journal = [
        json.loads(line)
        for line in (bundle / 'journal.jsonl').read_text(encoding='utf-8').splitlines()
    ]
    require(len(paths) == len(journal), 'Unsealed sample: collection was interrupted')
    require(len(paths) <= len(expected), 'Unexpected extra samples')
    records = []
    for ordinal, path in enumerate(paths):
        records.append(check_sample(path, ordinal, expected[ordinal], journal[ordinal]))
    return plan, records, len(expected)


def render(bundle):
    """Verify all raw digests and regenerate byte-identical JSON/Markdown/HTML."""
    bundle = Path(bundle)
    plan, records, expected_count = read_bundle(bundle)
    rows = [
        summarize(workload, [record
                             for record in records if record['workload'] == workload['id']], plan)
        for workload in plan['workloads']
    ]
    report = {
        'schema_version':
        1,
        'scope':
        'exploratory',
        'performance_acceptance':
        'pending',
        'plan_sha256':
        digest(bundle / 'plan.json'),
        'samples_retained':
        len(records),
        'samples_expected':
        expected_count,
        'workloads':
        rows,
        'limitations': [
            'Shared-host measurements cannot establish production performance.',
            'Process-group RSS is a sampled aggregate estimate; '
            'escaped sessions are outside its scope.',
            'Measured wall time includes taskset launch and resource-sampling overhead.',
            'Warmups are retained and checked; only paired samples enter confidence intervals.',
            'Missing workload domains, clean/incremental builds, solver and lifecycle '
            'evidence remain required.',
            'A reproducible dashboard does not establish optimization, regression limits '
            'or dedicated CI acceptance.',
        ],
    }
    write_json(bundle / 'report.json', report)
    write_markdown(bundle, report)
    write_html(bundle, report)
    return report


def write_markdown(bundle, report):
    """Write a compact portable table and preserve all qualification text."""
    lines = [
        '# Verilator UVM performance dashboard', '',
        '**Exploratory; production acceptance pending.**', '',
        '| Workload | Phase | Size | Baseline units/s | Candidate units/s | '
        'Paired ratio (95% CI) |', '|---|---|---|---:|---:|---:|'
    ]
    for row in report['workloads']:
        ratio = row['paired_throughput_ratio']
        values = [row['variants'][name]['units_per_second'] for name in ('baseline', 'candidate')]
        rates = [
            f'{statistics.median(value):.3f}' if value and all(x is not None
                                                               for x in value) else 'unavailable'
            for value in values
        ]
        estimate = (f'{ratio["geomean"]:.3f} ({ratio["low95"]:.3f}-{ratio["high95"]:.3f})'
                    if ratio else 'invalid: ' + ', '.join(row['invalid_reasons']))
        cells = [row['id'], row['phase'], str(row['size']), *rates, estimate]
        lines.append('| ' +
                     ' | '.join(cell.replace('|', '\\|').replace('\n', ' ')
                                for cell in cells) + ' |')
    lines.extend([
        '', f"Retained samples: {report['samples_retained']}/{report['samples_expected']}.", '',
        *report['limitations'], ''
    ])
    markdown = '\n'.join(lines)
    (bundle / 'report.md').write_text(markdown, encoding='utf-8')


def write_html(bundle, report):
    """Write a standalone escaped HTML dashboard with links to raw metrics."""
    table_rows = []
    for row in report['workloads']:
        ratio = row['paired_throughput_ratio']
        values = [
            row['id'], row['phase'],
            str(row['size']), 'valid exploratory comparison'
            if row['comparison_valid'] else '; '.join(row['invalid_reasons']),
            f'{ratio["geomean"]:.3f} [{ratio["low95"]:.3f}, {ratio["high95"]:.3f}]'
            if ratio else 'unavailable'
        ]
        table_rows.append('<tr>' + ''.join('<td>' + html.escape(value) + '</td>'
                                           for value in values) + '</tr>')
    page = (
        '<!doctype html><html lang="en"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Verilator UVM performance</title><style>'
        'body{font:16px system-ui;max-width:1100px;margin:2rem auto;padding:1rem;color:#19232b}'
        'table{border-collapse:collapse;width:100%}'
        'th,td{padding:.7rem;text-align:left;border-bottom:1px solid #ccd4da}'
        '</style><h1>Verilator UVM performance</h1>'
        '<p><strong>Exploratory; production acceptance pending.</strong></p>'
        '<table><tr><th>Workload</th><th>Phase</th><th>Size</th><th>Checks</th>'
        '<th>Paired ratio (95% CI)</th></tr>' + ''.join(table_rows) + '</table><ul>' +
        ''.join('<li>' + html.escape(item) + '</li>' for item in report['limitations']) +
        '</ul><p>Full raw values: <a href="report.json">report.json</a>. '
        'Collection policy: <a href="plan.json">plan.json</a>.</p></html>\n')
    (bundle / 'report.html').write_text(page, encoding='utf-8')
