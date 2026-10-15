#!/usr/bin/env python3
"""Serial, bounded test runner. Engine errors fail even when Godot returns 0."""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
RESULTS = GAME / "tests/results"
REPORTS = GAME / "reports"


def source_fingerprint():
    digest = hashlib.sha256()
    for directory in ["app", "core", "sim", "gameplay", "modes", "meta", "presentation", "tools", "tests"]:
        for path in sorted((GAME / directory).rglob("*")):
            if path.is_file() and path.suffix in (".gd", ".tscn", ".gdshader", ".mjs", ".py") and "results" not in path.relative_to(GAME / directory).parts:
                digest.update(str(path.relative_to(ROOT)).encode())
                digest.update(hashlib.sha256(path.read_bytes()).digest())
    for path in [GAME / "project.godot", GAME / "ele.gdextension", ROOT / "run.sh"]:
        if path.is_file():
            digest.update(str(path.relative_to(ROOT)).encode())
            digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def other_compute_processes(output):
    processes = {}
    for line in output.splitlines():
        fields = line.split(None, 3)
        if len(fields) != 4:
            continue
        try:
            pid, ppid, cpu = int(fields[0]), int(fields[1]), float(fields[2])
        except ValueError:
            continue
        processes[pid] = {"pid": pid, "ppid": ppid, "pcpu": cpu, "comm": fields[3]}
    ancestors = {os.getpid(), os.getppid()}
    current = os.getpid()
    while current in processes:
        parent = processes[current]["ppid"]
        if parent <= 0 or parent == current:
            break
        ancestors.add(parent)
        current = parent
        if current not in processes or processes[current]["ppid"] in ancestors:
            break
    workers = []
    # Bare node processes also host connectors; browser helpers are ordinary
    # applications. Do not infer a compute job from either name or CPU alone.
    known_workers = {"rustc", "clang", "clang++", "gcc", "g++", "cc1", "cc1plus", "swift-frontend", "ffmpeg", "blender"}
    for pid, item in processes.items():
        if pid in ancestors:
            continue
        executable = Path(item["comm"]).name.lower()
        engine = executable == "godot" or executable.startswith(("godot_", "godot-"))
        numeric_python = bool(re.fullmatch(r"python(?:\d+(?:\.\d+)*)?", executable)) and item["pcpu"] >= 10.0
        if engine or executable in known_workers or numeric_python:
            workers.append(item)
    return sorted(workers, key=lambda item: item["pid"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("godot")
    parser.add_argument("--gpu", action="store_true", help="also run actual macOS renderer comparisons")
    parser.add_argument("--suites", default="core,sdk,gameplay,levels,ids,render,lab,ui,ui-contracts")
    args = parser.parse_args()
    RESULTS.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1")
    # Each invocation gets fresh test data. Never use the player's save file.
    storage = tempfile.TemporaryDirectory(prefix="portitor-test-")
    env["PUSHBOX_TEST_STORAGE"] = storage.name
    stages = []
    run_id = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + "-" + str(os.getpid())
    def archive(path):
        if path.is_file():
            target = RESULTS / "history" / run_id / path.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    archive(REPORTS / "verification.json")
    # Invalidate the previous aggregate before any subprocess starts. Interrupted
    # runs must never leave an old passing report with a new implied status.
    (REPORTS / "verification.json").write_text(json.dumps({"format":"pushbox.verification/1", "generated":datetime.datetime.now(datetime.timezone.utc).isoformat(), "run_incomplete":True, "milestone_complete":False, "levels":[], "samples":[], "references":[]}) + "\n")
    tested_source_sha256 = source_fingerprint()
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, capture_output=True).stdout.strip()
    archive(RESULTS / "process-preflight.log")
    (RESULTS / "process-preflight.log").unlink(missing_ok=True)
    budget_blocked = None
    resource_budget = {"blocked": False, "worker_count": 1}

    def preflight(name):
        nonlocal resource_budget
        resource_budget = {"blocked": False, "worker_count": 1, "before_stage": name, "available": False, "other_compute_processes": []}
        try:
            process_info = subprocess.run(["ps", "-axo", "pid,ppid,pcpu,comm"], text=True, capture_output=True, timeout=5)
            output = process_info.stdout or process_info.stderr
            if process_info.returncode == 0:
                resource_budget["available"] = True
                resource_budget["other_compute_processes"] = other_compute_processes(process_info.stdout)
            else:
                output += "\nCannot confirm spare capacity; using one worker.\n"
        except (OSError, subprocess.TimeoutExpired) as error:
            output = str(error) + "\nCannot confirm spare capacity; using one worker.\n"
        resource_budget["blocked"] = len(resource_budget["other_compute_processes"]) >= 2
        with (RESULTS / "process-preflight.log").open("a") as stream:
            stream.write("Before stage: " + name + "\n" + output + "\n" + json.dumps(resource_budget) + "\n")
        return resource_budget["blocked"]

    def run(name, command, timeout=90):
        nonlocal budget_blocked
        if budget_blocked is not None:
            return False
        archive(RESULTS / (name + ".log"))
        if preflight(name):
            budget_blocked = dict(resource_budget)
            output = "RESOURCE BUDGET: two or more other compute processes are present; child was not started.\n"
            (RESULTS / (name + ".log")).write_text(output)
            stages.append({"name": name, "ok": False, "completed": False, "exit_code": None, "engine_errors": False, "seconds": 0.0, "command": command, "log": "game/tests/results/" + name + ".log", "budget_blocked": True})
            print(name + ": BLOCKED (global compute budget)", flush=True)
            return False
        evidence_files = {
            "sdk": RESULTS / "sdk.json", "gameplay": RESULTS / "gameplay.json", "levels": RESULTS / "levels.json",
            "ids": REPORTS / "id-checks.json", "world-gpu": REPORTS / "world-reference-report.json",
            "showcase-gpu": REPORTS / "showcase-reference-report.json", "ui-gpu": REPORTS / "ui-reference-report.json",
            "dynamic-gpu": REPORTS / "dynamic-render-report.json", "sdk-seam-gpu": REPORTS / "sdk-seam-reference-report.json",
            "performance": REPORTS / "performance.json",
            "performance-capacity": REPORTS / "performance-capacity.json",
        }
        evidence = evidence_files.get(name)
        if evidence is not None:
            archive(evidence)
            evidence.unlink(missing_ok=True)
        started = time.monotonic()
        try:
            completed = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
            output, code = completed.stdout, completed.returncode
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b"").decode(errors="replace") if isinstance(error.stdout, bytes) else (error.stdout or "")
            output += "\nTEST TIMEOUT: process terminated by runner.\n"
            code = 124
        (RESULTS / (name + ".log")).write_text(output)
        errors = bool(re.search(r"^(?:SCRIPT ERROR:|ERROR:)", output, re.MULTILINE))
        completion_patterns = {"core":"core services: 0 failure(s)", "sdk":"PORTITOR_TEST_RESULT=", "gameplay":"PORTITOR_TEST_RESULT=", "levels":"PORTITOR_TEST_RESULT=", "ids":"id checks:", "render":"render reference failures:", "lab":'"suite":"lab"', "ui":'"suite":"ui"', "ui-contracts":'"suite":"ui-contracts"', "terrain-gpu":"terrain GPU reference failures:", "world-gpu":"World reference report:", "showcase-gpu":"showcase differences=", "dynamic-gpu":'"format":"portitor.dynamic-render/1"', "sdk-seam-gpu":"SDK seam", "performance":"PORTITOR_PERFORMANCE_COMPLETE", "performance-capacity":"PORTITOR_PERFORMANCE_COMPLETE", "ui-gpu":'"suite":"ui-gpu"'}
        complete = completion_patterns.get(name, "") in output and (evidence is None or evidence.is_file())
        item = {"name": name, "ok": code == 0 and not errors and complete, "completed": complete, "exit_code": code, "engine_errors": errors, "seconds": round(time.monotonic() - started, 3), "command": command, "log": "game/tests/results/" + name + ".log"}
        stages.append(item)
        print(f"{name}: {'PASS' if item['ok'] else 'FAIL'} ({item['seconds']}s)", flush=True)
        if not item["ok"]:
            concise = [line for line in output.splitlines() if re.match(r"^(?:FAIL|ERROR|SCRIPT ERROR|PORTITOR_TEST_RESULT|TEST TIMEOUT)", line)]
            print("\n".join(concise[:12]), flush=True)
        return item["ok"]

    run("importer", ["node", "--test", "--test-concurrency=1", "game/tests/core/import_resources.test.mjs", "game/tests/core/mechanic_stubs.test.mjs"])
    prepared = run("resources", ["node", "game/tools/import_resources.mjs", "import"])
    prepared = run("model-export", ["node", "game/tools/export_model.mjs"]) and prepared
    prepared = run("reference-export", ["node", "game/tests/refs/generate_workbench_refs.mjs"]) and prepared
    # Import must follow generated-tree rebuilding so PNG .import sidecars exist.
    prepared = run("godot-import", [args.godot, "--headless", "--path", str(GAME), "--import"]) and prepared
    names = {
        "core": "tests/core/services_test.gd", "sdk": "tests/sdk/run.gd",
        "gameplay": "tests/gameplay/run.gd", "levels": "tests/levels/run.gd",
        "ids": "tools/check_ids.gd", "render": "tests/refs/test_render.gd",
        "lab": "tests/modes/lab_test.gd",
        "ui": "tests/ui/run.gd", "ui-contracts": "tests/ui/contracts.gd",
    }
    if prepared:
        for name in args.suites.split(","):
            run(name, [args.godot, "--headless", "--path", str(GAME), "--script", "res://" + names[name]])
        if args.gpu:
            for name, path in [("terrain-gpu", "refs/test_terrain_shader.gd"), ("world-gpu", "refs/test_world_view.gd"), ("showcase-gpu", "refs/test_showcase.gd"), ("dynamic-gpu", "refs/test_dynamic_cells.gd"), ("sdk-seam-gpu", "refs/test_sdk_seam.gd"), ("performance", "refs/test_performance.gd"), ("ui-gpu", "ui/capture.gd")]:
                run(name, [args.godot, "--path", str(GAME), "--display-driver", "macos", "--audio-driver", "Dummy", "--script", "res://tests/" + path])
                if name == "performance":
                    run("performance-capacity", [args.godot, "--path", str(GAME), "--display-driver", "macos", "--audio-driver", "Dummy", "--script", "res://tests/refs/test_performance.gd", "--", "--uncapped"])
    def read(path, default):
        try:
            return json.loads(path.read_text())
        except (OSError, ValueError):
            return default
    level_data = read(RESULTS / "levels.json", {}) if any(s["name"] == "levels" and s["completed"] for s in stages) else {}
    sample_data = read(RESULTS / "sdk.json", {}) if any(s["name"] == "sdk" and s["completed"] for s in stages) else {}
    references = []
    for stage_name, filename in ([("world-gpu", "world-reference-report.json"), ("showcase-gpu", "showcase-reference-report.json"), ("ui-gpu", "ui-reference-report.json"), ("sdk-seam-gpu", "sdk-seam-reference-report.json")] if args.gpu else []):
        if not any(stage["name"] == stage_name and stage["completed"] for stage in stages):
            continue
        value = read(REPORTS / filename, {})
        references.extend(value.get("references", []))
        for case in value.get("cases", []):
            references.append({"name": "level." + case["level"] + ".world_without_hud" if "level" in case else str(case.get("theme", "showcase")), "diff_pixels":case.get("static_pixel_differences", case.get("pixel_differences")), "sdk_validation":stage_name == "world-gpu", "screenshot":case.get("capture"), "detail":case})
    source_sha256_at_end = source_fingerprint()
    source_changed = source_sha256_at_end != tested_source_sha256
    levels = []
    for raw in level_data.get("levels", []):
        item = {key: value for key, value in raw.items() if key not in ("checks", "steps", "spec_checks")}
        item["checks"] = [{"text": check["text"], "ok": check.get("status") == "pass", "status": check.get("status"), "assertions": check.get("assertions", [])} for check in raw.get("spec_checks", [])]
        levels.append(item)
    samples = []
    for letter, name in [("a", "sand_overflow"), ("b", "earth_static"), ("c", "crate_conservation"), ("d", "stable_settle"), ("e", "snapshot_restore")]:
        checks = [check for check in sample_data.get("checks", []) if check.get("id", "").startswith("sample." + letter + ".")]
        if checks:
            samples.append({"id": "sdk." + name, "ok": all(check.get("status") == "pass" for check in checks), "assertion_count": len(checks), "evidence": "game/tests/results/sdk.json"})
    report = {"format": "pushbox.verification/1", "generated": datetime.datetime.now(datetime.timezone.utc).isoformat(), "commit": commit,
              "run_id": run_id,
              "tested_source_sha256": tested_source_sha256, "source_sha256_at_end": source_sha256_at_end, "source_changed": source_changed,
              "working_tree": True, "sdk": "v1.2.0 dacb93e", "godot": "4.7.2", "worker_count": 1,
              "stage": "stage1-development-candidate", "milestone_complete": False,
              "levels": levels, "samples": samples, "references": references,
              "run_incomplete": source_changed or budget_blocked is not None, "resource_budget": budget_blocked or resource_budget,
              "performance": read(REPORTS / "performance.json", {}) if any(stage["name"] == "performance" and stage["completed"] for stage in stages) else {"status":"not_run"},
              "performance_capacity": read(REPORTS / "performance-capacity.json", {}) if any(stage["name"] == "performance-capacity" and stage["completed"] for stage in stages) else {"status":"not_run"},
              "ui_behaviors": read(REPORTS / "ui-reference-report.json", {}).get("behaviors", []) if any(stage["name"] == "ui-gpu" and stage["completed"] for stage in stages) else [],
              "suites": stages, "limitations": ["Stage two has not started.", "Pending UI/bubble approvals block release.", "See docs/status.md for individual acceptance gaps; passing author replays do not waive them."]}
    if report["run_incomplete"]:
        reason = "source_change" if source_changed else "resource_budget"
        for key in ("levels", "samples", "references", "ui_behaviors"):
            report[key] = []
        for key in ("performance", "performance_capacity"):
            report[key] = {"status": "invalidated_" + reason}
        report["limitations"].append("Source changed during this run; raw logs are diagnostic only." if source_changed else "Global compute budget blocked a child; raw logs are diagnostic only.")
    (REPORTS / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    storage.cleanup()
    return 0 if not report["run_incomplete"] and stages and all(item["ok"] for item in stages) else 1


if __name__ == "__main__":
    raise SystemExit(main())
