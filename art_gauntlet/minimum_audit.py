"""Audit existing minimum-gate evidence without model dispatch, rendering or edits.

Accepts the routing trial's packet format. An audit completion is distinct from
all samples passing: a deliberately invalid control should still be rejected.
"""
import argparse
import math
import subprocess
import time
from pathlib import Path
from .minimum_gate import ROOT, compare, digest, read, write
from .runner import executable


def validate_observation(value, allowed, declared):
    """Require complete, internally consistent worker evidence before publication."""
    required = {'changed', 'allowed_ids', 'declared_delta', 'agreement', 'passed'}
    if not isinstance(value, dict) or not required.issubset(value):
        raise ValueError('Incomplete worker observation')
    def vector(v):
        return (isinstance(v, list) and len(v) == 3
                and all(type(x) in (int, float) and math.isfinite(x) for x in v))
    if (not isinstance(value['allowed_ids'], list)
            or any(type(i) is not int for i in value['allowed_ids'])
            or value['allowed_ids'] != sorted(allowed)
            or not vector(value['declared_delta']) or value['declared_delta'] != declared
            or type(value['agreement']) is not bool or type(value['passed']) is not bool
            or not isinstance(value['changed'], list)):
        raise ValueError('Invalid or misbound worker observation')
    ids = []
    for change in value['changed']:
        if (not isinstance(change, dict) or type(change.get('id')) is not int
                or change['id'] < 0 or not vector(change.get('delta'))
                or not any(abs(x) > 1e-6 for x in change['delta'])):
            raise ValueError('Invalid observed vertex change')
        ids.append(change['id'])
    if ids != sorted(set(ids)):
        raise ValueError('Duplicate or unordered observed vertices')
    agreement = (ids == sorted(allowed)
                 and all(all(abs(x-y) <= 1e-6 for x, y in zip(change['delta'], declared))
                         for change in value['changed']))
    if value['agreement'] != agreement or value['passed'] != agreement:
        raise ValueError('Worker verdict contradicts observed vertex evidence')


def audit(packet_path, output):
    started = time.perf_counter()
    packet_path, output = Path(packet_path).resolve(), Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {'completed': False, 'passed': False, 'samples': {}, 'blender_invocations': 0}
    try:
        packet = read(packet_path)
        base = packet_path.parent
        config_path = (base / packet['config']).resolve()
        config = read(config_path)
        allowed = packet['allowed_vertices']
        if (not allowed or any(type(v) is not int or v < 0 for v in allowed)
                or len(set(allowed)) != len(allowed)
                or sorted(allowed) != sorted(config['editable_vertices'])
                or packet['mesh'] != config['mesh']):
            raise ValueError('Packet scope differs from fixed config')
        if not packet['samples']:
            raise ValueError('No samples to audit')
        baseline = (base / packet['baseline']).resolve()
        folders = {name: (base / spec['folder']).resolve() for name, spec in packet['samples'].items()}
        job = {'mesh': config['mesh'], 'allowed_vertices': allowed,
               'baseline': str(baseline / 'candidate.blend'),
               'output': str(output / 'observed.json'), 'samples': {}}
        inputs = {packet_path, config_path}
        for folder in [baseline, *folders.values()]:
            inputs.update(folder / name for name in ['candidate.blend', 'snapshot.json'])
            inputs.update(folder / f'{view}_{kind}.png' for view in config['views'] for kind in ['id', 'matte'])
        for name, spec in packet['samples'].items():
            delta = spec['declared_delta']
            if (len(delta) != 3 or any(type(v) not in (int, float) or not math.isfinite(v) for v in delta)):
                raise ValueError(f'Invalid declared delta: {name}')
            job['samples'][name] = {'scene': str(folders[name] / 'candidate.blend'), 'declared_delta': delta}
        before = {str(path): digest(path) for path in sorted(inputs)}
        gates = {name: compare(config, baseline, folder) for name, folder in folders.items()}
        write(output / 'job.json', job)
        with (output / 'blender.log').open('w', encoding='utf-8') as log:
            report['blender_invocations'] = 1
            subprocess.run([executable('blender'), '--background', '--factory-startup', '--disable-autoexec',
                            '--python-exit-code', '1', '--python',
                            str(ROOT / 'art_gauntlet/minimum_audit_worker.py'), '--', str(output / 'job.json')],
                           cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        observed = read(output / 'observed.json')
        if not isinstance(observed, dict) or set(observed) != set(gates):
            raise ValueError('Incomplete worker output')
        for name, value in observed.items():
            validate_observation(value, allowed, job['samples'][name]['declared_delta'])
        if before != {str(path): digest(path) for path in sorted(inputs)}:
            raise ValueError('Input evidence changed during audit')
        samples = {}
        for name, gate in gates.items():
            reasons = []
            if not gate['passed']:
                reasons.append('gate comparison failed')
            if not observed[name]['passed']:
                reasons.append('vertex delta audit failed')
            samples[name] = {'gate': gate, 'observed': observed[name],
                             'passed': not reasons, 'reasons': reasons}
        report.update(completed=True, passed=all(s['passed'] for s in samples.values()), samples=samples,
                      scene_opens=1 + len(gates), input_sha256=before)
    except Exception as exc:
        report['error'] = f'{type(exc).__name__}: {exc}'
    report['elapsed_seconds'] = time.perf_counter() - started
    write(output / 'audit.json', report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packet')
    parser.add_argument('output', help='Fresh evidence directory')
    args = parser.parse_args()
    result = audit(args.packet, args.output)
    print(f"completed={result['completed']} passed={result['passed']} report={Path(args.output).resolve() / 'audit.json'}")
    return 2 if not result['completed'] else 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
