#!/usr/bin/env python3
"""Validate the stage-2A hard gates and produce an evidence manifest."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'artifacts/stage2a'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--require-package', action='store_true')
args = parser.parse_args()
def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):
    return json.loads(Path(path).read_text())

frozen = read(OUT/'frozen-files.json')
assert all(digest(ROOT/name) == value for name,value in frozen.items()), 'frozen SDK or accepted level changed'
for name in ['materials.json','profile.json','reactions.json']:
    baseline = subprocess.check_output(['git','show','6687206:pushbox/content/default/'+name],cwd=ROOT)
    assert (ROOT/'pushbox/content/legacy'/name).read_bytes() == baseline, 'legacy registry changed'
suite = read(OUT/'logs/test-summary.json')
assert suite['passed_executed_tests'] and suite['completed_test_count'] == suite['requested_test_count'] == 24
campaign = read(OUT/'campaign-verification.json')
assert campaign['solved'] == campaign['total'] == 36 and campaign['failures'] == 0
performance = read(OUT/'performance.json')
assert performance['failures'] == 0 and performance['max_us'] <= 4000 and len(performance['levels']) == 36
levels = sorted((ROOT/'pushbox/levels/campaign').rglob('*.json'))
assert len(levels) == 36
ids = set()
actions = 0
for path in levels:
    data = read(path)
    assert len(data['solution']) == len(data['solution_hashes']) == len(data['solution_keys']) > 0
    assert data['id'] not in ids
    ids.add(data['id'])
    actions += len(data['solution'])

capture_manifest = read(OUT/'captures/manifest.json')
pngs = {}
for item in capture_manifest['captures']:
    native_path = OUT/'captures'/f"{item['name']}-native.png"
    export_path = OUT/'captures'/f"{item['name']}-1920x1080.png"
    with Image.open(native_path) as native, Image.open(export_path) as exported:
        assert list(native.size) == item['native'] and exported.size == (1920,1080)
        factor = 1920//native.width
        assert exported.height == native.height*factor and factor in [3,6]
        expected = native.convert('RGBA').resize(exported.size,Image.Resampling.NEAREST)
        assert ImageChops.difference(expected,exported.convert('RGBA')).getextrema() == ((0,0),)*4
    pngs[str(native_path.relative_to(ROOT))] = digest(native_path)
    pngs[str(export_path.relative_to(ROOT))] = digest(export_path)
assert len(pngs) == 30

package = None
if args.require_package:
    package = read(ROOT/'artifacts/macos-stage2a/manifest.json')
    assert package['package_smoke_passed'] and package['sdk_bytes_unchanged']
    assert digest(ROOT/'artifacts/macos-stage2a'/package['dmg']) == package['dmg_sha256']
    libraries = list((ROOT/'artifacts/macos-stage2a/Pushbox.app').rglob('libele_godot.dylib'))
    assert len(libraries) == 1 and digest(libraries[0]) == frozen['bin/libele_godot.dylib']

paths = [ROOT/'project.godot',ROOT/'ele.gdextension']
paths += [p for p in (ROOT/'pushbox').rglob('*') if p.is_file() and p.suffix in ['.gd','.gdshader','.tscn','.json','.woff2']]
paths += list((ROOT/'tests').glob('*.gd'))
paths += [ROOT/p for p in ['tools/run_tests.py','tools/build_campaign.py','tools/record_campaign.gd','tools/install_campaign_recordings.py','tools/package_macos.py','tools/macos_package_smoke.gd','tools/verify_stage2a.py']]
source_hashes = {str(p.relative_to(ROOT)):digest(p) for p in sorted(set(paths))}
assert source_hashes == read(OUT/'test-input-hashes.json'), 'source changed after final test snapshot'
(OUT/'source-hashes.json').write_text(json.dumps(source_hashes,indent=2)+'\n')
report = {'date':'2026-10-15','status':'external_playtest_candidate' if package else 'technical_candidate', 'formal_release':False,'player_acceptance':False,'workers':1,'sdk_unchanged':True,'frozen_file_count':len(frozen),'suite_scripts':24,'campaign_solved':'36/36','campaign_checks':campaign['checks'],'author_actions':actions,'T5_T6_T7':True,'T8':performance,'screenshots_verified':len(pngs),'screenshot_hashes':pngs,'source_file_count':len(source_hashes),'package':package and {'file':package['dmg'],'sha256':package['dmg_sha256'],'signed':package['signed'],'notarized':package['notarized']}}
(OUT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f"Stage2A verified: 36/36, {campaign['checks']} checks, 24/24 scripts, T8 {performance['max_us']/1000:.3f} ms, 30 PNGs, {len(frozen)} frozen files; package={bool(package)}")
