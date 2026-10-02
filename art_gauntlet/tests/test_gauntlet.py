import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image, ImageDraw
from art_gauntlet import metric, review, runner
from art_gauntlet.storage import ROOT, contained, digest, fingerprint, read, write


def review_fixture():
    packet = {"packet_id": "opaque", "evidence": {"board.png": "hash"}, "views": ["front", "side"], "subjects": ["A"]}
    result = {"packet_id": "opaque", "evidence_hash": fingerprint(packet["evidence"]), "reviewer_id": "fresh-reviewer-1",
              "inspected": ["board.png"], "additional_evidence": [], "recommendation": "Inspect the eye", "subjects": {
                  "A": {"scores": {d: {v: 8 for v in packet["views"]} for d in review.DIMENSIONS},
                        "confidence": "high", "acceptable_progress": True, "discrepancies": []}}}
    return packet, result


class MetricTests(unittest.TestCase):
    def setUp(self):
        self.reference = Image.new("L", (100,100))
        draw = ImageDraw.Draw(self.reference)
        draw.rectangle((30,10,70,65), fill=255)
        draw.rectangle((30,65,40,90), fill=255)
        draw.rectangle((60,65,70,90), fill=255)

    def test_equal_shape_has_perfect_score(self):
        result = metric.compare(self.reference, self.reference)
        self.assertEqual(result["iou"], 1)
        self.assertEqual(result["outline_distance_height"], 0)

    def test_uniform_translation_and_scale_are_invariant(self):
        other = Image.new("L", (260,260))
        other.paste(self.reference.resize((200,200), Image.Resampling.NEAREST), (50,20))
        self.assertGreater(metric.compare(self.reference, other)["iou"], .97)

    def test_anisotropic_proportion_change_is_penalized(self):
        other = self.reference.resize((150,100), Image.Resampling.NEAREST)
        self.assertLess(metric.compare(self.reference, other)["iou"], .8)

    def test_empty_mask_cannot_pass(self):
        with self.assertRaises(ValueError):
            metric.compare(self.reference, Image.new("L", (100,100)))

    def test_only_calibrated_high_confidence_regression_is_rejected(self):
        old, new = {"side": {"iou": .8}}, {"side": {"iou": .6}}
        self.assertEqual(metric.disposition(new, old, {"side": {"calibrated": False, "confidence": "high"}}), "review_tradeoff")
        self.assertEqual(metric.disposition(new, old, {"side": {"calibrated": True, "confidence": "high"}}), "metric_rejected")
        self.assertEqual(metric.disposition(new, old, {"side": {"calibrated": True, "confidence": "high"}}, blind_to_metric=True), "review")

    def test_enclosed_white_marking_stays_foreground(self):
        im = Image.new("RGB", (20,20), "white")
        draw = ImageDraw.Draw(im)
        draw.rectangle((3,3,16,16), fill="black")
        draw.rectangle((7,7,12,12), fill="white")
        mask = metric.reference_mask(im)
        self.assertEqual(mask.getpixel((0,0)), 0)
        self.assertEqual(mask.getpixel((9,9)), 255)


class ReviewTests(unittest.TestCase):
    def test_major_discrepancy_caps_whole_dimension(self):
        packet, result = review_fixture()
        result["subjects"]["A"]["discrepancies"] = [{"dimension": "proportions", "view": "side", "region": "head", "description": "Head is too small", "severity": "major", "critical": False}]
        checked = review.validate_review(result, packet)
        self.assertEqual(set(checked["subjects"]["A"]["scores"]["proportions"].values()), {6})
        self.assertFalse(review.visual_gate(checked["subjects"]["A"], ["proportions"]))

    def test_stale_hash_rejected(self):
        packet, result = review_fixture()
        result["evidence_hash"] = "old"
        with self.assertRaises(ValueError): review.validate_review(result, packet)

    def test_missing_view_rejected(self):
        packet, result = review_fixture()
        del result["subjects"]["A"]["scores"]["silhouette"]["front"]
        with self.assertRaises(ValueError): review.validate_review(result, packet)

    def test_unseen_detail_rejected(self):
        packet, result = review_fixture()
        packet["evidence"]["eye.png"] = "hash2"
        result["evidence_hash"] = fingerprint(packet["evidence"])
        with self.assertRaises(ValueError): review.validate_review(result, packet)

    def test_nan_score_rejected(self):
        packet, result = review_fixture()
        result["subjects"]["A"]["scores"]["silhouette"]["front"] = float("nan")
        with self.assertRaises(ValueError): review.validate_review(result, packet)

    def test_critical_feature_vetoes_otherwise_high_scores(self):
        packet, result = review_fixture()
        subject = result["subjects"]["A"]
        subject["discrepancies"] = [{"dimension": "detail_integration", "view": "side", "region": "eye", "description": "Missing pupil", "severity": "major", "critical": True}]
        self.assertFalse(review.visual_gate(subject, ["silhouette", "proportions"]))


