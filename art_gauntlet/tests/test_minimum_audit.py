import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image
from art_gauntlet.minimum_audit import audit
from art_gauntlet.minimum_audit_worker import verify_coordinates


class CoordinateAuditTests(unittest.TestCase):
    def test_declared_edit_and_protected_violation(self):
        baseline = {0: [0, 0, 0], 1: [1, 1, 1]}
        self.assertTrue(verify_coordinates(baseline, {0: [0, 0, 0], 1: [1, 1, 1.06]}, [1], [0, 0, .06])['passed'])
        self.assertFalse(verify_coordinates(baseline, {0: [.1, 0, 0], 1: [1, 1, 1.06]}, [1], [0, 0, .06])['passed'])

    def test_noop_wrong_delta_and_missing_edit_rejected(self):
        baseline = {0: [0, 0, 0], 1: [1, 1, 1]}
        for sample, allowed in [(baseline, [1]), ({0: [0, 0, 0], 1: [1, 1, 1.1]}, [1]),
                                ({0: [0, 0, 0], 1: [1, 1, 1.06]}, [0, 1])]:
            with self.subTest(sample=sample, allowed=allowed):
                self.assertFalse(verify_coordinates(baseline, sample, allowed, [0, 0, .06])['passed'])

    def test_topology_and_nonfinite_coordinates_fail_closed(self):
        for sample in [{}, {0: [float('nan'), 0, 0]}]:
            with self.assertRaises(ValueError):
                verify_coordinates({0: [0, 0, 0]}, sample, [0], [0, 0, .06])


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.packet = {'mesh': 'Horse', 'allowed_vertices': [1], 'config': 'config.json',
                       'baseline': 'baseline', 'samples': {'sample': {'folder': 'sample', 'declared_delta': [0, 0, .06]}}}
        self.write('config.json', {'mesh': 'Horse', 'editable_vertices': [1], 'views': {'head': {}}, 'pixel_max_delta': 0})
        self.write('packet.json', self.packet)
        for name in ['baseline', 'sample']:
            (self.root / name).mkdir()
            (self.root / name / 'candidate.blend').write_bytes(b'fake scene for subprocess mock')
            self.write(f'{name}/snapshot.json', {key: {} for key in ['geometry', 'materials', 'transforms', 'rig']})
            for kind in ['id', 'matte']:
                Image.new('RGBA', (2, 2), 'white').save(self.root / name / f'head_{kind}.png')

    def write(self, path, data):
        (self.root / path).write_text(json.dumps(data), encoding='utf-8')

    def run_audit(self, effect):
        with patch('art_gauntlet.minimum_audit.subprocess.run', side_effect=effect) as worker, \
             patch('art_gauntlet.minimum_audit.executable', return_value='blender'):
            result = audit(self.root / 'packet.json', self.root / 'out')
        return result, worker

    def good_worker(self, *args, **kwargs):
        self.write('out/observed.json', {'sample': self.good_observation()})

    def good_observation(self):
        return {'changed': [{'id': 1, 'delta': [0, 0, .06]}], 'allowed_ids': [1],
                'declared_delta': [0, 0, .06], 'agreement': True, 'passed': True}

    def test_missing_observations_cannot_accept(self):
        result, _ = self.run_audit(lambda *a, **k: self.write('out/observed.json', {'sample': {'passed': True}}))
        self.assertFalse(result['completed'])
        self.assertFalse(result['passed'])
        self.assertEqual(result['samples'], {})
        self.assertIn('Incomplete worker observation', result['error'])

    def test_late_malformed_sample_cannot_expose_earlier_success(self):
        self.packet['samples']['last'] = self.packet['samples']['sample'].copy()
        self.write('packet.json', self.packet)
        result, _ = self.run_audit(lambda *a, **k: self.write('out/observed.json',
                                  {'sample': self.good_observation(), 'last': {}}))
        self.assertFalse(result['completed'])
        self.assertEqual(result['samples'], {})

    def test_contradictory_worker_verdict_cannot_accept(self):
        observation = self.good_observation()
        observation['changed'][0]['delta'] = [0, 0, .3]
        result, _ = self.run_audit(lambda *a, **k: self.write('out/observed.json', {'sample': observation}))
        self.assertFalse(result['completed'])
        self.assertEqual(result['samples'], {})
        self.assertIn('contradicts', result['error'])

    def test_nonfinite_or_misbound_observation_rejected(self):
        from art_gauntlet.minimum_audit import validate_observation
        for field, value in [('declared_delta', [0, 0, .1]), ('allowed_ids', [2]),
                             ('changed', [{'id': 1, 'delta': [float('nan'), 0, 0]}])]:
            observation = self.good_observation(); observation[field] = value
            with self.assertRaises(ValueError): validate_observation(observation, [1], [0, 0, .06])

    def test_success_single_dispatch_and_fresh_output(self):
        result, worker = self.run_audit(self.good_worker)
        self.assertTrue(result['completed'])
        self.assertTrue(result['passed'])
        self.assertEqual(worker.call_count, 1)
        self.assertIn('--python-exit-code', worker.call_args.args[0])
        with self.assertRaises(FileExistsError):
            audit(self.root / 'packet.json', self.root / 'out')

    def test_gate_rejection_is_completed_not_accepted(self):
        Image.new('RGBA', (2, 2), 'black').save(self.root / 'sample/head_id.png')
        result, _ = self.run_audit(self.good_worker)
        self.assertTrue(result['completed'])
        self.assertFalse(result['passed'])
        self.assertEqual(result['samples']['sample']['reasons'], ['gate comparison failed'])

    def test_missing_evidence_prevents_dispatch(self):
        (self.root / 'sample/head_id.png').unlink()
        result, worker = self.run_audit(self.good_worker)
        self.assertFalse(result['completed'])
        self.assertFalse(result['passed'])
        worker.assert_not_called()

    def test_scope_mismatch_prevents_dispatch(self):
        self.packet['allowed_vertices'] = [0, 1]
        self.write('packet.json', self.packet)
        result, worker = self.run_audit(self.good_worker)
        self.assertFalse(result['completed'])
        worker.assert_not_called()

    def test_worker_failure_cannot_accept(self):
        result, _ = self.run_audit(subprocess.CalledProcessError(1, ['blender']))
        self.assertFalse(result['completed'])
        self.assertFalse(result['passed'])

    def test_partial_output_cannot_accept(self):
        result, _ = self.run_audit(lambda *a, **k: self.write('out/observed.json', {}))
        self.assertFalse(result['completed'])
        self.assertFalse(result['passed'])

    def test_input_changed_during_worker_cannot_accept(self):
        def worker(*args, **kwargs):
            self.good_worker()
            (self.root / 'sample/candidate.blend').write_bytes(b'changed')
        result, _ = self.run_audit(worker)
        self.assertFalse(result['completed'])
        self.assertFalse(result['passed'])


if __name__ == '__main__':
    unittest.main()
