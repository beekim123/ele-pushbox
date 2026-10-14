#!/usr/bin/env python3
"""Install a complete author-verified recording set without changing old levels."""
import json
import argparse
from pathlib import Path
root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--artifact-dir', default='artifacts/stage2a')
args = parser.parse_args()
recordings = sorted((root/args.artifact_dir/'recorded').glob('*.json'))
assert len(recordings) == 36
for source in recordings:
    data = json.loads(source.read_text())
    assert data['solution'] and len(data['solution']) == len(data['solution_hashes']) == len(data['solution_keys'])
    theme = data['theme_id']
    index = int(data['campaign']['index'])
    destination = root/'pushbox/levels/campaign'/theme/f'c_{theme}_{index+1:02}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(source.read_text())
print('Installed 36 recorded campaign levels')
