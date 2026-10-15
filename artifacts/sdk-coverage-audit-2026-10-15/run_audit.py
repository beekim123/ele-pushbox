"""Run the read-only level audit in an isolated Godot project, with one worker."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[1]
GODOT = Path('/Users/key_/Desktop/CURRGO/ele-proj/zips/Godot.app/Contents/MacOS/Godot')
inputs = list((ROOT/'pushbox').rglob('*.gd')) + list((ROOT/'pushbox').rglob('*.json'))
inputs += list((ROOT/'bin').glob('*')) + [ROOT/'project.godot', ROOT/'ele.gdextension']
hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs if p.is_file()}
(EVIDENCE/'input-hashes.json').write_text(json.dumps(hashes, indent=2)+'\n')
environment = dict(os.environ)
for variable in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS']:
    environment[variable] = '1'
with tempfile.TemporaryDirectory(prefix='pushbox-sdk-audit-',dir='/private/tmp') as directory:
    project = Path(directory)
    for name in ['pushbox','bin','ele.gdextension']:
        (project/name).symlink_to(ROOT/name)
    (project/'evidence').symlink_to(EVIDENCE)
    (project/'audit.gd').symlink_to(EVIDENCE/'audit.gd')
    user_dir = Path.home()/'Library/Application Support/CodexPushboxAudit'/project.name
    config = (ROOT/'project.godot').read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CodexPushboxAudit/'+project.name+'"')
    (project/'project.godot').write_text(config)
    (project/'.godot').mkdir()
    (project/'.godot/extension_list.cfg').write_text('res://ele.gdextension\n')
    environment['PUSHBOX_AUDIT_USER_DIR'] = str(user_dir)
    try:
        with (EVIDENCE/'runtime.log').open('w') as log:
            completed = subprocess.run([str(GODOT),'--headless','--single-threaded-scene','--path',str(project),'--script','audit.gd'],env=environment,stdout=log,stderr=subprocess.STDOUT,timeout=120)
        unchanged = all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest() == digest for p,digest in hashes.items())
        log_text = (EVIDENCE/'runtime.log').read_text()
        valid = completed.returncode == 0 and unchanged and 'AUDIT COMPLETE levels=36 failures=[]' in log_text and 'SCRIPT ERROR:' not in log_text
        (EVIDENCE/'verification.json').write_text(json.dumps({'passed':valid,'exit_code':completed.returncode,'production_inputs_unchanged':unchanged,'workers':1},indent=2)+'\n')
        print(log_text)
        print('VERIFIED', valid, 'production_inputs_unchanged', unchanged)
    finally:
        shutil.rmtree(user_dir,ignore_errors=True)
raise SystemExit(0 if valid else 1)
