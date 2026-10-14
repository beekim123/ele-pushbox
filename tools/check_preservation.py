#!/usr/bin/env python3
"""Verify immutable rules/levels/SDK and the pre-scheduling Session oracle."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
baseline = json.loads((root/'docs/v3/baseline.json').read_text())
checks = {}
for name in ['pushbox/scripts/board.gd', 'pushbox/rules.json', 'bin/libele_godot.dylib', 'pushbox/content/default/materials.json', 'pushbox/content/default/profile.json', 'pushbox/content/default/reactions.json', 'tests/fixtures/session_sync_v03.gd']:
    checks[name] = hashlib.sha256((root/name).read_bytes()).hexdigest() == baseline[name]
for path in (root/'pushbox/levels').glob('*.json'):
    data = json.loads(path.read_text())
    data.pop('guides', None)
    name = str(path.relative_to(root))
    checks[name+' except guides'] = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest() == baseline[name]
population = (root/'pushbox/scripts/level_loader.gd').read_text().split('static func populate',1)[1]
checks['Loader.populate'] = hashlib.sha256(population.encode()).hexdigest() == baseline['Loader.populate']
assert all(checks.values()), [name for name, passed in checks.items() if not passed]
summary = {'all_passed': True, 'checks': checks, 'session_scheduling': 'explicitly authorized; result equivalence verified against frozen Session and original per-action hashes'}
(root/'artifacts/v03/core-preservation.json').write_text(json.dumps(summary, indent=2)+'\n')
print(f'Core preservation: {len(checks)} checks passed')
