#!/usr/bin/env python3
# DESCRIPTION: Verilator: Shared performance evidence identities and ordering
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
"""Stable artifact identities, strict JSON and frozen measurement scheduling."""

import hashlib
import json
from pathlib import Path


def is_integer(value):
    """JSON booleans are not valid numeric policy/count fields."""
    return isinstance(value, int) and not isinstance(value, bool)


def require(condition, message):
    """Raise a persistent validation error, including under python -O."""
    if not condition:
        raise ValueError(message)


def read_json(path):
    """Reject duplicate keys and non-finite JSON numbers."""

    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f'Duplicate JSON key: {key}')
            result[key] = value
        return result

    def invalid(value):
        raise ValueError(f'Non-finite JSON value: {value}')

    return json.loads(Path(path).read_text(encoding='utf-8'),
                      object_pairs_hook=unique,
                      parse_constant=invalid)


def write_json(path, value):
    """Write stable JSON, refusing non-finite values."""
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n',
                          encoding='utf-8')


def digest(path):
    """Hash an artifact without loading executable-sized inputs into memory."""
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def file_record(path):
    """Record immutable input identity."""
    path = Path(path).resolve()
    return {'path': str(path), 'bytes': path.stat().st_size, 'sha256': digest(path)}


def schedule(plan):
    """Warm both sides, then alternate AB/BA order in each matched pair."""
    for workload in plan['workloads']:
        for kind, count in [('warmup', plan['warmups']), ('sample', plan['pairs'])]:
            for pair in range(count):
                sides = ('baseline', 'candidate') if pair % 2 == 0 else ('candidate', 'baseline')
                for side in sides:
                    yield workload, side, kind, pair
