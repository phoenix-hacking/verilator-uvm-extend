# DESCRIPTION: Verilator: Independent UVM subscriber coverage query oracles
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import math
import re


def expected_coverage(protocol, transactions, writes, reads):
    """Derive the item ratios and unweighted counts from driver traffic."""
    sizes = {'direction': 2, 'response': 2}
    if protocol == 'APB':
        sizes['wait_states'] = 3
    else:
        assert protocol == 'AXI'
        sizes.update(byte_enables=16, channel_order=3, outcome=4)
    bins = {name: set() for name in sizes}
    for write, count in [(True, writes), (False, reads)]:
        for fields in transactions[write][:count]:
            _, _, _, _, strobe, response, delay = fields
            error = int(response != '0')
            bins['direction'].add(write)
            bins['response'].add(error)
            if protocol == 'APB':
                bins['wait_states'].add(int(delay))
            else:
                bins['outcome'].add((write, error))
                if write:
                    bins['byte_enables'].add(int(strobe, 16))
                    bins['channel_order'].add(int(delay))
    percentage = 100 * sum(len(bins[name]) / size for name, size in sizes.items()) / len(sizes)
    return percentage, sum(map(len, bins.values())), sum(sizes.values())


def verify_frame(frame, checkpoint, transactions, protocol):
    """Check both query percentages and both pairs of optional output counts."""
    values = dict(re.findall(r'(\w+)=([^ ]+)', frame))
    writes, reads = int(values['writes']), int(values['reads'])
    assert int(values['samples']) == writes + reads == checkpoint, frame
    assert 0 <= writes <= len(transactions[True]) and 0 <= reads <= len(transactions[False])
    percentage, covered, total = expected_coverage(protocol, transactions, writes, reads)
    for key in ('instance', 'type'):
        assert math.isclose(float(values[key]), percentage, rel_tol=0,
                            abs_tol=1e-8), (frame, percentage)
    for prefix in ('', 'type_'):
        assert int(values[prefix + 'covered']) == covered, frame
        assert int(values[prefix + 'total']) == total, frame


def verify_queries(text, protocol):
    """IEEE 1800-2017 19.8/19.11: equal-weight item ratios and raw bin counts.

    Derive observed bins from independent completed driver transactions. AXI
    permits either ordering between read and write, so select each direction's
    prefix separately at the subscriber's reported checkpoint.
    """
    transactions = {False: [], True: []}
    for line in text.splitlines():
        if line.startswith(protocol + '_TRACE '):
            fields = line.split()
            write = fields[1] == ('1' if protocol == 'APB' else 'W')
            transactions[write].append(fields)
    frames = [line for line in text.splitlines() if line.startswith(protocol + '_COVERAGE ')]
    assert len(frames) == 6, (protocol, 'coverage checkpoint count', len(frames))
    checkpoints = [0, 1, 2, 17, 257, sum(map(len, transactions.values()))]
    for frame, checkpoint in zip(frames, checkpoints):
        verify_frame(frame, checkpoint, transactions, protocol)
    return len(frames)
