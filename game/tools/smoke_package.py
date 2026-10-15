#!/usr/bin/env python3
"""Launch the real exported app twice with fresh, disposable save directories."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
report_path = ROOT / "game/reports/package-smoke.json"
report_path.write_text(json.dumps({"format": "portitor.package-smoke/1", "passed": False, "run_incomplete": True, "cases": []}) + "\n")
app = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "builds/PORTITOR-Stage1-Candidate.app").resolve()
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
cases = []
for name, options in [("headless", ["--headless"]), ("window", ["--display-driver", "macos", "--audio-driver", "Dummy"])]:
    with tempfile.TemporaryDirectory(prefix="portitor-package-smoke-") as storage:
        env = dict(os.environ, PUSHBOX_TEST_STORAGE=storage, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1")
        command = [str(executable), *options, "--quit-after", "30", "--", "--level=level:M01"]
        try:
            result = subprocess.run(command, cwd=storage, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            if isinstance(output, bytes):
                output = output.decode(errors="replace")
            result = subprocess.CompletedProcess(command, 124, output + "\nSMOKE TIMEOUT: child terminated.\n")
        (ROOT / f"game/tests/results/package-smoke-{name}.log").write_text(result.stdout)
        save_path = Path(storage) / "progress.json"
        saved = json.loads(save_path.read_text()) if save_path.exists() else {}
        passed = result.returncode == 0 and not re.search(r"^(?:SCRIPT ERROR:|ERROR:)", result.stdout, re.M) and saved.get("last_level_uid") == "level:M01"
        cases.append({"mode": name, "passed": passed, "exit_code": result.returncode, "last_level_uid": saved.get("last_level_uid"), "command": command})
report = {"format": "portitor.package-smoke/1", "passed": all(case["passed"] for case in cases), "run_incomplete": False, "app": str(app), "binary_architecture": subprocess.check_output(["lipo", "-archs", str(executable)], text=True).strip(), "executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "pck_sha256": hashlib.sha256((app / "Contents/Resources/PORTITOR.pck").read_bytes()).hexdigest(), "cases": cases, "scope": "Actual exported app, real SDK M01 setup in headless and macOS window; no novice playtest or full packaged author replay claimed"}
(ROOT / "game/reports/package-smoke.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report, ensure_ascii=False))
sys.exit(0 if report["passed"] else 1)
