"""Bounded, qualification-first routing experiment. Production code is read-only."""
import argparse
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'artifacts/routing_trial_01/audit_packet'
REFERENCE = ROOT / 'artifacts/independent_audit_20260911_010326'
CASES = ['incomplete_observations', 'late_malformed_sample', 'original_samples',
         'missing_image', 'scope_mismatch', 'worker_nonzero']
ORDER = ['A', 'B', 'C', 'B', 'C', 'A', 'C', 'A', 'B']

def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def write(p, x): Path(p).write_text(json.dumps(x, indent=2, sort_keys=True), encoding='utf-8')
def utc(): return datetime.now(timezone.utc).isoformat()
def digest(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def manifest(paths): return {str(p.resolve()): digest(p) for p in sorted(set(paths))}
def files(folder): return [p for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
def check(condition, reason):
    if not condition: raise ValueError(reason)
def unchanged(mapping): return all(Path(p).is_file() and digest(p) == h for p, h in mapping.items())

def inputs(folder):
    packet = read(folder / 'packet.json')
    paths = [folder / 'packet.json', folder / packet['config']]
    config = read(folder / packet['config'])
    for name in [packet['baseline'], *[s['folder'] for s in packet['samples'].values()]]:
        paths.extend(folder / name / f for f in ['candidate.blend', 'snapshot.json',
                     *[f'{v}_{k}.png' for v in config['views'] for k in ('id', 'matte')]])
    return paths

def freeze():
    paths = files(ROOT / 'art_gauntlet') + files(SOURCE) + files(Path(__file__).parent)
    paths += [ROOT / 'ART_GAUNTLET_RETENTION_CONTRACT.md', REFERENCE / 'independent.json',
              REFERENCE / 'protected_final.json', REFERENCE / 'observer/sitecustomize.py']
    return manifest(paths)

def fresh_copy(target):
    start = time.perf_counter()
    shutil.copytree(SOURCE, target, ignore=shutil.ignore_patterns('luna_audit.json', '*_blender.json', '__pycache__'))
    return time.perf_counter() - start

def run_process(command, output, extra_env=None):
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1',
               PYTHONPATH=str(REFERENCE / 'observer') + os.pathsep + str(ROOT),
               INDEPENDENT_AUDIT_TRACE=str(output / 'processes.jsonl'))
    if extra_env: env.update(extra_env)
    began = utc()
    with (output / 'console.log').open('w', encoding='utf-8') as log:
        start = time.perf_counter()
        try:
            proc = subprocess.run(list(map(str, command)), cwd=ROOT, env=env, stdout=log,
                                  stderr=subprocess.STDOUT, timeout=240)
            code, error = proc.returncode, None
        except (OSError, subprocess.TimeoutExpired) as exc:
            code, error = None, f'{type(exc).__name__}: {exc}'
        elapsed = time.perf_counter() - start
    trace = output / 'processes.jsonl'
    events = [json.loads(line) for line in trace.read_text().splitlines()] if trace.exists() else []
    scene_reads = []
    for event in events:
        if event.get('console') and Path(event['console']).exists():
            scene_reads += [s for s in Path(event['console']).read_text(errors='replace').splitlines() if 'Read blend:' in s]
    result = {'command': list(map(str, command)), 'started_utc': began, 'finished_utc': utc(),
              'process_wall_seconds': elapsed, 'exit_code': code, 'execution_error': error,
              'actual_blender_starts': len(events), 'scene_opens': len(scene_reads), 'scene_read_lines': scene_reads}
    write(output / 'measurement.json', result)
    return result

def load_study(folder):
    folder = Path(folder).resolve()
    protocol, state = read(folder / 'protocol.json'), read(folder / 'state.json')
    check(digest(folder / 'protocol.json') == state['protocol_sha256'], 'Protocol changed; start a fresh study')
    check(unchanged(protocol['frozen_sha256']), 'Frozen implementation/input changed; start a fresh study')
    return folder, protocol, state

def save_state(folder, state): write(folder / 'state.json', state)

def initialize(folder, strong_model, cheap_model):
    check(strong_model != cheap_model, 'A and B require distinct frozen model identifiers')
    folder = Path(folder).resolve()
    folder.mkdir(parents=True, exist_ok=False)
    reference_hashes = read(REFERENCE / 'protected_final.json')
    # Trust only the previously independently checked fixture, with its bytes bound.
    for path in inputs(SOURCE):
        check(digest(path) == reference_hashes[str(path.relative_to(ROOT))], f'Independent fixture binding failed: {path}')
    write(folder / 'protocol.json', {
        'version': 1, 'created_utc': utc(), 'hypothesis': 'Scripted mechanical audit preserves correctness while reducing total cost/effort.',
        'qualification_order': CASES, 'stopping_rule': 'Stop on first failed qualification or arm result; no model dispatch before qualification passes. No retries within a study.',
        'qualification_reference': str(REFERENCE / 'independent.json'),
        'arms': {'A': {'model': strong_model, 'path': 'unchanged legacy scripts'},
                 'B': {'model': cheap_model, 'path': 'unchanged legacy scripts'},
                 'C': {'model': None, 'path': 'unchanged deterministic command'}},
        'schedule': [{'slot': i+1, 'batch': i//3+1, 'arm': arm} for i, arm in enumerate(ORDER)],
        'case_acceptance': 'Original packet: exit 1, completed true and exact independent nested results. Faults: exit 2, completed false, passed false, explicit error, no successful samples.',
        'arm_acceptance': 'Exact nested independent results; valid process exit (legacy 0, CLI 1); unchanged inputs; no unrecorded repairs. Compare only completed batches.',
        'economic_decision': 'Require all correctness checks, C intervention count no higher than either model arm, and lower C median task wall time or comparable complete billed cost evidence. No monetary claim without total-cost receipts including coordinator effort. Setup break-even unavailable without sourced setup cost.',
        'limits': 'Three batches of the same three unique scenes. No statistics/generalization, new scenes, rendering, art scores, source edits or failure-state resets. Run serially; no deliberate concurrent tests or CPU work.',
        'model_execution': 'Coordinator dispatches fresh context A/B sessions using dispatch.json, then records actual provider receipts. Harness never fabricates model calls. Prompt isolation is procedural, not filesystem enforcement.',
        'usage_fields': 'Input/cached/output tokens and total billed cost are nullable. Supplied values require a source; proxies never become credit savings.',
        'frozen_sha256': freeze()})
    save_state(folder, {'status': 'initialized', 'protocol_sha256': digest(folder / 'protocol.json'),
                        'qualification': [], 'next_slot': 1, 'active_slot': None, 'runs': [], 'actual_model_dispatches': 0})
    return {'study': str(folder), 'status': 'initialized'}

def qualification_ok(case, measurement, result, oracle):
    if not isinstance(result, dict) or not isinstance(result.get('samples'), dict):
        return False
    if any(not isinstance(s, dict) for s in result['samples'].values()):
        return False
    if case == 'original_samples':
        return (measurement['exit_code'] == 1 and result.get('completed') is True
                and result.get('samples') == oracle and result.get('passed') is False)
    return (measurement['exit_code'] == 2 and result.get('completed') is False
            and result.get('passed') is False and isinstance(result.get('error'), str) and bool(result['error'])
            and not any(s.get('passed') is True for s in result.get('samples', {}).values()))

def qualify(folder):
    folder, protocol, state = load_study(folder)
    check(state['status'] == 'initialized', 'Qualification is single-use; create a fresh study')
    state['status'] = 'qualifying'; save_state(folder, state)
    oracle = read(REFERENCE / 'independent.json')['samples']
    for case in CASES:
        case_dir = folder / 'qualification' / case
        case_dir.mkdir(parents=True)
        packet = case_dir / 'packet'
        setup = fresh_copy(packet)
        env = {}
        if case == 'missing_image': (packet / 'sample_b/head_id.png').unlink()
        if case == 'scope_mismatch':
            spec = read(packet / 'packet.json'); spec['allowed_vertices'].append(25); write(packet / 'packet.json', spec)
        if case == 'worker_nonzero': env['GAUNTLET_BLENDER'] = sys.executable
        command = [sys.executable, '-m', 'art_gauntlet.minimum_audit', packet / 'packet.json', case_dir / 'audit']
        if case in ('incomplete_observations', 'late_malformed_sample'):
            command = [sys.executable, Path(__file__), '_fault', packet / 'packet.json', case_dir / 'audit', case]
        measured = run_process(command, case_dir / 'process', env)
        result_path = case_dir / 'audit/audit.json'
        result = read(result_path) if result_path.exists() else {}
        passed = qualification_ok(case, measured, result, oracle) and unchanged(protocol['frozen_sha256'])
        record = {'case': case, 'qualified': passed, 'copy_setup_seconds': setup,
                  'measurement': measured, 'audit': result}
        write(case_dir / 'result.json', record)
        state['qualification'].append(record)
        if not passed:
            state.update(status='qualification_failed', stopped_utc=utc(), stop_reason=f'Qualification failed: {case}')
            save_state(folder, state)
            return summary(folder)
        save_state(folder, state)
    state['status'] = 'qualified'; save_state(folder, state)
    return summary(folder)

def fault(packet, output, mode):
    sys.path.insert(0, str(ROOT))
    from art_gauntlet.minimum_audit import audit
    def worker(*args, **kwargs):
        if mode == 'incomplete_observations':
            observations = {k: {'passed': True} for k in read(packet)['samples']}
        else:
            observations = {k: v['observed'] for k, v in read(REFERENCE / 'independent.json')['samples'].items()}
            observations['sample_c'] = {}
        write(Path(output) / 'observed.json', observations)
    with patch('art_gauntlet.minimum_audit.subprocess.run', side_effect=worker):
        result = audit(packet, output)
    return 2 if not result['completed'] else 0 if result['passed'] else 1

def prepare(folder):
    folder, protocol, state = load_study(folder)
    check(state['status'] == 'qualified', 'Comparison preparation requires passed qualification')
    began = time.perf_counter()
    # Names are blinded; mapping remains outside each participant's packet.
    private = {}
    for row in protocol['schedule']:
        target = folder / 'runs' / str(row['slot']) / 'packet'
        fresh_copy(target)
        spec = read(target / 'packet.json')
        mapping = {f'item_{i+1}': name for i, name in enumerate(sorted(spec['samples'], key=lambda n: hashlib.sha256(f"{row['batch']}:{n}".encode()).hexdigest()))}
        spec['samples'] = {anon: spec['samples'][old] for anon, old in mapping.items()}
        # Rename physical folders too, so historical sample labels aren't visible.
        for anon, old in mapping.items():
            old_folder = spec['samples'][anon]['folder']; (target / old_folder).rename(target / anon)
            spec['samples'][anon]['folder'] = anon
        write(target / 'packet.json', spec)
        private[str(row['slot'])] = {'mapping': mapping, 'inputs': manifest(inputs(target))}
    write(folder / 'private_mapping.json', private)
    state.update(status='ready', comparison_setup_seconds=time.perf_counter()-began,
                 private_mapping_sha256=digest(folder / 'private_mapping.json'))
    save_state(folder, state)
    return summary(folder)

def start(folder):
    folder, protocol, state = load_study(folder)
    check(state['status'] == 'ready' and state['active_slot'] is None, 'No eligible serial comparison slot')
    check(digest(folder / 'private_mapping.json') == state['private_mapping_sha256'], 'Mapping changed')
    row = protocol['schedule'][state['next_slot']-1]
    run_dir = folder / 'runs' / str(row['slot'])
    binding = read(folder / 'private_mapping.json')[str(row['slot'])]
    check(unchanged(binding['inputs']), 'Packet changed before dispatch')
    started = {'started_utc': utc(), 'started_monotonic': time.monotonic(), **row}
    write(run_dir / 'start.json', started)
    state.update(status='running', active_slot=row['slot']); save_state(folder, state)
    command = [sys.executable, str(Path(__file__)), 'legacy', str(run_dir / 'packet')]
    dispatch = {'slot': row['slot'], 'arm': row['arm'], 'model': protocol['arms'][row['arm']]['model'],
                'packet': str(run_dir / 'packet/packet.json'), 'command': command,
                'prompt': 'Mechanically audit this packet using the supplied legacy command. Check every sample and report its gate, actual vertex changes, acceptance and reasons. Read only this assigned packet and its scripts; do not inspect other study folders or prior reports. Do not render, edit source/scenes, repair, retry, or score art. Preserve every output and report execution failures. Expected classifications are intentionally withheld.',
                'receipt_template': {'model': protocol['arms'][row['arm']]['model'], 'model_dispatches': None,
                                     'coordinator_interventions': None, 'input_tokens': None, 'cached_input_tokens': None,
                                     'output_tokens': None, 'total_billed_cost': None, 'currency': None,
                                     'usage_source': None, 'total_cost_includes_coordinator': None, 'notes': ''}}
    write(run_dir / 'dispatch.json', dispatch)
    if row['arm'] == 'C':
        measured = run_process([sys.executable, '-m', 'art_gauntlet.minimum_audit', run_dir / 'packet/packet.json', run_dir / 'audit'], run_dir / 'process')
        receipt = dict(dispatch['receipt_template'], model_dispatches=0, coordinator_interventions=0)
        write(run_dir / 'script_receipt.json', receipt)
        return finish(folder, run_dir / 'script_receipt.json')
    return dispatch

def legacy(packet):
    packet = Path(packet).resolve()
    folder, protocol, state = load_study(packet.parents[2])
    check(state['status'] == 'running' and state['active_slot'] is not None, 'Legacy execution requires an active qualified slot')
    row = protocol['schedule'][state['active_slot']-1]
    check(row['arm'] in ('A', 'B') and packet == folder / 'runs' / str(row['slot']) / 'packet', 'Wrong packet/arm for active slot')
    return run_process([sys.executable, packet / 'luna_audit.py'], packet.parent / 'process')

def validate_receipt(receipt, expected_model, arm):
    check(receipt.get('model') == expected_model, 'Receipt model differs from frozen arm')
    for key in ('model_dispatches', 'coordinator_interventions'):
        check(type(receipt.get(key)) is int and receipt[key] >= 0, f'Missing/noninteger {key}')
    check(receipt['model_dispatches'] == (0 if arm == 'C' else 1), 'Exactly one model dispatch per A/B run; none for C')
    for key in ('input_tokens', 'cached_input_tokens', 'output_tokens'):
        value = receipt.get(key)
        check(value is None or type(value) is int and value >= 0, f'Invalid {key}')
    if receipt.get('cached_input_tokens') is not None and receipt.get('input_tokens') is not None:
        check(receipt['cached_input_tokens'] <= receipt['input_tokens'], 'Cached tokens exceed total input tokens')
    if any(receipt.get(k) is not None for k in ('input_tokens', 'cached_input_tokens', 'output_tokens', 'total_billed_cost')):
        check(bool(receipt.get('usage_source')), 'Measured usage requires a source')
    cost = receipt.get('total_billed_cost')
    if cost is not None:
        check(type(cost) in (int, float) and math.isfinite(cost) and cost >= 0, 'Invalid billed cost')
        check(bool(receipt.get('currency')) and receipt.get('total_cost_includes_coordinator') is True, 'Cost must cover coordinator plus arm and name currency')

def finish(folder, receipt_path):
    folder, protocol, state = load_study(folder)
    check(state['status'] == 'running' and state['active_slot'] is not None, 'No active run')
    slot = state['active_slot']; row = protocol['schedule'][slot-1]
    receipt = read(receipt_path); validate_receipt(receipt, protocol['arms'][row['arm']]['model'], row['arm'])
    check(digest(folder / 'private_mapping.json') == state['private_mapping_sha256'], 'Mapping changed')
    run_dir = folder / 'runs' / str(slot)
    binding = read(folder / 'private_mapping.json')[str(slot)]
    expected = {anon: read(REFERENCE / 'independent.json')['samples'][old] for anon, old in binding['mapping'].items()}
    result_path = run_dir / ('audit/audit.json' if row['arm'] == 'C' else 'packet/luna_audit.json')
    result = read(result_path) if result_path.exists() else {}
    measurement_path = run_dir / 'process/measurement.json'
    measurement = read(measurement_path) if measurement_path.exists() else {}
    correct = (result.get('samples') == expected and measurement.get('exit_code') == (1 if row['arm'] == 'C' else 0)
               and (row['arm'] != 'C' or result.get('completed') is True) and unchanged(binding['inputs']))
    record = {**row, 'correct': correct, 'receipt': receipt, 'measurement': measurement,
              'task_wall_seconds': time.monotonic() - read(run_dir / 'start.json')['started_monotonic'],
              'finished_utc': utc(), 'input_hashes_unchanged': unchanged(binding['inputs']), 'audit': result}
    write(run_dir / 'result.json', record)
    state['runs'].append(record); state['actual_model_dispatches'] += receipt['model_dispatches']
    state.update(active_slot=None, next_slot=slot+1,
                 status='comparison_failed' if not correct else 'complete' if slot == 9 else 'ready')
    save_state(folder, state)
    return summary(folder)

def summary(folder):
    folder, protocol, state = load_study(folder)
    result = {'status': state['status'], 'qualification_cases_executed': len(state['qualification']),
              'qualification_cases_skipped': CASES[len(state['qualification']):],
              'comparison_runs': len(state['runs']), 'actual_model_dispatches': state['actual_model_dispatches'],
              'recommendation': 'withhold adoption', 'credit_savings': None,
              'break_even_audits': None, 'reason': state.get('stop_reason', 'Experiment not yet complete'),
              'tokens_and_cost': 'Unavailable unless sourced in actual run receipts; null is not zero.'}
    if state['status'] == 'complete':
        import statistics
        metrics = {arm: {'median_task_seconds': statistics.median(r['task_wall_seconds'] for r in state['runs'] if r['arm'] == arm),
                         'interventions': sum(r['receipt']['coordinator_interventions'] for r in state['runs'] if r['arm'] == arm)} for arm in 'ABC'}
        lower_effort = all(metrics['C']['interventions'] <= metrics[a]['interventions'] for a in 'AB')
        faster = all(metrics['C']['median_task_seconds'] < metrics[a]['median_task_seconds'] for a in 'AB')
        receipts = [r['receipt'] for r in state['runs']]
        comparable_cost = all(r.get('total_billed_cost') is not None for r in receipts) and len({r.get('currency') for r in receipts}) == 1
        cheaper = False
        if comparable_cost:
            costs = {a: sum(r['receipt']['total_billed_cost'] for r in state['runs'] if r['arm'] == a) for a in 'ABC'}
            cheaper = all(costs['C'] < costs[a] for a in 'AB')
            result['billed_cost_by_arm'] = costs
        result.update(metrics=metrics, recommendation='adopt with capture-binding limitation' if lower_effort and (faster or cheaper) else 'withhold adoption',
                      reason='Three descriptive batches only; monetary savings unavailable without complete comparable receipts. Setup amortization remains unavailable without sourced setup cost.')
    write(folder / 'summary.json', result)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('init'); p.add_argument('study'); p.add_argument('--strong-model', required=True); p.add_argument('--cheap-model', required=True)
    for name in ('qualify', 'prepare', 'start', 'summary'):
        p = sub.add_parser(name); p.add_argument('study')
    p = sub.add_parser('finish'); p.add_argument('study'); p.add_argument('receipt')
    p = sub.add_parser('legacy'); p.add_argument('packet')
    p = sub.add_parser('_fault'); p.add_argument('packet'); p.add_argument('output'); p.add_argument('mode')
    args = parser.parse_args()
    if args.command == '_fault': return fault(args.packet, args.output, args.mode)
    try:
        if args.command == 'init': result = initialize(args.study, args.strong_model, args.cheap_model)
        elif args.command == 'legacy': result = legacy(args.packet)
        elif args.command == 'finish': result = finish(args.study, args.receipt)
        else: result = globals()[args.command](args.study)
        print(json.dumps(result, indent=2))
        return 1 if result.get('status') in ('qualification_failed', 'comparison_failed') else 0
    except (ValueError, OSError, KeyError) as exc:
        print(json.dumps({'error': f'{type(exc).__name__}: {exc}'})); return 2

if __name__ == '__main__': raise SystemExit(main())
