#!/usr/bin/env python3
# DESCRIPTION: Verilator: Reproducible exploratory performance measurements
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
"""Collect checked, interleaved measurements; regenerate reports without rerunning.

The Linux process-group RSS sampler includes concurrent children but is a
sampled estimate. These records cannot establish G-PERF acceptance.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import time

from performance_common import (digest, file_record, is_integer, read_json, require, schedule,
                                write_json)
from performance_report import render


def host_record(affinity):
    """Record available host controls, explicitly retaining unavailable values."""
    governors = {}
    for cpu in affinity:
        path = Path(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_governor')
        governors[str(cpu)] = path.read_text(encoding='utf-8').strip() if path.exists() else None
    return {
        'platform': platform.platform(),
        'cpuinfo': Path('/proc/cpuinfo').read_text(encoding='utf-8'),
        'meminfo': Path('/proc/meminfo').read_text(encoding='utf-8'),
        'affinity': affinity,
        'governors': governors,
        'load_average': list(os.getloadavg()),
        'host_policy': 'shared; exploratory only',
    }


def group_sample(group):
    """Sum simultaneously observed RSS for processes in an isolated group.

    Reading /proc is not atomic. Record the interval and process membership so
    this value cannot be mistaken for a kernel-accounted aggregate peak.
    """
    members = []
    page_bytes = os.sysconf('SC_PAGE_SIZE')
    for path in Path('/proc').glob('[0-9]*/stat'):
        try:
            value = path.read_text(encoding='utf-8')
            fields = value[value.rfind(')') + 2:].split()
            if int(fields[2]) == group and fields[0] != 'Z':
                members.append({
                    'pid': int(path.parent.name),
                    'rss_bytes': int(fields[21]) * page_bytes
                })
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
    return members


def observe_process(process, started, policy, resources):
    """Observe a process group and always reap its leader and remaining children."""
    status, peak, count = 'completed', 0, 0
    try:
        while True:
            members = group_sample(process.pid)
            elapsed = time.monotonic() - started
            rss = sum(member['rss_bytes'] for member in members)
            peak = max(peak, rss)
            count += 1
            resources.write(
                json.dumps(
                    {
                        'elapsed_seconds': elapsed,
                        'members': members,
                        'aggregate_rss_bytes': rss
                    },
                    sort_keys=True) + '\n')
            if process.poll() is not None:
                if group_sample(process.pid):
                    status = 'leftover_children'
                break
            if elapsed >= policy['timeout_seconds']:
                status = 'timeout'
                break
            time.sleep(policy['sample_interval_seconds'])
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
    return {
        'status': status,
        'exit_code': process.returncode,
        'wall_seconds': time.monotonic() - started,
        'sampled_aggregate_peak_rss_bytes': peak,
        'resource_samples': count,
        'rss_method': 'proc_process_group_sampled_estimate'
    }


def measured_command(command, context, policy, directory, prefix=''):
    """Retain output, timing and samples even when a workload fails or times out."""
    started = time.monotonic()
    launch = ['/usr/bin/taskset', '-c', ','.join(map(str, policy['affinity'])), *command]
    with (directory / (prefix + 'stdout.log')).open('wb') as stdout, \
            (directory / (prefix + 'stderr.log')).open('wb') as stderr, \
            (directory / (prefix + 'resources.jsonl')).open('w', encoding='utf-8') as resources:
        with subprocess.Popen(launch,
                              cwd=context['cwd'],
                              env=context['environment'],
                              stdout=stdout,
                              stderr=stderr,
                              start_new_session=True) as process:
            result = observe_process(process, started, policy, resources)
    result['launch_command'] = launch
    return result


def validate_plan(plan):
    """Require an explicit, fixed collection policy before creating records."""
    require(plan['schema_version'] == 1, 'Unsupported performance plan schema')
    require(plan['scope'] == 'exploratory', 'This collector cannot grant performance acceptance')
    require(isinstance(plan['cache_policy'], str) and plan['cache_policy'], 'Missing cache policy')
    for key, minimum in [('warmups', 1), ('pairs', 7), ('bootstrap_resamples', 10000)]:
        require(is_integer(plan[key]) and plan[key] >= minimum, f'Invalid {key}')
    require(is_integer(plan['bootstrap_seed']), 'Missing bootstrap seed')
    require(0.005 <= plan['sample_interval_seconds'] <= 1, 'Invalid sample interval')
    require(0 < plan['timeout_seconds'] <= 3600, 'Invalid timeout')
    affinity = plan['affinity']
    require(
        affinity and all(is_integer(cpu) for cpu in affinity)
        and set(affinity) <= os.sched_getaffinity(0), 'Unavailable CPU affinity')
    require(len(affinity) == len(set(affinity)), 'Duplicate CPU affinity')
    ids = set()
    for workload in plan['workloads']:
        identifier = workload['id']
        require(
            isinstance(identifier, str) and identifier.replace('-', '').replace('_', '').isalnum(),
            'Invalid workload identifier')
        require(identifier not in ids, 'Duplicate workload')
        ids.add(identifier)
        require(
            workload['phase'] in ('simulation', 'compile_clean', 'compile_incremental',
                                  'solver_startup', 'lifecycle'), 'Unknown measurement phase')
        require(workload['unit'] and workload['category'] and workload['size'],
                'Missing workload identity')
        require(set(workload['variants']) == {'baseline', 'candidate'}, 'Expected both variants')
        for variant in workload['variants'].values():
            require(variant['revision'] and variant['inputs'], 'Missing source provenance')
            for name in ('command', 'checker'):
                require(
                    isinstance(variant[name], list) and variant[name]
                    and all(isinstance(arg, str) and arg for arg in variant[name]), 'Invalid argv')
                require(
                    Path(variant[name][0]).is_absolute(), 'Command executable must be absolute')
            require(
                Path(variant['cwd']).is_absolute() and Path(variant['cwd']).is_dir(),
                'Invalid cwd')
            require(
                all(
                    isinstance(key, str) and isinstance(value, str)
                    for key, value in variant['environment'].items()), 'Invalid environment')
            require('{stdout}' in variant['checker'] and '{result}' in variant['checker'],
                    'Checker must read the captured output and write a result')
    require(ids, 'Empty workload set')


def freeze_inputs(plan):
    """Pin all declared inputs and the actual command/checker executables."""
    result = {}
    for workload in plan['workloads']:
        for name, variant in workload['variants'].items():
            paths = [
                *variant['inputs'], variant['command'][0], variant['checker'][0],
                '/usr/bin/taskset'
            ]
            paths.extend(arg for arg in variant['checker'][1:]
                         if Path(arg).is_absolute() and Path(arg).is_file())
            if not workload['phase'].startswith('compile_'):
                paths.append(variant['artifact'])
            result[workload['id'] + '/' +
                   name] = [file_record(path) for path in sorted(set(paths))]
    return result


def check_output(variant, context, plan, directory):
    """Check measured output outside timing, with the same process cleanup policy."""
    result_path = directory / 'checked.json'
    substitutions = {'{stdout}': str(directory / 'stdout.log'), '{result}': str(result_path)}
    checker = [substitutions.get(arg, arg) for arg in variant['checker']]
    checked = measured_command(checker, context, plan, directory, prefix='checker.')
    record = {'checker_measurement': checked}
    if checked['exit_code'] == 0 and checked['status'] == 'completed':
        try:
            result = read_json(result_path)
            require(result['status'] == 'pass', 'Checker did not verify output')
            require(
                is_integer(result['work_units']) and result['work_units'] > 0,
                'Checker must count actual completed work')
            require(
                len(result['semantic_sha256']) == 64
                and all(c in '0123456789abcdef' for c in result['semantic_sha256']),
                'Checker must hash meaningful results')
            record['correctness'] = result
        except (ValueError, TypeError, KeyError, FileNotFoundError) as error:
            record['checker_error'] = str(error)
    return record


def collect_sample(plan, item, ordinal, frozen, output):
    """Run one sample and its independent correctness checker outside timing."""
    workload, variant_name, kind, pair = item
    variant = workload['variants'][variant_name]
    directory = output / f'{ordinal:05d}'
    directory.mkdir()
    identities = frozen[workload['id'] + '/' + variant_name]
    require(all(file_record(identity['path']) == identity for identity in identities),
            'Input changed after policy freeze')
    context = {
        'cwd': variant['cwd'],
        'environment': {
            'PATH': os.defpath,
            'LC_ALL': 'C',
            'TZ': 'UTC',
            **variant['environment']
        }
    }
    command = [arg.replace('{sample_dir}', str(directory)) for arg in variant['command']]
    record = {
        'schema_version': 1,
        'ordinal': ordinal,
        'workload': workload['id'],
        'variant': variant_name,
        'kind': kind,
        'pair': pair,
        'measurement': measured_command(command, context, plan, directory),
        'correctness': {
            'status': 'not_checked'
        },
        'environment': context['environment'],
        'load_average_after': list(os.getloadavg())
    }
    if record['measurement']['status'] == 'completed' and record['measurement']['exit_code'] == 0:
        record.update(check_output(variant, context, plan, directory))
    return finish_sample(record, identities, variant, directory)


def finish_sample(record, identities, variant, directory):
    """Record artifact identity and preserve every raw result, including failures."""
    record['inputs_unchanged'] = all(
        Path(item['path']).is_file() and file_record(item['path']) == item for item in identities)
    artifact = Path(variant['artifact'])
    record['artifact_bytes'] = artifact.stat().st_size if artifact.is_file() else None
    record['artifact_sha256'] = digest(artifact) if artifact.is_file() else None
    if not artifact.is_file():
        record['correctness'] = {'status': 'missing_artifact'}
    record['files'] = {
        path.name: {
            'sha256': digest(path),
            'bytes': path.stat().st_size
        }
        for path in sorted(directory.iterdir()) if path.is_file()
    }
    write_json(directory / 'sample.json', record)
    return record


def collect(plan_path, output):
    """Create a new bundle; never reuse or silently prune an earlier run."""
    plan = read_json(plan_path)
    validate_plan(plan)
    frozen = freeze_inputs(plan)
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    write_json(output / 'plan.json', plan)
    write_json(output / 'inputs.json', frozen)
    write_json(output / 'host.json', host_record(plan['affinity']))
    for path in (Path(__file__), Path(__file__).with_name('performance_report.py'),
                 Path(__file__).with_name('performance_common.py')):
        shutil.copy2(path, output / path.name)
    root_files = {path.name: digest(path) for path in output.iterdir()}
    write_json(output / 'bundle.json', {'schema_version': 1, 'files': root_files})
    (output / 'journal.jsonl').touch()
    passed = True
    for ordinal, (workload, side, kind, pair) in enumerate(schedule(plan)):
        record = collect_sample(plan, (workload, side, kind, pair), ordinal, frozen, output)
        with (output / 'journal.jsonl').open('a', encoding='utf-8') as journal:
            journal.write(
                json.dumps(
                    {
                        'ordinal': ordinal,
                        'sha256': digest(output / f'{ordinal:05d}' / 'sample.json')
                    },
                    sort_keys=True) + '\n')
            journal.flush()
            os.fsync(journal.fileno())
        passed &= (record['correctness']['status'] == 'pass' and record['inputs_unchanged'])
        print(
            f'{ordinal}: {workload["id"]} {side} {kind} {pair}: '
            f'{record["correctness"]["status"]}',
            flush=True)
    render(output)
    return passed


def main():
    """Collect from a reviewed local plan or regenerate a saved report."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    command = commands.add_parser('collect')
    command.add_argument('--plan', type=Path, required=True)
    command.add_argument('--output', type=Path, required=True)
    command = commands.add_parser('report')
    command.add_argument('bundle', type=Path)
    args = parser.parse_args()
    if args.action == 'collect':
        return 0 if collect(args.plan, args.output) else 1
    render(args.bundle)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
