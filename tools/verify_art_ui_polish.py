#!/usr/bin/env python3
"""Check the complete polish candidate, screenshots, preservation and native package."""
import argparse, hashlib, json, subprocess
from pathlib import Path
from PIL import Image, ImageChops
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/art-ui-polish'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--run',required=True,help='full suite evidence, relative to project')
parser.add_argument('--require-package',action='store_true')
a=parser.parse_args();run=ROOT/a.run
def read(p):return json.loads(Path(p).read_text())
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
frozen=read(ROOT/'artifacts/stage2a/frozen-files.json')
assert all(digest(ROOT/p)==h for p,h in frozen.items()),'frozen SDK or accepted level changed'
assert not subprocess.check_output(['git','diff','--name-only','6af71f0','--','artifacts/stage2a','artifacts/macos-stage2a'],cwd=ROOT,text=True).strip(),'historical evidence modified'
suite=read(run/'logs/test-summary.json')
assert suite['passed_executed_tests'] and suite['completed_test_count']==suite['requested_test_count']==25
campaign=read(run/'campaign-verification.json');assert campaign['total']==campaign['solved']==36 and campaign['failures']==0
perf=read(run/'performance.json');assert perf['max_us']<=4000 and perf['failures']==0 and len(perf['levels'])==36
snapshot=run/'test-input-hashes.json'
assert suite.get('inputs_unchanged') and digest(snapshot)==suite['test_input_snapshot_sha256'],'run snapshot missing or changed'
for source,h in read(snapshot).items():assert digest(ROOT/source)==h,source+' changed after full test snapshot'
levels=[read(p) for p in sorted((ROOT/'pushbox/levels/campaign').rglob('*.json'))]
assert len(levels)==36
for d in levels:
 assert len(d['solution'])==len(d['solution_hashes'])==len(d['solution_keys'])>0
 if d['theme_id']=='sky_island':
  assert d['map'][0]=='.'*len(d['map'][0])
  assert all(row[0]==row[-1]=='.' for row in d['map'])
  assert '.' in d['map'][-1]
 assert d['map']!=read(OUT/'baseline-levels'/(d['id']+'.json'))['map']
manifest=read(OUT/'captures/manifest.json');assert manifest['failures']==0
assert len(manifest['animation_pairs'])==6 and all(x['all_frames_changed'] for x in manifest['animation_pairs'])
pngs={}
for c in manifest['captures']:
 native_path=OUT/'captures'/(c['name']+'-native.png');hd_path=OUT/'captures'/(c['name']+'-1920x1080.png')
 with Image.open(native_path) as n,Image.open(hd_path) as hd:
  assert n.size==(320,180) and hd.size==(1920,1080)
  expected=n.convert('RGBA').resize(hd.size,Image.Resampling.NEAREST)
  assert ImageChops.difference(expected,hd.convert('RGBA')).getextrema()==((0,0),)*4
 pngs[str(native_path.relative_to(ROOT))]=digest(native_path);pngs[str(hd_path.relative_to(ROOT))]=digest(hd_path)
assert sum('-opening-' in c['name'] for c in manifest['captures'])==36
for pair in manifest['animation_pairs']:
 paths=[OUT/'captures'/(pair['theme']+'-animation-'+str(i)+'-native.png') for i in range(3)]
 assert len({digest(p) for p in paths})==3,'static animation evidence'
package=None
if a.require_package:
 package=read(ROOT/'artifacts/macos-art-ui-polish/manifest.json')
 assert package['app_version']=='0.4.1' and package['package_smoke_passed'] and package['sdk_bytes_unchanged'] and package['package_smoke_checks']>=2877
 assert package['test_input_snapshot_sha256']==digest(snapshot),'package belongs to a different tested source'
 assert digest(ROOT/'artifacts/macos-art-ui-polish'/package['dmg'])==package['dmg_sha256']
 libs=list((ROOT/'artifacts/macos-art-ui-polish/Pushbox.app').rglob('libele_godot.dylib'))
 assert len(libs)==1 and digest(libs[0])==frozen['bin/libele_godot.dylib']
report={'date':'2026-10-15','status':'art_ui_playtest_candidate','formal_release':False,'user_acceptance':False,'workers':1,'suite_scripts':25,'run':a.run,'campaign_solved':'36/36','checks':campaign['checks'],'author_actions':sum(len(d['solution']) for d in levels),'frozen_files':len(frozen),'historical_evidence_preserved':True,'T8':perf,'screenshots':len(pngs),'animation_themes':manifest['animation_pairs'],'screenshot_hashes':pngs,'package':package and {'file':package['dmg'],'sha256':package['dmg_sha256'],'app_version':package['app_version'],'signed':package['signed'],'notarized':package['notarized']}}
(OUT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f"Polish verified: 25/25 scripts; 36/36; {campaign['checks']} checks; T8 {perf['max_us']/1000:.3f}ms; {len(pngs)} PNGs; frozen={len(frozen)}; package={bool(package)}")
