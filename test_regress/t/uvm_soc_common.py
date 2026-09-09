# DESCRIPTION: Verilator: Independent synthetic SoC memory, CSR and protocol oracle
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

from collections import Counter
from pathlib import Path
import re

from uvm_protocol_common import first_violation, samples


def initial_memory():
    """The fixture's specified reset image, including all untouched bytes."""
    return [(37 * address ^ address // 4 ^ 90) & 255 for address in range(512)]


def physical_memory(text, require_idle=True, require_backpressure=True):
    """Reconstruct completed AXI transactions from sampled physical pins."""
    rows = clocked_samples(text, 'AXI', 14)
    assert first_violation(rows, 'AXI') is None
    pending = {}
    epoch = 0
    in_reset = False
    result = []
    for row in rows:
        if not row['reset']:
            epoch += not in_reset
            in_reset = True
            pending.clear()
            continue
        in_reset = False
        for channel, fields in [('aw', ('awaddr', )), ('w', ('wdata', 'wstrb')),
                                ('ar', ('araddr', ))]:
            if row[channel + 'valid'] and row[channel + 'ready']:
                assert channel not in pending, (channel, row)
                pending[channel] = tuple(row[key] for key in fields)
        if row['bvalid'] and row['bready']:
            assert 'aw' in pending and 'w' in pending and row['bresp'] == 0
            result.append((epoch, 'W', pending.pop('aw')[0], *pending.pop('w')))
        if row['rvalid'] and row['rready']:
            assert 'ar' in pending and row['rresp'] == 0
            result.append((epoch, 'R', pending.pop('ar')[0], row['rdata'], 0))
    assert not require_idle or not pending
    for channel in ('aw', 'w', 'b', 'ar', 'r'):
        assert not require_backpressure or any(
            row['reset'] and row[channel + 'valid'] and not row[channel + 'ready']
            for row in rows), channel + ': missing backpressure'
    return result


def physical_csr(text):
    """Reconstruct each APB access; read response values use the separate model."""
    rows = clocked_samples(text, 'APB', 10)
    assert first_violation(rows, 'APB') is None
    epoch = 0
    in_reset = False
    result = []
    for row in rows:
        if not row['reset']:
            epoch += not in_reset
            in_reset = True
            continue
        in_reset = False
        if row['sel'] and row['enable'] and row['ready']:
            result.append((epoch, row['write'], row['addr'], row['wdata'] if row['write'] else 0,
                           row['strb']))
    assert any(row['reset'] and row['sel'] and row['enable'] and not row['ready'] for row in rows)
    return result


class SocOracle:
    """Check the specified byte-copy/CSR/IRQ contract independently of DUT state."""

    def __init__(self):
        self.memory = initial_memory()
        self.command = None
        self.csr = [0] * 7
        self.counts = {
            'epoch': 0,
            'commands': 0,
            'reads': 0,
            'writes': 0,
            'completed': 0,
            'canceled': 0,
            'irq_edges': 0,
            'snapshots': 0,
            'last_irq': 0,
            'errors': 0
        }
        self.snapshot = 0
        self.trace = []

    def reset(self, fields):
        assert len(fields) == 1
        if self.command:
            assert self.command['finished'] or self.command['canceled']
        self.counts['epoch'] += 1
        assert int(fields[0]) == self.counts['epoch']
        self.memory = initial_memory()
        self.command = None
        self.csr = [0] * 7
        self.counts['last_irq'] = 0

    def begin(self, fields):
        epoch, source, destination, length, enabled = map(int, fields)
        assert epoch == self.counts['epoch']
        assert self.command is None or self.command['finished']
        assert 1 <= length <= 63 and 0 <= source <= 256 - length
        assert 256 <= destination <= 512 - length and enabled in (0, 1)
        assert self.csr[:3] == [source, destination, length] and self.csr[5] == enabled
        self.command = {
            'source': source,
            'destination': destination,
            'length': length,
            'reads': 0,
            'writes': 0,
            'started': False,
            'cleared': False,
            'finished': False,
            'canceled': False
        }
        self.counts['commands'] += 1
        self.trace.append(('command', *map(int, fields)))

    def register(self, fields):
        epoch, write = map(int, fields[:2])
        address, data, strobes = (int(value, 16) for value in fields[2:5])
        error = int(fields[5])
        assert epoch == self.counts['epoch'] and write in (0, 1)
        if error:
            assert address == 28 and write == 0
            self.counts['errors'] += 1
            return
        assert address % 4 == 0 and 0 <= address <= 24
        index = address // 4
        if write:
            self.register_write(index, data, strobes)
        elif index in (0, 1, 2, 5):
            assert data == self.csr[index], (fields, self.csr)
        elif index == 4:
            assert self.command and self.command['started']
            if self.command['cleared']:
                assert data == 0
            else:
                assert data in (1, 2)
                if data == 2:
                    assert self.command['writes'] == self.command['length']
        else:
            raise AssertionError(('unexpected CSR read', fields))

    def register_write(self, index, data, strobes):
        assert 0 <= strobes <= 15
        if index in (0, 1, 2):
            for lane in range(4):
                mask = 255 << (8 * lane)
                if strobes & (1 << lane):
                    self.csr[index] = self.csr[index] & ~mask | data & mask
        elif index == 3:
            assert self.command and not self.command['started'] and data == 1 and strobes == 15
            self.command['started'] = True
        elif index == 5:
            assert data in (0, 1) and strobes == 15
            self.csr[index] = data
        elif index == 6:
            assert self.command and self.command['writes'] == self.command['length']
            assert data == 1 and strobes == 15
            self.command['cleared'] = True
        else:
            raise AssertionError(('unexpected CSR write', index, data, strobes))

    def transfer(self, fields):
        epoch, direction = int(fields[0]), fields[1]
        address, data, strobes = (int(value, 16) for value in fields[2:])
        assert epoch == self.counts['epoch'] and self.command and self.command['started']
        command = self.command
        if direction == 'R':
            expected_address = (command['source'] + command['reads']) & ~3
            expected_data = sum(self.memory[expected_address + lane] << (8 * lane)
                                for lane in range(4))
            assert command['reads'] == command['writes'] < command['length']
            assert (address, data, strobes) == (expected_address, expected_data, 0), fields
            command['reads'] += 1
            self.counts['reads'] += 1
        else:
            assert direction == 'W' and command['reads'] == command['writes'] + 1
            target = command['destination'] + command['writes']
            value = self.memory[command['source'] + command['writes']]
            assert address == target & ~3 and strobes == 1 << (target % 4), fields
            assert data >> (8 * (target % 4)) & 255 == value, fields
            self.memory[target] = value
            command['writes'] += 1
            self.counts['writes'] += 1
        self.trace.append(('dma', epoch, direction, address, data, strobes))

    def interrupt(self, fields):
        epoch, value = map(int, fields)
        assert epoch == self.counts['epoch'] and value in (0, 1)
        assert value != self.counts['last_irq'] and self.command
        assert self.command['writes'] == self.command['length']
        if value:
            assert self.csr[5] == 1 and not self.command['cleared']
        else:
            assert self.command['cleared']
        self.counts['last_irq'] = value
        self.counts['irq_edges'] += 1

    def memory_byte(self, fields):
        epoch, address = map(int, fields[:2])
        value = int(fields[2], 16)
        assert epoch == self.counts['epoch'] and address == self.snapshot
        assert value == self.memory[address], fields
        self.snapshot = (self.snapshot + 1) % 512
        if self.snapshot == 0:
            self.counts['snapshots'] += 1

    def complete(self, fields):
        epoch, count = map(int, fields)
        assert epoch == self.counts['epoch'] and self.command
        assert self.command['reads'] == self.command['writes'] == self.command['length'] == count
        assert self.command[
            'cleared'] and not self.command['finished'] and not self.counts['last_irq']
        self.command['finished'] = True
        self.counts['completed'] += 1

    def cancel(self, fields):
        epoch, writes = map(int, fields)
        assert epoch == self.counts['epoch'] and self.command and not self.command['canceled']
        assert writes == self.command['writes'] and 3 <= writes < self.command['length']
        assert not self.counts['last_irq']
        self.command['canceled'] = True
        self.counts['canceled'] += 1


def verify_soc(text, dpi, jobs=4):
    """Require all independent memory, protocol, reset and IRQ checks to pass."""
    assert text.count('** UVM SOC PASSED **') == 1
    assert not re.search(r'^UVM_(?:ERROR|FATAL) (?!:)', text, re.M)
    oracle = SocOracle()
    handlers = {
        'SOC_RESET': oracle.reset,
        'SOC_COMMAND': oracle.begin,
        'SOC_CSR': oracle.register,
        'SOC_DMA': oracle.transfer,
        'SOC_IRQ': oracle.interrupt,
        'SOC_MEMORY': oracle.memory_byte,
        'SOC_COMPLETE': oracle.complete,
        'SOC_CANCEL': oracle.cancel
    }
    records = [line.split() for line in text.splitlines() if line.startswith('SOC_')]
    for record in records:
        if record[0] in handlers:
            handlers[record[0]](record[1:])
    assert oracle.snapshot == 0
    expected = {
        'commands': jobs + 2,
        'completed': jobs + 1,
        'canceled': 1,
        'irq_edges': 2 * (jobs + 1),
        'snapshots': jobs + 2,
        'errors': 1,
        'epoch': jobs + 2
    }
    for key, value in expected.items():
        assert oracle.counts[key] == value, (key, oracle.counts, expected)
    summary = [record for record in records if record[0] == 'SOC_SUMMARY']
    assert len(summary) == 1
    values = dict(field.split('=') for field in summary[0][1:])
    for key, count in [('jobs', 'completed'), ('canceled', 'canceled'), ('reads', 'reads'),
                       ('writes', 'writes'), ('irq_edges', 'irq_edges')]:
        assert int(values[key]) == oracle.counts[count]
    assert int(values['dpi']) == (512 * (jobs + 2) if dpi else 0)
    assert float(values['coverage']) == 100.0
    verify_observations(text, records)
    return oracle.counts, oracle.trace


def expected_bins(text):
    """Count every subscriber bin from separately checked observable events."""
    result = Counter()
    for line in text.splitlines():
        fields = line.split()
        if not fields or fields[0] not in ('SOC_CSR', 'SOC_DMA', 'SOC_RESET', 'SOC_IRQ'):
            continue
        channel = {'SOC_CSR': 0, 'SOC_DMA': 1, 'SOC_RESET': 2, 'SOC_IRQ': 3}[fields[0]]
        result[f'channel_kind.kinds[{channel}]'] += 1
        if channel < 2:
            write = int(fields[2] == ('1' if channel == 0 else 'W'))
            result[f'direction.auto_{write}'] += 1
            if channel == 0:
                result[f'response.auto_{int(fields[6])}'] += 1
            elif write:
                mask = int(fields[5], 16)
                assert mask in (1, 2, 4, 8)
                result[f'byte_lane.lanes[{mask.bit_length() - 1}]'] += 1
    assert len(result) == 12 and all(result.values())
    return result


def read_bins(path):
    """Require exactly the twelve normal subscriber bins, without duplicates."""
    result = Counter()
    for metadata, count in re.findall(r"C '([^']*)' (\d+)",
                                      Path(path).read_text(encoding='utf-8')):
        fields = dict(
            field.split('\x02', 1) for field in metadata.split('\x01') if '\x02' in field)
        hierarchy = fields.get('h', '')
        if 'transfers.' in hierarchy:
            name = hierarchy.split('transfers.', 1)[1]
            assert name not in result, name
            result[name] = int(count)
    assert len(result) == 12
    return result


def verify_report(path, bins, source):
    """Validate LCOV locations and branch/line hits from expected merged bins."""
    locations = {}
    for number, line in enumerate(Path(source).read_text(encoding='utf-8').splitlines(), 1):
        match = re.match(r'\s*(\w+): coverpoint ', line)
        if match:
            assert match[1] not in locations
            locations[match[1]] = number
    branches = Counter((locations[name.split('.', 1)[0]], count) for name, count in bins.items())
    sections = [
        part for part in Path(path).read_text(encoding='utf-8').split('end_of_record')
        if re.search(r'^SF:.*t_uvm_soc.v$', part, re.M)
    ]
    assert len(sections) == 1
    actual = Counter(
        (int(line), int(count))
        for line, count in re.findall(r'^BRDA:(\d+),\d+,\d+,(\d+)$', sections[0], re.M))
    assert actual == branches, (actual, branches)
    line_hits = {}
    for line, count in branches:
        line_hits[line] = max(line_hits.get(line, 0), count)
    assert dict((int(line), int(count))
                for line, count in re.findall(r'^DA:(\d+),(\d+)$', sections[0], re.M)) == line_hits


def physical_irq(text):
    epoch = 0
    in_reset = False
    previous = 0
    result = []
    rows = [line.split() for line in text.splitlines() if line.startswith('SOC_IRQ_SAMPLE ')]
    assert rows
    for row in rows:
        reset, value = map(int, row[2:])
        if not reset:
            epoch += not in_reset
            in_reset = True
            previous = 0
        else:
            in_reset = False
            if value != previous:
                result.append((epoch, value))
                previous = value
    return result


def verify_oracle_controls(text, dpi, jobs=4):
    """Prove the checker rejects wrong data, strobes, memory, IRQs and bus traces."""
    cases = [('SOC_DMA', lambda r: r[2] == 'R', 4), ('SOC_DMA', lambda r: r[2] == 'W', 5),
             ('SOC_MEMORY', lambda r: True, 3), ('SOC_IRQ', lambda r: True, 2),
             ('SOC_CSR', lambda r: r[2] == '0' and r[3] in ('0', '4', '8'), 4),
             ('AXI_SAMPLE', lambda r: r[18:20] == ['1', '1'], 20)]
    variants = []
    for prefix, predicate, index in cases:
        original = next(line for line in text.splitlines()
                        if line.startswith(prefix + ' ') and predicate(line.split()))
        fields = original.split()
        fields[index] = f'{int(fields[index], 16) ^ 1:x}'
        variants.append(text.replace(original, ' '.join(fields), 1))
    original = next(line for line in text.splitlines() if line.startswith('SOC_CANCEL '))
    variants.append(text.replace(original, '', 1))
    for variant in variants:
        try:
            verify_soc(variant, dpi, jobs)
        except AssertionError:
            pass
        else:
            raise AssertionError('Independent SoC checker accepted corrupted evidence')
    return len(variants)


def verify_fault(text, fault):
    """Check each deliberate fault reached its intended stimulus and diagnostic."""
    diagnostics = {
        'CORRUPT_DATA': 'SOC_SCOREBOARD',
        'SUPPRESS_IRQ': 'SOC_IRQ',
        'SPURIOUS_IRQ': 'SOC_IRQ',
        'RESUME_CANCELED': 'SOC_SCOREBOARD',
        'CORRUPT_REFERENCE': 'SOC_DPI'
    }
    first = re.search(r'^UVM_FATAL (?!:).+$', text, re.M)
    assert first and '[' + diagnostics[fault] + ']' in first.group(), first
    assert '** UVM SOC PASSED **' not in text
    commands = [
        list(map(int,
                 line.split()[1:])) for line in text.splitlines()
        if line.startswith('SOC_COMMAND ')
    ]
    assert commands
    transfers = physical_memory(text, require_idle=False, require_backpressure=False)
    if fault == 'CORRUPT_DATA':
        epoch, direction, address, data, strobes = transfers[-1]
        command = commands[0]
        assert direction == 'W' and epoch == command[0]
        assert address == command[2] & ~3 and strobes == 1 << (command[2] % 4)
        assert data >> (8 * (command[2] % 4)) & 255 != initial_memory()[command[1]]
    elif fault == 'RESUME_CANCELED':
        assert re.search(r'^SOC_CANCEL \d+ [3-9]\d*$', text, re.M)
        assert transfers[-1][0] > commands[-1][0], 'No unsolicited transfer after reset'
    elif fault == 'SPURIOUS_IRQ':
        assert physical_irq(text) == [(commands[0][0], 1)]
        assert sum(t[1] == 'W' for t in transfers) < commands[0][3]
    elif fault == 'SUPPRESS_IRQ':
        assert sum(t[1] == 'W' for t in transfers) == commands[0][3]
        assert not physical_irq(text)
        assert re.search(r'^SOC_CSR \d+ 1 14 00000001 f 0$', text, re.M)
    else:
        assert sum(t[1] == 'W' for t in transfers) == commands[0][3]
        assert 'C memory[0] got=91 expected=90' in first.group()


def verify_observations(text, records):
    """Match all UVM bus and interrupt observations to independent sampled pins."""
    memory_records = [(int(r[1]), r[2], *[int(v, 16) for v in r[3:]]) for r in records
                      if r[0] == 'SOC_DMA']
    assert memory_records == physical_memory(text), 'UVM observations differ from AXI pins'
    csr_records = [(int(r[1]), int(r[2]), int(r[3], 16), int(r[4], 16) if int(r[2]) else 0,
                    int(r[5], 16)) for r in records if r[0] == 'SOC_CSR']
    assert csr_records == physical_csr(text), 'UVM observations differ from APB pins'
    irq_records = [(int(r[1]), int(r[2])) for r in records if r[0] == 'SOC_IRQ']
    assert irq_records == physical_irq(text), 'UVM IRQ observations differ from sampled pin'


def clocked_samples(text, protocol, period):
    """Both distinct clocks must advance throughout the observed run."""
    rows = samples(text, protocol)
    assert all(after['time'] - before['time'] == period
               for before, after in zip(rows, rows[1:])), protocol
    return rows
