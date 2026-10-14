#!/usr/bin/env python3
"""Verify a candidate manifest, executable modes, and extracted startup."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
archive_path = root/'artifacts/pushbox-demo-v03-2026-10-13.zip'
candidates = [os.environ.get('PUSHBOX_GODOT_BIN'), '/Applications/Godot.app/Contents/MacOS/Godot', str(Path.home()/'Desktop/CURRGO/ele-proj/zips/Godot.app/Contents/MacOS/Godot')]
godot = next(value for value in candidates if value and Path(value).is_file())
environment = dict(os.environ)
for name in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS']:
    environment[name] = '1'
test_user_dir = None
logs = []
try:
    with tempfile.TemporaryDirectory(prefix='codex-pushbox-v03-', dir='/private/tmp') as temporary:
        with zipfile.ZipFile(archive_path) as archive:
            assert archive.testzip() is None
            archive.extractall(temporary)
            for entry in archive.infolist():
                mode = entry.external_attr >> 16
                if mode:
                    os.chmod(Path(temporary)/entry.filename, mode & 0o777)
            assert archive.getinfo('pushbox-demo/Run Demo.command').external_attr >> 16 & 0o111
        project = Path(temporary)/'pushbox-demo'
        manifest = json.loads((project/'artifacts/v03/artifact-manifest.json').read_text())
        for name, expected in manifest['files'].items():
            assert hashlib.sha256((project/name).read_bytes()).hexdigest() == expected, name
        logs.append(f"Manifest {len(manifest['files'])} files verified; status={manifest['status']}; failed_tests={manifest['failed_tests']}\n")
        # Verify original bytes first; override only the disposable project config.
        custom_user_dir = 'CodexPushboxTests/'+Path(temporary).name
        test_user_dir = Path.home()/'Library/Application Support'/custom_user_dir
        config = (project/'project.godot').read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="'+custom_user_dir+'"')
        (project/'project.godot').write_text(config)
        (project/'.godot').mkdir(exist_ok=True)
        (project/'.godot/extension_list.cfg').write_text('res://ele.gdextension\n')
        for script, marker in [('m0','PASS M0:'), ('ui','UI: 0 failures')]:
            result = subprocess.run([godot,'--headless','--single-threaded-scene','--max-fps','60','--path',str(project),'--script',f'tests/{script}.gd','--quit-after','1800'], env=environment, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            logs.append(output)
            assert result.returncode == 0 and marker in output and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output
        logs.append('PACKAGE SMOKE PASS: extracted extension startup and five-room controller replay; all executed validations passed, T10 remains pending humans.\n')
finally:
    if test_user_dir is not None:
        shutil.rmtree(test_user_dir, ignore_errors=True)
    (root/'artifacts/v03/package-smoke-latest.log').write_text(''.join(logs))
print(''.join(logs))
