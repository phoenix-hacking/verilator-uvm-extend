#!/usr/bin/env python3
# DESCRIPTION: Verilator: Independent SoC benchmark output validation
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
"""Check measured SoC output with the original independent physical traffic oracle.

This adapter counts completed DMA commands, not requested iterations. The full
trace remains enabled in this initial exploratory workload; no optimized or
quiet performance baseline is claimed.
"""

import argparse
import hashlib
import importlib
import json
from pathlib import Path
import sys


def main():
    """Validate every memory/CSR/IRQ observation before returning useful work."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--jobs', type=int, required=True)
    parser.add_argument('--dpi', action='store_true')
    parser.add_argument('stdout', type=Path)
    parser.add_argument('result', type=Path)
    args = parser.parse_args()
    if not __debug__:
        raise RuntimeError('The original semantic oracle requires Python assertions')
    sys.path.insert(0, str(args.source_root / 'test_regress/t'))
    verify_soc = importlib.import_module('uvm_soc_common').verify_soc

    counts, trace = verify_soc(args.stdout.read_text(encoding='utf-8'), args.dpi, args.jobs)
    meaningful = json.dumps({'counts': counts, 'trace': trace}, sort_keys=True).encode()
    args.result.write_text(json.dumps(
        {
            'status': 'pass',
            'work_units': counts['completed'],
            'semantic_sha256': hashlib.sha256(meaningful).hexdigest(),
        },
        sort_keys=True) + '\n',
                           encoding='utf-8')


if __name__ == '__main__':
    main()
