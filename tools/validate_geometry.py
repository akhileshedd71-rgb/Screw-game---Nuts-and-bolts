#!/usr/bin/env python3
"""Check the finite campaign's authored geometry and inventories.

This is a geometry/data check, not a replacement for production Godot replay,
visual inspection, or phone playtesting. No third-party packages are required.
"""
from __future__ import annotations
import collections
import hashlib
import json
import math
from pathlib import Path
from generate_campaign import ROOT, COLORS, inside, edge_distance


def validate(level):
    errors=[]
    def require(condition,message):
        if not condition:errors.append(message)
    lid=level['level_id'];plates={p['id']:p for p in level['plates']};screws={s['id']:s for s in level['screws']}
    require(len(plates)==len(level['plates']),'duplicate plate IDs')
    require(len(screws)==len(level['screws']),'duplicate screw IDs')
    require(collections.Counter(s['color_id'] for s in screws.values())==collections.Counter(c for b in level['boxes_in_activation_order'] for c in [b['color_id']]*3),'color quota mismatch')
    owned=[s for p in plates.values() for s in p['screw_ids']]
    require(collections.Counter(owned)==collections.Counter(screws.keys()),'ownership is not exactly once')
    require(len(level['reference_solution'])==len(screws) and set(level['reference_solution'])==set(screws),'reference solution must include each screw exactly once')
    for p in plates.values():
        poly=p['polygon']
        require(len(poly)>=3,f'{p["id"]}: invalid polygon')
        require(all(0<=x<=640 and 0<=y<=600 for x,y in poly),f'{p["id"]}: plate outside board')
        for sid in p['screw_ids']:require(sid in screws and screws[sid]['plate_id']==p['id'],f'{p["id"]}: ownership disagreement')
    for s in screws.values():
        pos=s['position'];owner=plates[s['plate_id']]
        require(40<=pos[0]<=600 and 40<=pos[1]<=560,f'{s["id"]}: target outside safe board bounds')
        require(inside(pos,owner['polygon']) and edge_distance(pos,owner['polygon'])>=27.9,f'{s["id"]}: head not contained by owner with 28px margin')
        visual=[]
        for p in plates.values():
            if p['id']==owner['id'] or p['layer']<owner['layer']:continue
            within=inside(pos,p['polygon']);distance=edge_distance(pos,p['polygon'])
            if p['layer']==owner['layer']:
                require(not within and distance>=25,f'{s["id"]}: same-layer plate {p["id"]} intersects head')
            elif within:
                require(distance>=27.9,f'{s["id"]}: partial cover by {p["id"]}')
                visual.append(p['id'])
            else:require(distance>=25,f'{s["id"]}: partially obscured by {p["id"]}')
        require(set(visual)==set(s['blocker_plate_ids']),f'{s["id"]}: visual blockers differ from logical blockers')
    values=list(screws.values())
    for i,a in enumerate(values):
        for b in values[i+1:]:
            # A screw and a screw on a plate blocking it can never be exposed
            # simultaneously. Every other pair gets a conservative spacing check.
            mutually_excluded=a['plate_id'] in b['blocker_plate_ids'] or b['plate_id'] in a['blocker_plate_ids']
            if not mutually_excluded:
                require(math.dist(a['position'],b['position'])>=57.99,f'{a["id"]}/{b["id"]}: potentially concurrent targets are under 58px apart')
    # Geometric release sequence only; routing and wins belong to Godot tests.
    left=set(screws);cleared=set()
    for sid in level['reference_solution']:
        s=screws[sid]
        require(set(s['blocker_plate_ids'])<=cleared,f'witness removes hidden target {sid}')
        left.remove(sid)
        cleared.update(pid for pid,p in plates.items() if not set(p['screw_ids'])&left)
    expected_hash=level['content_hash'];original={k:v for k,v in level.items() if k!='content_hash'}
    require(hashlib.sha256(json.dumps(original,sort_keys=True,separators=(',',':')).encode()).hexdigest()==expected_hash,'content hash mismatch')
    return [f'{lid}: {e}' for e in errors]


def topology_key(level):
    # Isomorphism is not claimed: descriptors discard plate IDs, spatial layout,
    # color labels and screw order, grouping equivalent independent stacks.
    groups=[]
    for p in level['plates']:
        ss=[s for s in level['screws'] if s['plate_id']==p['id']]
        groups.append((p['layer'],len(ss),tuple(sorted(len(s['blocker_plate_ids']) for s in ss))))
    return str(sorted(groups))


def main():
    levels=json.loads((ROOT/'content/levels/campaign.json').read_text())
    errors=[]
    if len(levels)!=1000:errors.append(f'Expected 1000 levels, found {len(levels)}')
    if len({l['level_id'] for l in levels})!=len(levels):errors.append('Duplicate stable level IDs')
    briefs=json.loads((ROOT/'docs/reference/level_briefs.json').read_text())['levels']
    for index,level in enumerate(levels,1):
        if level['index']!=index or level['level_id']!=f'campaign_{index:04}':errors.append(f'Unstable index {index}')
        errors.extend(validate(level))
        if index<=30:
            actual=collections.Counter(s['color_id'] for s in level['screws'])
            expected=collections.Counter({c:n for c,n in briefs[index-1]['screw_count_by_color'].items() if n})
            if actual!=expected:errors.append(f'Level {index}: source brief inventory changed')
    hashes=[l['content_hash'] for l in levels]
    report={
        'schema_version':1,
        'geometry_validation':'PASS' if not errors else 'FAIL',
        'level_count':len(levels),
        'screw_count':sum(len(l['screws']) for l in levels),
        'unique_content_hashes':len(set(hashes)),
        'topology_descriptor_count':len({topology_key(l) for l in levels}),
        'family_counts':dict(sorted(collections.Counter(l['family'] for l in levels).items())),
        'screw_count_distribution':dict(sorted(collections.Counter(len(l['screws']) for l in levels).items())),
        'layer_count_distribution':dict(sorted(collections.Counter(max(p['layer'] for p in l['plates'])+1 for l in levels).items())),
        'witness_peak_buffer_distribution':dict(sorted(collections.Counter(l['witness_peak_buffer'] for l in levels).items())),
        'first_30_exact_color_inventories':not any('inventory changed' in e for e in errors),
        'fixture_L08_preserves_abstract_graph':levels[7].get('source_fixture')=='two_green_caps_12',
        'guarantees':['finite fixed queues','stable IDs and content hashes','all screw ownership and color quotas','heads fit owners by >=28 logical pixels','all visual covers agree with declared blockers','no partly obscured exposed heads','potentially concurrent head centers >=58 logical pixels','witness removes geometrically exposed screws only'],
        'separate_required_checks':['Godot reducer witness replay (tests/test_reducer.gd)','human playtesting','physical Android touch and readability'],
        'human_playtest_verified':False,
        'errors':errors,
    }
    path=ROOT/'docs/LEVEL_VALIDATION.json';path.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ['guarantees','separate_required_checks']},indent=2))
    raise SystemExit(bool(errors))

if __name__=='__main__':main()
