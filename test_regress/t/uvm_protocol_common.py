# DESCRIPTION: Verilator: Independent sampled APB and AXI protocol oracles
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import re


def samples(text, protocol):
    names = {
        'APB':
        'time reset sel enable write addr wdata strb ready',
        'AXI': ('time reset awvalid awready awaddr awprot wvalid wready wdata wstrb '
                'bvalid bready bresp arvalid arready araddr arprot rvalid rready rdata rresp'),
    }[protocol].split()
    result = []
    for line in text.splitlines():
        if line.startswith(protocol + '_SAMPLE '):
            values = line.split()[1:]
            assert len(values) == len(names), line
            result.append(dict(zip(names, [int(values[0])] + [int(v, 16) for v in values[1:]])))
    assert result, protocol + ': missing physical samples'
    return result


def apb_rules(previous, current):
    result = set()
    if not current['reset']:
        return result
    if current['enable'] and not current['sel']:
        result.add('select')
    if current['sel'] and not current['write'] and current['strb']:
        result.add('strobe')
    if previous is None or not previous['reset'] or not previous['sel']:
        return result
    rule = 'wait' if previous['enable'] else 'setup'
    if rule == 'wait' and previous['ready']:
        return result
    stable = current['sel'] and current['enable']
    stable &= all(previous[key] == current[key] for key in ('addr', 'write', 'strb'))
    for lane in range(4):
        if previous['write'] and previous['strb'] & (1 << lane):
            stable &= ((previous['wdata'] ^ current['wdata']) & (255 << (8 * lane))) == 0
    if not stable:
        result.add(rule)
    return result


def axi_rules(previous, current):
    result = set()
    channels = {
        'aw': ('awaddr', 'awprot'),
        'w': ('wdata', 'wstrb'),
        'b': ('bresp', ),
        'ar': ('araddr', 'arprot'),
        'r': ('rdata', 'rresp')
    }
    if not current['reset']:
        if any(current[channel + 'valid'] for channel in channels):
            result.add('RESET_VALID')
        return result
    if previous is None or not previous['reset']:
        return result
    for channel, payload in channels.items():
        if previous[channel + 'valid'] and not previous[channel + 'ready']:
            if not current[channel + 'valid'] or any(previous[key] != current[key]
                                                     for key in payload):
                result.add(channel.upper() + '_STABLE')
    return result


def first_violation(rows, protocol):
    previous = None
    check = apb_rules if protocol == 'APB' else axi_rules
    for index, current in enumerate(rows):
        rules = check(previous, current)
        if rules:
            return index, rules
        previous = current
    return None


def verify_positive(text, protocol):
    rows = samples(text, protocol)
    assert first_violation(rows, protocol) is None, protocol + ': invalid positive bus trace'
    assert not re.search(r'^UVM_(?:ERROR|FATAL) (?!:)', text, re.M)
    if protocol == 'APB':
        assert any(r['reset'] and r['sel'] and not r['enable'] for r in rows)
        assert any(r['reset'] and r['sel'] and r['enable'] and not r['ready'] for r in rows)
        assert any(r['reset'] and r['sel'] and r['enable'] and r['ready'] for r in rows)
    else:
        for channel in ('aw', 'w', 'b', 'ar', 'r'):
            assert any(r['reset'] and r[channel + 'valid'] and not r[channel + 'ready']
                       for r in rows)
            assert any(r['reset'] and r[channel + 'valid'] and r[channel + 'ready'] for r in rows)
    assert any(not r['reset'] for r in rows)
    return rows


def compare_faults(sva_text, monitor_text, protocol, rule):
    traces = []
    for is_sva, text in ((True, sva_text), (False, monitor_text)):
        assert '** UVM ' + protocol + ' ENV PASSED **' not in text
        rows = samples(text, protocol)
        violation = first_violation(rows, protocol)
        assert violation is not None, (protocol, rule, 'fault did not reach physical bus')
        index, rules = violation
        assert rule in rules, (protocol, rule, rules)
        # Falling-edge samples describe the signals checked at the next rising
        # edge. Both oracles must stop on that first independently invalid cycle.
        assert all(right['time'] - left['time'] == 10 for left, right in zip(rows, rows[1:]))
        expected_time = rows[index]['time'] + 5
        if is_sva:
            diagnostics = re.findall(r'^' + protocol + r'_ASSERTION (\w+) time=(\d+)$', text, re.M)
            assert diagnostics and diagnostics[0] == (rule, str(expected_time)), diagnostics
            assert not re.search(r'^UVM_FATAL (?!:)', text, re.M)
        else:
            fatal = re.search(r'^UVM_FATAL (?!:).+$', text, re.M)
            assert fatal and '[' + protocol + '_PROTOCOL]' in fatal.group(), text[-1500:]
            when = re.search(r' @ (\d+):', fatal.group())
            assert when and int(when.group(1)) == expected_time, fatal.group()
            assert not re.search(r'^' + protocol + '_ASSERTION ', text, re.M)
        traces.append(rows[:index + 1])
    assert traces[0] == traces[1], (protocol, rule, 'oracles received different bus prefixes')
    return len(traces[0])


def verify_unused_apb(text):
    rows = verify_positive(text, 'APB')
    changed = [False, False]
    for before, after in zip(rows, rows[1:]):
        if (before['reset'] and after['reset'] and before['sel'] and after['sel']
                and (not before['enable'] or not before['ready'])
                and before['wdata'] != after['wdata']):
            changed[before['write']] = True
    assert all(changed), 'Missing legal unused read/write data changes'
