#!/usr/bin/env python3
"""Export the stage-1 candidate as a self-contained Apple silicon app and DMG."""
import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/macos-stage1'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default='/Users/key_/Desktop/CURRGO/ele-proj/zips/Godot.app/Contents/MacOS/Godot')
parser.add_argument('--stage', choices=['stage1','stage2a','art-ui-polish'], default='stage1')
parser.add_argument('--test-evidence', help='evidence directory for art-ui-polish full gate')
parser.add_argument('--template', default='/private/tmp/pushbox-macos-template-4.7.2.zip')
args = parser.parse_args()
if args.stage != "stage1":
    OUT = ROOT / ("artifacts/macos-"+args.stage)
environment = dict(os.environ)
for key in ['OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS', 'VECLIB_MAXIMUM_THREADS']:
    environment[key] = '1'
os.nice(10)
OUT.mkdir(parents=True, exist_ok=True)
(OUT/'logs').mkdir(exist_ok=True)

def run(command, name, timeout=120):
    result = subprocess.run(list(map(str,command)), env=environment, cwd='/private/tmp', capture_output=True, text=True, timeout=timeout)
    output = result.stdout + result.stderr
    (OUT/'logs'/f'{name}.log').write_text(output)
    if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
        raise RuntimeError(f'{name} failed ({result.returncode}): {output[-4000:]}')
    print(name + ': PASS', flush=True)
    return output

def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(1024*1024), b''):
            result.update(chunk)
    return result.hexdigest()

# Inspect the shared machine; never terminate a user's unrelated process.
processes = subprocess.check_output(['ps','-axo','pid,%cpu,comm,args'],text=True)
for line in processes.splitlines()[1:]:
    values = line.strip().split(None,3)
    if len(values) == 4 and int(values[0]) != os.getpid():
        idle_editor = Path(values[2]).name == 'Godot' and float(values[1]) < 5 and '--path' not in values[3] and '--script' not in values[3]
        if (Path(values[2]).name == 'Godot' and not idle_editor) or ('python' in Path(values[2]).name.lower() and ('tools/run_tests.py' in values[3] or float(values[1])>10)):
            raise RuntimeError('Compute already occupied by PID ' + values[0])
summary_path = ROOT/('artifacts/stage2a/logs/test-summary.json' if args.stage == 'stage2a' else 'artifacts/stage1/logs/final/test-summary.json')
if args.stage == 'art-ui-polish':
    assert args.test_evidence, '--test-evidence required for polish candidate'
    summary_path = ROOT/args.test_evidence/'logs/test-summary.json'
summary = json.loads(summary_path.read_text())
assert summary['passed_executed_tests'] and summary['completed_test_count'] == (25 if args.stage == 'art-ui-polish' else 24 if args.stage == 'stage2a' else 18)
if args.stage == 'art-ui-polish':
    snapshot = summary_path.parent.parent/'test-input-hashes.json'
    assert summary.get('inputs_unchanged') and digest(snapshot) == summary['test_input_snapshot_sha256'], 'full-run source snapshot missing or changed'
    assert all(digest(ROOT/p) == h for p,h in json.loads(snapshot.read_text()).items()), 'source changed since full gate; rerun before packaging'
assert Path(args.template).is_file(), 'macOS 4.7.2 export template missing'
template_dir = Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable'
template_dir.mkdir(parents=True,exist_ok=True)
installed_template = template_dir/'macos.zip'
if not installed_template.exists():
    shutil.copy(args.template,installed_template)
else:
    assert digest(installed_template) == digest(args.template), 'existing template differs; preserved'
sdk_hash = digest(ROOT/'bin/libele_godot.dylib')
assert sdk_hash == json.loads((ROOT/'bin/build-metadata.json').read_text())['dylib_sha256']

