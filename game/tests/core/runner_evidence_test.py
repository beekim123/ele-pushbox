#!/usr/bin/env python3
"""Exercise the real runner in disposable repos with controlled CLI producers.

No Godot, SDK, repository build, or player's save is started. The child
executables model only the process/file boundary whose guard is under test.
Run serially: python3 game/tests/core/runner_evidence_test.py
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest


RUNNER = Path(__file__).resolve().parents[2] / "tools/run_tests.py"

PRODUCER = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

repo = Path.cwd()
results = repo / "game/tests/results"
reports = repo / "game/reports"
mode = os.environ["PORTITOR_FIXTURE_MODE"]
tool = Path(sys.argv[0]).name

if tool == "ps":
    report = json.loads((reports / "verification.json").read_text())
    assert report.get("run_incomplete") is True, "old aggregate survived until the first subprocess"
    assert report.get("levels") == [], "old level verification survived invalidation"
    assert report.get("samples") == [], "old sample verification survived invalidation"
    assert report.get("references") == [], "old references survived invalidation"
    (repo / "invalidation_observed.json").write_text(json.dumps(report))
    print("PID PPID %CPU COMM")
    ancestor = int(os.environ["PORTITOR_FIXTURE_ANCESTOR_PID"])
    print(str(os.getppid()) + " " + str(ancestor) + " 99.0 /Applications/Godot.app/Contents/MacOS/Godot")
    print(str(ancestor) + " 1 99.0 /usr/bin/python3")
    count_file = repo / "preflight-count.txt"
    count = int(count_file.read_text()) + 1 if count_file.exists() else 1
    count_file.write_text(str(count))
    if mode == "preflight_unknown":
        sys.exit(1)
    full = mode == "budget_full" or (mode == "budget_after_preparation" and count >= 2)
    if full or mode == "budget_single":
        print("700001 1 80.0 /Applications/Godot.app/Contents/MacOS/Godot")
        print("700003 1 90.0 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        print("700004 1 90.0 /Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node")
    if full:
        print("700002 1 80.0 /usr/bin/rustc")
    sys.exit(0)

if tool == "git":
    print("fixture-head")
    sys.exit(0)

if tool == "node":
    with (repo / "started-children.log").open("a") as stream:
        stream.write("node\n")
    print("fixture preparation finished")
    sys.exit(0)

if "--import" in sys.argv:
    print("fixture engine imported")
    sys.exit(0)

script = sys.argv[sys.argv.index("--script") + 1]
suite = "sdk" if "/sdk/" in script else "levels"
destination = results / (suite + ".json")
assert not destination.exists(), "stale suite evidence was not removed before the child started"

if mode == "stale_failure":
    print("SCRIPT ERROR: controlled producer failure before any new evidence")
    sys.exit(1)

if mode == "zero_without_completion":
    print("Godot fixture exited at --quit-after before completing its test")
    sys.exit(0)

if mode == "marker_without_file":
    print('PORTITOR_TEST_RESULT={"suite":"' + suite + '","ok":true}')
    sys.exit(0)

if suite == "levels":
    payload = {"suite": "levels", "ok": True, "levels": [{
        "id": "M01", "uid": "level:M01", "sdk_verified": True,
        "author_solution_verified": True, "won": True,
        "spec_checks": [{"text": "controlled completed goal", "status": "pass", "assertions": ["fixture.actual_goal"]}],
    }]}
else:
    payload = {"suite": "sdk", "ok": True, "checks": [{
        "id": "sample.a.fixture_count", "status": "pass", "expected": 256, "actual": 256,
    }]}
if mode == "completed_failed_acceptance":
    payload["ok"] = False
    payload["levels"][0]["id"] = "M06"
    payload["levels"][0]["uid"] = "level:M06"
    payload["levels"][0]["acceptance_ok"] = False
    payload["levels"][0]["spec_checks"] = [{
        "text": "controlled unresolved alternative", "status": "not_run", "assertions": [],
    }]
destination.write_text(json.dumps(payload))

if mode == "source_mutation":
    (repo / "game/core/fixture.gd").write_text("extends RefCounted\nconst VERSION = 2\n")

if mode != "file_without_marker":
    print("PORTITOR_TEST_RESULT=" + json.dumps({"suite": suite, "ok": payload["ok"]}))
sys.exit(1 if mode == "completed_failed_acceptance" else 0)
'''


class RunnerEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="portitor-runner-evidence-")
        self.repo = Path(self.temporary.name)
        self.results = self.repo / "game/tests/results"
        self.reports = self.repo / "game/reports"
        self.results.mkdir(parents=True)
        self.reports.mkdir(parents=True)
        self.tools = self.repo / "game/tools"
        self.tools.mkdir(parents=True)
        shutil.copy2(RUNNER, self.tools / "run_tests.py")
        self.repo.joinpath("game/core").mkdir()
        self.repo.joinpath("game/core/fixture.gd").write_text("extends RefCounted\nconst VERSION = 1\n")
        self.bin = self.repo / "fixture-bin"
        self.bin.mkdir()
        for name in ("godot-fixture", "node", "ps", "git"):
            executable = self.bin / name
            executable.write_text(textwrap.dedent(PRODUCER))
            executable.chmod(0o700)
        # Prior successes deliberately exist: a failed new run must invalidate
        # their authority without modifying any real project's report files.
        self.reports.joinpath("verification.json").write_text(json.dumps({
            "levels": [{"id": "OLD_LEVEL", "sdk_verified": True}],
            "samples": [{"id": "OLD_SAMPLE", "ok": True}],
            "references": [{"name": "OLD_REFERENCE", "diff_pixels": 0}],
        }))

    def tearDown(self):
        self.temporary.cleanup()

    def run_fixture(self, suite, mode, old_report=None, stage_name=None):
        if old_report is not None:
            self.results.joinpath(suite + ".json").write_text(json.dumps(old_report))
        env = dict(os.environ)
        env["PATH"] = str(self.bin) + os.pathsep + env.get("PATH", "")
        env["PORTITOR_FIXTURE_MODE"] = mode
        env["PORTITOR_FIXTURE_ANCESTOR_PID"] = str(os.getpid())
        result = subprocess.run(
            [sys.executable, str(self.tools / "run_tests.py"), str(self.bin / "godot-fixture"), "--suites", suite],
            cwd=self.repo, env=env, text=True, capture_output=True, timeout=20,
        )
        report = json.loads(self.reports.joinpath("verification.json").read_text())
        stage = next(item for item in report["suites"] if item["name"] == (stage_name or suite))
        observed = json.loads(self.repo.joinpath("invalidation_observed.json").read_text())
        self.assertTrue(observed["run_incomplete"])
        self.assertEqual(observed["levels"], [])
        return result, report, stage

    def test_old_level_report_is_not_republished_after_failed_child(self):
        old = {"levels": [{"id": "OLD_LEVEL", "sdk_verified": True, "spec_checks": []}]}
        result, report, stage = self.run_fixture("levels", "stale_failure", old)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(stage["ok"])
        self.assertFalse(stage["completed"])
        self.assertEqual(report["levels"], [])
        self.assertFalse(self.results.joinpath("levels.json").exists())

    def test_old_sdk_report_is_not_republished_after_failed_child(self):
        old = {"checks": [{"id": "sample.a.old", "status": "pass"}]}
        result, report, stage = self.run_fixture("sdk", "stale_failure", old)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(stage["ok"])
        self.assertEqual(report["samples"], [])
        self.assertFalse(self.results.joinpath("sdk.json").exists())

    def test_zero_exit_without_completion_is_failure(self):
        result, report, stage = self.run_fixture("levels", "zero_without_completion")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(stage["exit_code"], 0)
        self.assertFalse(stage["completed"])
        self.assertFalse(stage["ok"])
        self.assertEqual(report["levels"], [])

    def test_completion_marker_without_fresh_file_cannot_use_old_success(self):
        old = {"levels": [{"id": "OLD_LEVEL", "sdk_verified": True, "spec_checks": []}]}
        result, report, stage = self.run_fixture("levels", "marker_without_file", old)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(stage["completed"])
        self.assertEqual(report["levels"], [])

    def test_fresh_level_file_without_marker_is_not_authoritative(self):
        result, report, stage = self.run_fixture("levels", "file_without_marker")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(stage["completed"])
        self.assertFalse(stage["ok"])
        self.assertEqual(report["levels"], [])
        self.assertTrue(self.results.joinpath("levels.json").exists(), "keep incomplete raw evidence for diagnostics")

    def test_fresh_sdk_file_without_marker_is_not_authoritative(self):
        result, report, stage = self.run_fixture("sdk", "file_without_marker")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(stage["completed"])
        self.assertEqual(report["samples"], [])

    def test_fresh_completed_level_evidence_is_retained(self):
        result, report, stage = self.run_fixture("levels", "complete")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(stage["completed"])
        self.assertTrue(stage["ok"])
        self.assertEqual([level["id"] for level in report["levels"]], ["M01"])
        self.assertEqual(report["levels"][0]["checks"], [{
            "text": "controlled completed goal", "ok": True, "status": "pass", "assertions": ["fixture.actual_goal"],
        }])
        self.assertFalse(report["run_incomplete"])

    def test_completed_failed_acceptance_preserves_actual_author_results(self):
        result, report, stage = self.run_fixture("levels", "completed_failed_acceptance")
        self.assertEqual(result.returncode, 1)
        self.assertTrue(stage["completed"])
        self.assertFalse(stage["ok"])
        self.assertEqual([level["id"] for level in report["levels"]], ["M06"])
        self.assertTrue(report["levels"][0]["author_solution_verified"])
        self.assertFalse(report["levels"][0]["acceptance_ok"])
        self.assertEqual(report["levels"][0]["checks"][0]["status"], "not_run")
        self.assertFalse(report["levels"][0]["checks"][0]["ok"])

    def test_source_mutation_invalidates_authoritative_evidence_but_keeps_raw_results(self):
        result, report, stage = self.run_fixture("sdk,levels", "source_mutation", stage_name="levels")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertTrue(stage["completed"], "the child finished before its source changed")
        self.assertTrue(report["run_incomplete"])
        self.assertTrue(report["source_changed"])
        self.assertNotEqual(report["tested_source_sha256"], report["source_sha256_at_end"])
        for key in ("levels", "samples", "references", "ui_behaviors"):
            self.assertEqual(report[key], [], key)
        for key in ("performance", "performance_capacity"):
            self.assertEqual(report[key]["status"], "invalidated_source_change", key)
        self.assertTrue(self.results.joinpath("levels.json").exists())
        self.assertTrue(self.results.joinpath("sdk.json").exists())
        self.assertIn("PORTITOR_TEST_RESULT=", self.results.joinpath("levels.log").read_text())

    def test_two_other_compute_processes_block_all_test_children(self):
        result, report, stage = self.run_fixture("levels", "budget_full", stage_name="importer")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertTrue(report["run_incomplete"])
        self.assertFalse(stage["completed"])
        self.assertFalse(stage["ok"])
        self.assertTrue(stage["budget_blocked"])
        self.assertEqual([item["pid"] for item in report["resource_budget"]["other_compute_processes"]], [700001, 700002])
        self.assertFalse(self.repo.joinpath("started-children.log").exists(), "no test/build child may start")
        self.assertEqual(report["levels"], [])
        self.assertEqual(report["samples"], [])
        self.assertEqual(report["references"], [])

    def test_one_compute_process_allows_one_worker_and_ignores_ancestors_and_connectors(self):
        result, report, stage = self.run_fixture("levels", "budget_single")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(stage["ok"])
        self.assertEqual(report["worker_count"], 1)
        self.assertFalse(report["run_incomplete"])
        self.assertFalse(report["source_changed"])
        self.assertTrue(self.repo.joinpath("started-children.log").exists())

    def test_budget_is_checked_again_before_the_next_child(self):
        result, report, stage = self.run_fixture("levels", "budget_after_preparation", stage_name="resources")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertTrue(report["run_incomplete"])
        self.assertTrue(stage["budget_blocked"])
        self.assertEqual(self.repo.joinpath("started-children.log").read_text().splitlines(), ["node"])
        self.assertEqual(len(report["suites"]), 2)

    def test_unknown_capacity_keeps_the_default_single_worker(self):
        result, report, stage = self.run_fixture("levels", "preflight_unknown")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(stage["ok"])
        self.assertEqual(report["worker_count"], 1)
        self.assertFalse(report["run_incomplete"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
