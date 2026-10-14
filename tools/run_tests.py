#!/usr/bin/env python3
"""Run one Godot process at a time; retain output and enforce test markers."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=os.environ.get('PUSHBOX_GODOT_BIN'))
parser.add_argument('--performance', action='store_true', help='also run T8 with a real macOS window')
parser.add_argument('--only', help='run a single named script from the suite')
parser.add_argument('--record-tutorial', action='store_true', help='record tutorial hashes into artifacts/stage1/recorded')
parser.add_argument('--capture-stage1', action='store_true', help='run tutorial UI checks and export real 1920x1080 rendered screens')
args = parser.parse_args()
godot = args.godot or shutil.which('godot')
if not godot:
    candidates = [Path('/Applications/Godot.app/Contents/MacOS/Godot'), Path.home()/'Desktop/CURRGO/ele-proj/zips/Godot.app/Contents/MacOS/Godot']
    godot = next((str(p) for p in candidates if p.is_file()), None)
if not godot:
    parser.error('Godot 4.7.2 missing; pass --godot or set PUSHBOX_GODOT_BIN')
environment = dict(os.environ)
for key in ['OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS', 'VECLIB_MAXIMUM_THREADS']:
    environment[key] = '1'
# Inspect the global machine before starting compute; do not terminate others.
# Headless computation gets lower priority. Window timing checks use the same
# normal scheduling priority as Run Demo; each SDK still has exactly one worker.
if not args.performance and not args.capture_stage1:
    os.nice(10)
processes = subprocess.check_output(['ps', '-axo', 'pid,ppid,%cpu,comm,args'], text=True)
conflicts = []
for line in processes.splitlines()[1:]:
    columns = line.strip().split(None, 4)
    if len(columns) < 5:
        continue
    pid, parent, cpu, executable, arguments = columns
    if int(pid) in [os.getpid(), os.getppid()]:
        continue
    if Path(executable).name.lower() == 'godot' or ('python' in Path(executable).name.lower() and (float(cpu) > 10 or 'tools/run_tests.py' in arguments)):
        conflicts.append({'pid': int(pid), 'executable': Path(executable).name, 'cpu_percent': float(cpu)})
if conflicts:
    parser.error(f'compute budget occupied; wait for these processes: {conflicts}')
version = subprocess.check_output([godot, '--version'], text=True, env=environment).strip()
if not version.startswith('4.7.2.'):
    parser.error(f'Godot 4.7.2 required, found {version}')
(ROOT/'.godot').mkdir(exist_ok=True)
(ROOT/'.godot/extension_list.cfg').write_text('res://ele.gdextension\n')
log_dir = ROOT/'artifacts/v03/logs'
log_dir.mkdir(parents=True, exist_ok=True)
tests = [('m0', 'PASS M0:'), ('board', 'Board tests: 0 failures'), ('m1', 'M1: 0 failures'), ('edge_cases', 'checks, 0 failures'), ('acceptance', 'checks, 0 failures'), ('session_scheduling', 'checks, 0 failures'), ('ui', 'UI: 0 failures'), ('ui_interaction', 'v03 input: 17 checks, 0 failures'), ('ui_failure', 'checks, 0 failures'), ('inspect_levels', 'Inspection: 0 errors'), ('guides', 'checks, 0 failures'), ('v03_presentation', 'checks, 0 failures'), ('v03_render', 'checks, 0 failures')]
tests.append(('bugfix', 'checks, 0 failures'))
tests.append(('procedural_art', 'checks, 0 failures'))
tests.append(('lobby_stage1', 'checks, 0 failures'))
tests.append(('tutorial_stage1', 'checks, 0 failures'))
if args.performance:
    tests.append(('performance', 'Performance: 0 failures'))
if args.only:
    tests = [(name, marker) for name, marker in tests if name == args.only]
    if not tests:
        parser.error('unknown test name or performance requires --performance')
if args.record_tutorial:
    tests = [('record_tutorial', 'Record tutorial: 4/4')]
if args.capture_stage1:
    tests = [('tutorial_stage1', 'checks, 0 failures')]
results = []
# Test scenes get their own project/user directory. A user can keep playing
# the real project without test actions changing their learned guides.
temporary_project = tempfile.TemporaryDirectory(prefix='codex-pushbox-test-', dir='/private/tmp')
test_root = Path(temporary_project.name)
for name in ['bin', 'tests', 'tools', 'artifacts']:
    (test_root/name).symlink_to(ROOT/name, target_is_directory=True)
# Prove the runtime can start and render without any legacy sprite PNGs.
shutil.copytree(ROOT/'pushbox', test_root/'pushbox', ignore=shutil.ignore_patterns('*.png', '*.import'))
(test_root/'ele.gdextension').symlink_to(ROOT/'ele.gdextension')
custom_user_dir = f'CodexPushboxTests/{test_root.name}'
project_config = (ROOT/'project.godot').read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="'+custom_user_dir+'"')
# Native OS pointer traffic must not overwrite scripted hover coordinates.
# These window flags leave Input.parse_input_event usable by the old UI tests.
(test_root/'test_input_isolation.gd').write_text('extends Node\nfunc _ready() -> void:\n\tif DisplayServer.get_name() != "headless":\n\t\tget_tree().root.mouse_passthrough = true\n\t\tget_tree().root.unfocusable = true\n\tif OS.get_cmdline_args().has("tests/performance.gd"):\n\t\tget_tree().node_added.connect(_isolate_game)\nfunc _isolate_game(node: Node) -> void:\n\tif node.get_script() != null and node.get_script().resource_path == "res://pushbox/scripts/game.gd":\n\t\tnode.set_process_input.call_deferred(false)\n')
project_config += '\n[autoload]\nTestInputIsolation="*res://test_input_isolation.gd"\n'
(test_root/'project.godot').write_text(project_config)
(test_root/'.godot').mkdir()
(test_root/'.godot/extension_list.cfg').write_text('res://ele.gdextension\n')
test_user_dir = Path.home()/'Library/Application Support'/custom_user_dir
try:
    for name, marker in tests:
        script_dir = 'tools' if name == 'record_tutorial' else 'tests'
        frame_limit = '5400' if name == 'tutorial_stage1' else '1800'
        command = [godot, '--single-threaded-scene', '--max-fps', '60', '--path', str(test_root), '--script', f'{script_dir}/{name}.gd', '--quit-after', frame_limit]
        if args.capture_stage1:
            command.extend(['--resolution', '1920x1080', '--', '--capture-stage1'])
        elif args.performance and name == 'tutorial_stage1':
            command.extend(['--', '--check-performance'])
        elif name not in ['performance', 'v03_presentation', 'v03_render', 'bugfix']:
            command.insert(1, '--headless')
        start = time.monotonic()
        try:
            result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True, text=True, timeout=90)
            output = result.stdout + result.stderr
            error = bool(result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output or '\nFAIL ' in output or marker not in output)
            code = result.returncode
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b'').decode() if isinstance(exc.stdout, bytes) else (exc.stdout or '')
            output += '\nTEST TIMEOUT: stopped current Godot process; no further tests started.\n'
            error, code = True, None
        (log_dir/f'{name}.log').write_text(output)
        print(output, end='', flush=True)
        results.append({'test': name, 'passed': not error, 'exit_code': code, 'seconds': round(time.monotonic()-start, 3), 'log': f'artifacts/v03/logs/{name}.log'})
        if error:
            break
finally:
    temporary_project.cleanup()
    shutil.rmtree(test_user_dir, ignore_errors=True)
    summary = {'godot': version, 'workers': 1, 'candidate_version': 'stage1', 'user_data_isolated': True, 'legacy_sprite_pngs_present': False, 'results': results, 'not_run': ['T2 threads=4', 'T2 threads=8', 'T10 new-player study'], 'passed_executed_tests': bool(results) and all(r['passed'] for r in results), 'requested_test_count': len(tests), 'completed_test_count': len(results)}
    suffix = args.only or ('captures' if args.capture_stage1 else 'record-tutorial' if args.record_tutorial else '')
    (log_dir/('test-summary-'+suffix+'.json' if suffix else 'test-summary.json')).write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n')
print(f"Executed {len(results)}/{len(tests)} test scripts; passed={summary['passed_executed_tests']}; T2 threads 4/8 NOT RUN.", flush=True)
raise SystemExit(0 if len(results) == len(tests) and summary['passed_executed_tests'] else 1)