with tempfile.TemporaryDirectory(prefix='codex-pushbox-mac-',dir='/private/tmp') as directory:
    stage = Path(directory)
    shutil.copytree(ROOT/'pushbox',stage/'pushbox',ignore=shutil.ignore_patterns('*.png','*.import','*.uid'))
    # FileAccess needs the original font bytes, while the exporter remaps fonts
    # to imported resources. A non-resource alias preserves those exact bytes.
    original_font = stage/'pushbox/assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2'
    font_alias = stage/'pushbox/assets/fonts/pixel_font.bin'
    shutil.copy(original_font,font_alias)
    assert digest(original_font) == digest(font_alias)
    style_path = stage/'pushbox/scripts/ui/pixel_style.gd'
    style_path.write_text(style_path.read_text().replace('fusion-pixel-12px-proportional-zh_hans.otf.woff2','pixel_font.bin'))
    shutil.copytree(ROOT/'bin',stage/'bin')
    shutil.copy(ROOT/'ele.gdextension',stage/'ele.gdextension')
    shutil.copy(ROOT/'project.godot',stage/'project.godot')
    config = (stage/'project.godot').read_text().replace('[rendering]','[rendering]\ntextures/vram_compression/import_etc2_astc=true')
    # This exporter inserts the project title into XML without escaping '&'.
    # Keep the repository title intact; use a safe title in the export copy.
    config = config.replace('config/name="Pushbox · Sand & Water"','config/name="Pushbox Sand and Water"')
    config = config.replace('run/main_scene="res://pushbox/scenes/main.tscn"','run/main_scene="res://verification/bootstrap.tscn"')
    (stage/'project.godot').write_text(config)
    (stage/'verification').mkdir()
    shutil.copy(ROOT/'tools/macos_package_smoke.gd',stage/'verification/package_smoke.gd')
    shutil.copy(ROOT/'tools/macos_engine_license.gd',stage/'verification/engine_license.gd')
    shutil.copy(ROOT/'tools/macos_package_bootstrap.gd',stage/'verification/bootstrap.gd')
    (stage/'verification/bootstrap.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://verification/bootstrap.gd" id="1"]\n[node name="Pushbox" type="Node"]\nscript = ExtResource("1")\n')
    (stage/'.godot').mkdir()
    (stage/'.godot/extension_list.cfg').write_text('res://ele.gdextension\n')
    preset = '''[preset.0]
name="macOS Apple Silicon"
platform="macOS"
runnable=true
advanced_options=true
custom_features="stage1"
export_filter="all_resources"
include_filter="*.json,*.bin,*.txt,*.md"
exclude_filter="pushbox/assets/sprites/*"
export_path=""
script_export_mode=1
customized_files={
"res://pushbox/assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2": "keep"
}

[preset.0.options]
custom_template/debug="TEMPLATE"
custom_template/release="TEMPLATE"
binary_format/architecture="universal"
application/bundle_identifier="org.beekim.pushbox.stage1"
application/signature="PSBW"
application/app_category="public.app-category.games"
application/short_version="0.3.1"
application/version="0.3.1"
application/min_macos_version_arm64="15.6"
application/min_macos_version_x86_64="15.6"
application/export_angle=0
display/high_res=true
codesign/codesign=0
notarization/notarization=0
'''.replace('TEMPLATE',str(Path(args.template).resolve()))
    if args.stage == 'stage2a':
        preset = preset.replace('stage1','stage2a').replace('0.3.1','0.4.0')
    if args.stage == 'art-ui-polish':
        preset = preset.replace('stage1','art-ui-polish').replace('0.3.1','0.4.1')
    (stage/'export_presets.cfg').write_text(preset)
    (OUT/'export-preset-used.cfg').write_text(preset)
    run([args.godot,'--headless','--single-threaded-scene','--path',stage,'--import'],'import')
    app = OUT/'Pushbox.app'
    if app.exists():
        shutil.rmtree(app)
    run([args.godot,'--headless','--single-threaded-scene','--path',stage,'--export-release','macOS Apple Silicon',app],'export',180)

app = OUT/'Pushbox.app'
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
executable = app/'Contents/MacOS'/info['CFBundleExecutable']
if subprocess.check_output(['lipo','-archs',str(executable)],text=True).strip() != 'arm64':
    thin = executable.with_name(executable.name + '.arm64')
    run(['lipo',executable,'-thin','arm64','-output',thin],'thin-arm64')
    thin.chmod(0o755)
    thin.replace(executable)
info['LSArchitecturePriority'] = ['arm64']
info['LSMinimumSystemVersion'] = '15.6'
info['LSMinimumSystemVersionByArchitecture'] = {'arm64':'15.6'}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
assert subprocess.check_output(['lipo','-archs',str(executable)],text=True).strip() == 'arm64'
libraries = list(app.rglob('libele_godot.dylib'))
assert len(libraries) == 1 and digest(libraries[0]) == sdk_hash, 'SDK binary changed during export'
license_dir = app/'Contents/Resources/Licenses'
license_dir.mkdir(exist_ok=True)
for source in (ROOT/'bin').glob('*.txt'):
    shutil.copy(source,license_dir/source.name)
