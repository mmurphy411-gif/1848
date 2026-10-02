import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from art_gauntlet import minimum_gate as gate


class MinimumGateTests(unittest.TestCase):
    def test_two_failures_persist_and_block_worker_before_third_attempt(self):
        with tempfile.TemporaryDirectory() as folder:
            run=Path(folder)
            def capture(config,source,out,operations,render):Path(out).mkdir()
            with patch.object(gate,'capture',side_effect=capture) as worker, patch.object(gate,'compare',return_value={'passed':False}):
                gate.attempt({},run,'first',[])
                gate.attempt({},run,'second',[])
                with self.assertRaisesRegex(ValueError,'two consecutive'):
                    gate.attempt({},run,'third',[])
                self.assertEqual(worker.call_count,2)
                self.assertFalse((run/'third').exists())
                self.assertTrue(gate.read(run/'loop_state.json')['stopped'])

    def test_success_breaks_consecutive_failure_streak(self):
        state={'consecutive_failures':0,'dispatched':0,'stopped':False}
        for passed in [False,True,False]:
            gate.reserve(state);gate.record(state,passed)
        gate.reserve(state)
        self.assertEqual(state['consecutive_failures'],1)
        self.assertEqual(state['dispatched'],4)

    def test_worker_failure_counts_toward_stop(self):
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(gate,'capture',side_effect=RuntimeError('worker failure')):
                for name in ['first','second']:
                    with self.assertRaises(RuntimeError):gate.attempt({},folder,name,[])
                with self.assertRaisesRegex(ValueError,'two consecutive'):gate.attempt({},folder,'third',[])

    def test_edit_requires_successful_validation(self):
        with tempfile.TemporaryDirectory() as folder:
            gate.write(Path(folder)/'validation.json',{'passed':False})
            gate.write(Path(folder)/'config.json',{})
            with patch.object(gate,'capture') as worker:
                with self.assertRaisesRegex(ValueError,'Step 3'):gate.edit(folder)
                worker.assert_not_called()


if __name__=='__main__':unittest.main()
