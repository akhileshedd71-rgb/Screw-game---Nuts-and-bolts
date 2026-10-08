#!/usr/bin/env python3
"""Negative controls ensure the geometric acceptance gate rejects real defects."""
import copy
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from validate_geometry import validate

root = Path(__file__).resolve().parents[1]
levels = json.loads((root / 'content/levels/campaign.json').read_text())
assert not validate(levels[7])
cases = []

bad = copy.deepcopy(levels[7])
bad['screws'][0]['position'] = [5, 5]
cases.append((bad, 'target outside safe board bounds'))

bad = copy.deepcopy(levels[7])
covered = next(s for s in bad['screws'] if s['blocker_plate_ids'])
covered['blocker_plate_ids'] = []
cases.append((bad, 'visual blockers differ from logical blockers'))

bad = copy.deepcopy(levels[0])
bad['screws'][1]['position'] = bad['screws'][0]['position'][:]
cases.append((bad, 'potentially concurrent targets are under 58px apart'))

bad = copy.deepcopy(levels[0])
bad['screws'][0]['color_id'] = 'teal'
cases.append((bad, 'color quota mismatch'))

for definition, message in cases:
    errors = validate(definition)
    assert any(message in error for error in errors), (message, errors)
print(f'GEOMETRY NEGATIVE CONTROLS PASS: {len(cases)} intentional defects rejected')