shutil.copy(ROOT/'bin/THIRD_PARTY.md',license_dir/'THIRD_PARTY.md')
shutil.copytree(ROOT/'pushbox/assets/fonts',license_dir/'fonts',ignore=shutil.ignore_patterns('*.woff2'))
# Read the exact runtime's license and third-party notices through Engine APIs.
run([executable,'--headless','--single-threaded-scene','--','--package-license'],'engine-license',30)
shutil.copy(OUT/'logs/engine-license.log',license_dir/'LICENSE-Godot.txt')
entitlements = OUT/'entitlements.plist'
entitlements.write_bytes(plistlib.dumps({'com.apple.security.cs.disable-library-validation':True}))
# The SDK is already linker-signed; keep its exact byte hash and sign the bundle.
run(['codesign','--verify','--strict',libraries[0]],'sdk-signature')
run(['codesign','--force','--sign','-','--options','runtime','--entitlements',entitlements,app],'sign')
run(['codesign','--verify','--deep','--strict',app],'signature-verify')
run([executable,'--headless','--single-threaded-scene','--','--package-smoke'],'package-smoke',90)
smoke = (OUT/'logs/package-smoke.log').read_text()
assert 'MAC PACKAGE:' in smoke and '0 failures' in smoke
smoke_checks = int(re.search(r'MAC PACKAGE: (\d+) checks, 0 failures',smoke).group(1))
if args.stage == 'art-ui-polish':
    assert smoke_checks >= 2877, 'polish package must replay all 36 levels'

with tempfile.TemporaryDirectory(prefix='codex-pushbox-dmg-',dir='/private/tmp') as directory:
    image_root = Path(directory)
    shutil.copytree(app,image_root/'Pushbox.app',symlinks=True)
    (image_root/'Applications').symlink_to('/Applications')
    (image_root/'安装说明.txt').write_text('推箱子：沙与水 · 第一阶段候选\n\n适用于 Apple silicon（M1/M2/M3/M4 等）及 macOS 15.6 或更新。\n将 Pushbox.app 拖到 Applications（应用程序），然后双击启动。无需另装 Godot 或 SDK。\n本包为 ad-hoc 测试签名，尚未 Apple 公证；系统拦截时，请在系统设置→隐私与安全性中选择仍要打开。\n从大厅选择教学模式即可试玩 T01–T04。\n')
    if args.stage == 'stage2a':
        (image_root/'安装说明.txt').write_text('推箱子：沙与水 · 第二阶段 A 外部试玩候选\n\nApple silicon / macOS 15.6+；将 Pushbox.app 拖入 Applications。\n大厅 → 闯关模式；每图先开 2 关，每通 1 关再开 2 关，满 3/6 解锁下一地图。\nTab 观察池可侦察全部 36 关。Z 撤销，R 重开，Esc 返回大厅/查看下一步提示。\n反馈请记录关卡编号、复现步骤及预期/实际表现。\n本包为 ad-hoc 测试签名，尚未 Apple 公证；系统拦截时可在系统设置→隐私与安全性中选择仍要打开。\n')
    if args.stage == 'art-ui-polish':
        (image_root/'安装说明.txt').write_text('推箱子：沙与水 · 美术与 UI 翻新试玩候选 0.4.1\n\nApple silicon / macOS 15.6+；拖入 Applications 后启动。\n大厅 → 闯关模式：六主题动态背景、航线徽章、实际关卡微缩窗。\nTab 观察池：Q/E 切世界，A/D 切关，F 切全景 / 原生细节；原生模式方向键或拖动平移。\n每图通 3/6 关开下一图；Z 撤销，R 重开，Esc 返回。\n验收回复：美术与 UI 优化验收：通过 / 需改……\n候选未正式发布；ad-hoc 测试签名，未 Apple 公证。\n')
    dmg = OUT/('Pushbox-'+args.stage+'-macos-arm64.dmg')
    run(['hdiutil','create','-volname','Pushbox Sand and Water','-srcfolder',image_root,'-format','UDZO','-imagekey','zlib-level=6','-ov',dmg],'dmg-create',180)
run(['hdiutil','verify',dmg],'dmg-verify',90)
manifest = {'status':'macOS_installation_candidate','date':'2026-10-15' if args.stage != 'stage1' else '2026-10-14','platform':'macOS arm64','minimum_macos':'15.6','godot':'4.7.2','app_version':'0.4.1' if args.stage == 'art-ui-polish' else '0.4.0' if args.stage == 'stage2a' else '0.3.1','sdk_sha256':sdk_hash,'sdk_bytes_unchanged':digest(libraries[0])==sdk_hash,'signed':'ad-hoc hardened runtime','notarized':False,'package_smoke_passed':True,'package_smoke_checks':smoke_checks,'dmg':dmg.name,'dmg_bytes':dmg.stat().st_size,'dmg_sha256':digest(dmg),'executable':str(executable.relative_to(app)),'app_files_sha256':{str(p.relative_to(app)):digest(p) for p in sorted(app.rglob('*')) if p.is_file()}}
if args.stage == 'art-ui-polish':
    manifest['test_evidence'] = args.test_evidence
    manifest['test_input_snapshot_sha256'] = digest(snapshot)
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('MACOS PACKAGE READY ' + str(dmg),flush=True)