class RunnerTests(unittest.TestCase):
    def setUp(self):
        import time
        parent = ROOT / "artifacts" / "gauntlet" / "tests"
        parent.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=parent)
        self.run = Path(self.temp.name)
        self.manifest = {"budget": {"max_candidates": 3, "max_minutes": 10, "max_model_calls": 4, "max_review_images": 8}, "references": {"side": {"calibrated": False}}}
        write(self.run / "manifest.json", self.manifest)
        (self.run / "baseline.blend").write_bytes(b"immutable source fixture")
        self.state = {"asset_id": "fixture", "started": time.time(), "candidates": [], "originals": {}, "reference_hashes": {},
                      "manifest_hash": digest(self.run / "manifest.json"), "cost": {"planner_calls": 0, "reviewer_calls": 0, "review_images": 0, "review_pixels": 0},
                      "best_candidate": None, "latest_attempt": None, "status": "awaiting_edit", "phase": "form", "packet_ids": []}
        write(self.run / "run.json", self.state)

    def tearDown(self): self.temp.cleanup()

    def test_failed_build_never_promotes_or_changes_source(self):
        before = digest(self.run / "baseline.blend")
        with patch.object(runner, "worker", side_effect=RuntimeError("injected worker crash")):
            with self.assertRaises(RuntimeError):
                runner.iterate(self.run, {"hypothesis": "failure fixture", "operations": []})
        state = read(self.run / "run.json")
        self.assertIsNone(state["best_candidate"])
        self.assertEqual(state["status"], "failed")
        self.assertEqual(digest(self.run / "baseline.blend"), before)
        self.assertEqual(state["cost"]["planner_calls"], 1)

    def test_budget_blocks_before_candidate_or_call_is_created(self):
        self.state["cost"]["planner_calls"] = 4
        write(self.run / "run.json", self.state)
        with self.assertRaises(ValueError):
            runner.iterate(self.run, {"hypothesis": "over budget", "operations": []})
        self.assertEqual(read(self.run / "run.json")["candidates"], [])

    def test_changed_protocol_requires_new_run(self):
        write(self.run / "manifest.json", {**self.manifest, "changed": True})
        with self.assertRaises(ValueError): runner.verify_inputs(self.run, self.state)

    def test_missing_review_cannot_package(self):
        with self.assertRaises(ValueError): runner.package(self.run)

    def test_path_traversal_rejected(self):
        with self.assertRaises(ValueError): contained(self.run, "../../../../outside")

    def test_status_does_not_execute_or_spawn(self):
        self.assertEqual(runner.status(self.run)["status"], "awaiting_edit")

    def install_candidate_and_packet(self, cid="candidate", parent=None, pid="packet"):
        folder = self.run / "candidates" / cid
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "candidate.blend").write_bytes(cid.encode())
        write(folder / "candidate.json", {"id": cid, "parent": parent, "state": "awaiting_review", "reviews": [], "scene_hash": digest(folder / "candidate.blend")})
        write(folder / "metric.json", {"side": {"iou": .9}})
        public = self.run / "packets" / pid
        public.mkdir(parents=True)
        (public / "board.png").write_bytes(b"fixture image, not used by visual scoring tests")
        packet, response = review_fixture()
        packet.update(packet_id=pid, evidence={"board.png": digest(public / "board.png")})
        response.update(packet_id=pid, evidence_hash=fingerprint(packet["evidence"]))
        write(public / "packet.json", packet)
        write(public / "response.json", response)
        write(self.run / "packet_maps" / f"{pid}.json", {"candidate": cid, "mapping": {"A": cid}, "kind": "source", "candidate_hash": digest(folder / "candidate.blend")})
        state = read(self.run / "run.json")
        if cid not in state["candidates"]:
            state["candidates"].append(cid)
        state["latest_attempt"] = cid
        state["packet_ids"].append(pid)
        write(self.run / "run.json", state)
        return public / "response.json"

    def test_valid_review_retains_but_uncalibrated_metric_blocks_gate(self):
        response = self.install_candidate_and_packet()
        result = runner.ingest(self.run, response)
        self.assertEqual(result["best_candidate"], "candidate")
        self.assertEqual(result["phase"], "form")
        self.assertFalse(read(self.run / "candidates/candidate/candidate.json")["form_pass"])

    def test_rejected_candidate_keeps_previous_best(self):
        first = self.install_candidate_and_packet()
        runner.ingest(self.run, first)
        response = self.install_candidate_and_packet("inferior", "candidate", "packet2")
        data = read(response)
        data["subjects"]["A"]["acceptable_progress"] = False
        write(response, data)
        result = runner.ingest(self.run, response)
        self.assertEqual(result["best_candidate"], "candidate")

    def test_changed_candidate_after_packet_cannot_promote(self):
        response = self.install_candidate_and_packet()
        (self.run / "candidates/candidate/candidate.blend").write_bytes(b"changed")
        with self.assertRaises(ValueError): runner.ingest(self.run, response)
        self.assertIsNone(read(self.run / "run.json")["best_candidate"])

    def test_fresh_comparison_accepts_candidate_built_from_older_parent(self):
        runner.ingest(self.run, self.install_candidate_and_packet())
        response = self.install_candidate_and_packet("new", "older", "fresh")
        public = response.parent
        packet, data = read(public / "packet.json"), read(response)
        packet["subjects"].append("B")
        data["subjects"]["B"] = data["subjects"]["A"]
        write(public / "packet.json", packet)
        write(response, data)
        mapping_path = self.run / "packet_maps/fresh.json"
        mapping = read(mapping_path)
        mapping["mapping"]["B"] = "candidate"
        write(mapping_path, mapping)
        self.assertEqual(runner.ingest(self.run, response)["best_candidate"], "new")

    def test_unseen_new_best_still_rejects_stale_comparison(self):
        response = self.install_candidate_and_packet()
        state = read(self.run / "run.json")
        state["best_candidate"] = "unseen"
        write(self.run / "run.json", state)
        with self.assertRaisesRegex(ValueError, "Best changed"):
            runner.ingest(self.run, response)

    def test_duplicate_review_cannot_count_as_confirmation(self):
        response = self.install_candidate_and_packet()
        runner.ingest(self.run, response)
        with self.assertRaises(ValueError): runner.ingest(self.run, response)

    def test_new_candidate_starts_from_best_not_failed_latest(self):
        first = self.install_candidate_and_packet()
        runner.ingest(self.run, first)
        with patch.object(runner, "worker", side_effect=RuntimeError("failure")):
            with self.assertRaises(RuntimeError): runner.iterate(self.run, {"hypothesis": "test parent", "operations": []})
        state = read(self.run / "run.json")
        record = read(self.run / "candidates" / state["latest_attempt"] / "candidate.json")
        self.assertEqual(record["parent"], "candidate")

    def confirmation(self, pid="confirmation"):
        previous = read(self.run / "candidates/candidate/candidate.json")
        response = self.install_candidate_and_packet(pid=pid)
        write(self.run / "candidates/candidate/candidate.json", previous)
        data = read(response)
        data["reviewer_id"] = "fresh-reviewer-"+pid
        write(response, data)
        return response

    def calibrate_fixture(self):
        manifest = read(self.run / "manifest.json")
        manifest["references"]["side"].update(calibrated=True, form_floor=.8)
        write(self.run / "manifest.json", manifest)
        state = read(self.run / "run.json")
        state["manifest_hash"] = digest(self.run / "manifest.json")
        write(self.run / "run.json", state)

    def test_two_fresh_reviews_required_for_calibrated_form_gate(self):
        self.calibrate_fixture()
        response = self.install_candidate_and_packet()
        self.assertEqual(runner.ingest(self.run, response)["phase"], "form")
        self.assertEqual(runner.ingest(self.run, self.confirmation())["phase"], "polish")

    def test_confirmation_rejection_revokes_candidate_and_gate(self):
        self.calibrate_fixture()
        runner.ingest(self.run, self.install_candidate_and_packet())
        response = self.confirmation()
        data = read(response)
        data["subjects"]["A"]["acceptable_progress"] = False
        write(response, data)
        state = runner.ingest(self.run, response)
        self.assertIsNone(state["best_candidate"])
        self.assertEqual(state["phase"], "form")
        self.assertFalse(read(self.run / "candidates/candidate/candidate.json")["form_pass"])

    def test_review_disagreement_cannot_be_averaged_into_pass(self):
        self.calibrate_fixture()
        runner.ingest(self.run, self.install_candidate_and_packet())
        response = self.confirmation()
        data = read(response)
        data["subjects"]["A"]["scores"]["proportions"]["side"] = 6
        write(response, data)
        self.assertEqual(runner.ingest(self.run, response)["phase"], "form")
        self.assertEqual(runner.ingest(self.run, self.confirmation("third"))["phase"], "form")

    def test_more_evidence_request_does_not_pass_gate(self):
        self.calibrate_fixture()
        runner.ingest(self.run, self.install_candidate_and_packet())
        response = self.confirmation()
        data = read(response)
        data["additional_evidence"] = ["Closer side view of eye"]
        write(response, data)
        self.assertEqual(runner.ingest(self.run, response)["status"], "awaiting_evidence")

    def export_confirmation(self, pid, engine_pass=True):
        response = self.confirmation(pid)
        folder = self.run / "candidates/candidate"
        (folder / "export").mkdir(exist_ok=True)
        (folder / "export/asset.glb").write_bytes(b"synthetic export fixture")
        glb_hash = digest(folder / "export/asset.glb")
        write(folder / "export/comparison.json", {"passed": True, "source_hash": digest(folder / "candidate.blend"), "glb_hash": glb_hash})
        write(folder / "godot/audit.json", {"passed": engine_pass, "runtime_materials_verified": engine_pass, "glb_hash": glb_hash})
        mapping_path = self.run / "packet_maps" / f"{pid}.json"
        mapping = read(mapping_path)
        mapping.update(kind="export", export_hash=glb_hash)
        write(mapping_path, mapping)
        return response

    def test_engine_failure_blocks_otherwise_passing_export_review(self):
        self.calibrate_fixture()
        runner.ingest(self.run, self.install_candidate_and_packet())
        runner.ingest(self.run, self.confirmation())
        result = runner.ingest(self.run, self.export_confirmation("export1", engine_pass=False))
        self.assertEqual(result["status"], "export_reviewed_incomplete")
        with self.assertRaises(ValueError): runner.package(self.run)

    def test_complete_review_chain_packages_hash_indexed_delivery(self):
        import zipfile
        self.calibrate_fixture()
        runner.ingest(self.run, self.install_candidate_and_packet())
        runner.ingest(self.run, self.confirmation())
        self.assertEqual(runner.ingest(self.run, self.export_confirmation("export1"))["phase"], "polish")
        self.assertEqual(runner.ingest(self.run, self.export_confirmation("export2"))["phase"], "game_ready")
        with zipfile.ZipFile(runner.package(self.run)) as archive:
            self.assertIn("SHA256.json", archive.namelist())
            self.assertIsNone(archive.testzip())
        (self.run / "candidates/candidate/export/asset.glb").write_bytes(b"unreviewed replacement")
        with self.assertRaises(ValueError): runner.package(self.run)

    def test_changed_export_after_packet_is_not_ingested(self):
        runner.ingest(self.run, self.install_candidate_and_packet())
        response = self.export_confirmation("export1")
        (self.run / "candidates/candidate/export/asset.glb").write_bytes(b"changed")
        with self.assertRaises(ValueError): runner.ingest(self.run, response)

    def test_cache_reuses_exact_outputs_and_recovers_corrupt_view(self):
        from types import SimpleNamespace
        manifest = {**self.manifest, "protocol": {"views": {"side": {}}}}
        write(self.run / "manifest.json", manifest)
        state = read(self.run / "run.json")
        state["manifest_hash"] = digest(self.run / "manifest.json")
        write(self.run / "run.json", state)
        output = self.run / "cache-test"
        executable = self.run / "fake-blender.exe"
        executable.write_bytes(b"fixture executable")
        def execute(*args, **kwargs):
            write(output / "dependencies.json", {})
            write(output / "audit.json", {})
            write(output / "worker.json", {})
            (output / "candidate.blend").write_bytes(b"scene")
            (output / "renders").mkdir(exist_ok=True)
            for name in ("side.png", "side_mask.png"):
                Image.new("RGBA", (8,8), "white").save(output / "renders" / name)
            return SimpleNamespace(returncode=0)
        with patch.object(runner, "executable", return_value=str(executable)), patch.object(runner.subprocess, "run", side_effect=execute) as call:
            runner.worker(self.run, self.run / "baseline.blend", output, "build")
            runner.worker(self.run, self.run / "baseline.blend", output, "build")
            self.assertEqual(call.call_count, 1)
            (output / "renders/side.png").write_bytes(b"interrupted write")
            runner.worker(self.run, self.run / "baseline.blend", output, "build")
            self.assertEqual(call.call_count, 2)


if __name__ == "__main__":
    unittest.main()
