import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('experiment', Path(__file__).resolve().parents[1] / 'experiment.py')
e = importlib.util.module_from_spec(spec)
spec.loader.exec_module(e)


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.reference = self.folder / 'reference'; self.reference.mkdir()
        e.write(self.reference / 'independent.json', {'samples': {'sample': {'passed': True}}})
        self.patch = patch.object(e, 'REFERENCE', self.reference)
        self.patch.start(); self.addCleanup(self.patch.stop)

    def study(self, status='initialized'):
        protocol = {'frozen_sha256': {}, 'arms': {'A': {'model': 'strong'}, 'B': {'model': 'cheap'}, 'C': {'model': None}},
                    'schedule': [{'slot': i+1, 'batch': i//3+1, 'arm': arm} for i, arm in enumerate(e.ORDER)]}
        e.write(self.folder / 'protocol.json', protocol)
        state = {'protocol_sha256': e.digest(self.folder / 'protocol.json'), 'status': status,
                 'qualification': [], 'active_slot': None, 'next_slot': 1, 'actual_model_dispatches': 0, 'runs': []}
        e.write(self.folder / 'state.json', state)
        return state

    def receipt(self, **extra):
        return {'model': 'strong', 'model_dispatches': 1, 'coordinator_interventions': 0,
                'input_tokens': None, 'cached_input_tokens': None, 'output_tokens': None,
                'total_billed_cost': None, **extra}

    def test_failed_qualification_blocks_preparation_and_dispatch(self):
        for status in ('initialized', 'qualification_failed', 'qualifying'):
            self.study(status)
            for fn in (e.prepare, e.start):
                with self.assertRaises(ValueError): fn(self.folder)

    def test_first_failure_stops_without_later_cases_or_models(self):
        self.study()
        with patch.object(e, 'fresh_copy', return_value=0), patch.object(e, 'run_process', return_value={'exit_code': 0}) as process:
            result = e.qualify(self.folder)
        self.assertEqual(process.call_count, 1)
        self.assertEqual(result['status'], 'qualification_failed')
        self.assertEqual(result['actual_model_dispatches'], 0)
        self.assertEqual(len(result['qualification_cases_skipped']), 5)

    def test_incomplete_results_never_qualify(self):
        for result in [[], {'samples': []}, {'samples': {'sample': None}},
                       {'completed': False, 'passed': False, 'error': 'bad', 'samples': {'sample': {'passed': True}}},
                       {'completed': True, 'passed': False, 'samples': {'sample': {'passed': True}}}]:
            self.assertFalse(e.qualification_ok('incomplete_observations', {'exit_code': 2}, result, {}))

    def test_completed_negative_control_is_successful_execution(self):
        oracle = {'sample': {'passed': False, 'reasons': ['protected movement']}}
        report = {'completed': True, 'passed': False, 'samples': oracle}
        self.assertTrue(e.qualification_ok('original_samples', {'exit_code': 1}, report, oracle))
        self.assertFalse(e.qualification_ok('original_samples', {'exit_code': 2}, report, oracle))

    def test_nullable_usage_is_not_zero_or_free(self):
        receipt = self.receipt()
        e.validate_receipt(receipt, 'strong', 'A')
        self.assertIsNone(receipt['total_billed_cost'])
        self.study()
        self.assertIsNone(e.summary(self.folder)['credit_savings'])

    def test_receipt_requires_source_model_and_full_cost_scope(self):
        for receipt in [self.receipt(model='wrong'), self.receipt(model_dispatches=0),
                        self.receipt(input_tokens=10), self.receipt(coordinator_interventions=None),
                        self.receipt(total_billed_cost=1, usage_source='invoice', currency='USD'),
                        self.receipt(input_tokens=2, cached_input_tokens=3, usage_source='export')]:
            with self.assertRaises(ValueError): e.validate_receipt(receipt, 'strong', 'A')

    def test_protocol_and_frozen_file_changes_refuse_resume(self):
        self.study()
        protocol = e.read(self.folder / 'protocol.json'); protocol['changed'] = True
        e.write(self.folder / 'protocol.json', protocol)
        with self.assertRaises(ValueError): e.load_study(self.folder)
        self.study()
        asset = self.folder / 'frozen.txt'; asset.write_text('before')
        protocol = e.read(self.folder / 'protocol.json'); protocol['frozen_sha256'] = e.manifest([asset])
        e.write(self.folder / 'protocol.json', protocol)
        state = e.read(self.folder / 'state.json'); state['protocol_sha256'] = e.digest(self.folder / 'protocol.json')
        e.write(self.folder / 'state.json', state); asset.write_text('after')
        with self.assertRaises(ValueError): e.load_study(self.folder)

    def test_no_second_dispatch_while_running(self):
        state = self.study('running'); state['active_slot'] = 1; e.write(self.folder / 'state.json', state)
        with self.assertRaises(ValueError): e.start(self.folder)

    def test_bad_arm_result_stops_schedule_and_records_dispatch(self):
        state = self.study('running'); state['active_slot'] = 1
        e.write(self.folder / 'private_mapping.json', {'1': {'mapping': {'item_1': 'sample'}, 'inputs': {}}})
        state['private_mapping_sha256'] = e.digest(self.folder / 'private_mapping.json')
        e.write(self.folder / 'state.json', state)
        run_dir = self.folder / 'runs/1'; run_dir.mkdir(parents=True)
        e.write(run_dir / 'start.json', {'started_monotonic': e.time.monotonic()})
        receipt = self.folder / 'receipt.json'; e.write(receipt, self.receipt())
        result = e.finish(self.folder, receipt)
        self.assertEqual(result['status'], 'comparison_failed')
        self.assertEqual(result['actual_model_dispatches'], 1)
        with self.assertRaises(ValueError): e.start(self.folder)


if __name__ == '__main__': unittest.main()
