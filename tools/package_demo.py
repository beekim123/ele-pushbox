#!/usr/bin/env python3
"""Package source, the built extension, licenses and measured evidence."""
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
files = [root/name for name in ['.gitignore', 'README.md', 'Run Demo.command', 'project.godot', 'ele.gdextension']]
for directory in ['bin', 'pushbox', 'tests', 'tools', 'docs', 'artifacts/logs', 'artifacts/v03/m1', 'artifacts/v03/m2', 'artifacts/v03/m3', 'artifacts/v03/logs', 'artifacts/v03/scheduling']:
    files.extend(p for p in (root/directory).rglob('*') if p.is_file() and p.suffix not in ['.uid', '.pyc'] and '__pycache__' not in p.parts and p.name != '.DS_Store')
files.extend(root/'artifacts/v03'/name for name in ['core-preservation.json', 'visual-validation.json'])
files.append(root/'artifacts/v03/package-smoke-latest.log')
files = sorted(set(files))
assert (root/'bin/libele_godot.dylib').is_file(), 'SDK extension missing'
summary = json.loads((root/'artifacts/v03/logs/test-summary.json').read_text())
assert summary['completed_test_count'] == summary['requested_test_count'], 'test suite incomplete'
failed_tests = [r['test'] for r in summary['results'] if not r['passed']]
assert not failed_tests and summary['passed_executed_tests'], 'latest validation failure blocks packaging'
manifest = {'date': '2026-10-13', 'candidate_version': '0.3', 'sdk_version': '1.2.0', 'godot_version': summary['godot'], 'workers': 1, 'not_run': summary['not_run'], 'all_executed_tests_passed': summary['passed_executed_tests'], 'failed_tests': failed_tests, 'status': 'candidate', 'files': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
manifest_path = root/'artifacts/v03/artifact-manifest.json'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
files.append(manifest_path)
destination = root/'artifacts/pushbox-demo-v03-2026-10-13.zip'
with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in files:
        archive.write(path, 'pushbox-demo/'+str(path.relative_to(root)))
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None, 'ZIP CRC mismatch'
info = {'file': destination.name, 'bytes': destination.stat().st_size, 'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(), 'entries': len(files)}
(root/'artifacts/v03/package-info.json').write_text(json.dumps(info, indent=2)+'\n')
print(json.dumps(info, indent=2))
