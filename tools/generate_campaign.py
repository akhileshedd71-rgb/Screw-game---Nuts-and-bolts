#!/usr/bin/env python3
"""Build the finite Screwcraft campaign from constrained deterministic templates.

Not a runtime randomizer. Every output includes complete geometry, a fixed queue
and a winning witness. Python construction checks are complemented by the actual
Godot reducer replay in tests/test_campaign.gd. Human/mobile playtests are separate.
"""
from __future__ import annotations
import collections
import hashlib
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COLORS = ['red', 'blue', 'green', 'yellow', 'purple', 'teal']
FAMILIES = ['flower', 'sailboat', 'bird', 'windmill', 'butterfly', 'house', 'lantern', 'signpost', 'star', 'tree', 'fish', 'keepsake']
FAMILY_NAMES = ['Petal studio', 'Little harbor', 'Feather collection', 'Wind garden', 'Butterfly meadow', 'Cozy village', 'Lantern night', 'Woodland trail', 'Starlight workshop', 'Orchard morning', 'Coral cove', 'Keepsake shelf']
RHYTHM = ['warm-up', 'practice', 'variation', 'challenge', 'recovery']

def point(cx, cy, x, y, rotation=0):
    a = math.radians(rotation)
    return [round(cx + x*math.cos(a)-y*math.sin(a), 3), round(cy+x*math.sin(a)+y*math.cos(a), 3)]

def plank(cx, cy, half_length=111, half_width=43, rotation=0, bevel=16):
    return [point(cx,cy,x,y,rotation) for x,y in [(-half_length+bevel,-half_width),(half_length-bevel,-half_width),(half_length,-half_width+bevel),(half_length,half_width-bevel),(half_length-bevel,half_width),(-half_length+bevel,half_width),(-half_length,half_width-bevel),(-half_length,-half_width+bevel)]]

def disc(cx,cy,r=43):
    return [[round(cx+math.cos(i*math.tau/16)*r,3),round(cy+math.sin(i*math.tau/16)*r,3)] for i in range(16)]

def inside(p, poly):
    x,y=p; hit=False
    for a,b in zip(poly, poly[1:]+poly[:1]):
        if (a[1]>y)!=(b[1]>y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]: hit=not hit
    return hit

def edge_distance(p,poly):
    def d(a,b):
        vx,vy=b[0]-a[0],b[1]-a[1]; wx,wy=p[0]-a[0],p[1]-a[1]
        t=max(0,min(1,(vx*wx+vy*wy)/(vx*vx+vy*vy)))
        return math.hypot(p[0]-a[0]-t*vx,p[1]-a[1]-t*vy)
    return min(d(a,b) for a,b in zip(poly,poly[1:]+poly[:1]))

def derive_blockers(level):
    owners={p['id']:p for p in level['plates']}
    for screw in level['screws']:
        owner=owners[screw['plate_id']]
        assert inside(screw['position'], owner['polygon']) and edge_distance(screw['position'],owner['polygon'])>=27.9, (level['index'],screw,'outside owner')
        blockers=[]
        for plate in level['plates']:
            if plate['id']==owner['id'] or plate['layer']<=owner['layer']:continue
            is_inside=inside(screw['position'],plate['polygon'])
            distance=edge_distance(screw['position'],plate['polygon'])
            if is_inside:
                assert distance>=27.9,(level['index'],screw['id'],plate['id'],'partial inside',distance)
                blockers.append(plate['id'])
            else:
                assert distance>=25.0,(level['index'],screw['id'],plate['id'],'partial outside',distance)
        screw['blocker_plate_ids']=blockers

def layouts(count, family, rng):
    # Nonintersecting footprints; varied craft arrangements share the same clear
    # touch-target contract. Nested layers reveal progressively inset pieces.
    if count==1:return [(320,300,0)]
    if count==2:return [(320,202,-8),(320,398,8)]
    if count==3:
        variants=[[(175,175,-20),(465,175,20),(320,420,0)],[(170,200,75),(470,200,-75),(320,435,0)],[(170,155,0),(465,300,90),(230,455,0)]]
        return variants[rng.randrange(len(variants))]
    if count==4:
        variants=[[(320,135,0),(485,300,90),(320,465,0),(155,300,90)],[(180,170,-15),(460,170,15),(180,430,15),(460,430,-15)],[(180,160,15),(465,215,-65),(175,415,65),(430,460,-15)]]
        return variants[rng.randrange(len(variants))]
    if count==5:
        return [(320+183*math.cos(a),300+183*math.sin(a),math.degrees(a)+90) for a in [-math.pi/2+i*math.tau/5 for i in range(5)]]
    return [(130+190*(i%3),175+250*(i//3),90) for i in range(count)]

def add_plate(level,pid,layer,poly,positions,material=0,rotation=0):
    ids=[]
    for pos in positions:
        sid=f's{len(level["screws"])+1:02}'
        ids.append(sid)
        level['screws'].append({'id':sid,'color_id':'red','plate_id':pid,'blocker_plate_ids':[],'position':pos})
    level['plates'].append({'id':pid,'layer':layer,'screw_ids':ids,'polygon':poly,'material':material,'position':[round(sum(p[0] for p in poly)/len(poly),3),round(sum(p[1] for p in poly)/len(poly),3)],'rotation':rotation})
    return ids

def distribute(total,count,rng,maximum):
    out=[1]*count
    while sum(out)<total:
        i=rng.choice([i for i,v in enumerate(out) if v<maximum]);out[i]+=1
    return out

def generic_geometry(level, screw_count, plate_count, layers,rng):
    stack_count=max(math.ceil(plate_count/layers),min(5,plate_count//2))
    stack_count=min(stack_count,plate_count,6)
    depths=distribute(plate_count,stack_count,rng,layers)
    counts=distribute(screw_count,plate_count,rng,3)
    locs=layouts(stack_count,level['family'],rng)
    for k,depth in enumerate(depths):
        cx,cy,rotation=locs[k]
        for layer in range(depth):
            inset=(depth-layer-1)*3
            count=counts.pop()
            offsets={1:[0],2:[-52,52],3:[-72,0,72]}[count]
            add_plate(level,f'p{len(level["plates"])+1:02}',layer,plank(cx,cy,111+inset,43+inset,rotation),[point(cx,cy,x,0,rotation) for x in offsets],(k+layer+level['index'])%4,rotation)
    derive_blockers(level)

def topological_route(level,rng):
    remaining={s['id'] for s in level['screws']};cleared=set();out=[]
    while remaining:
        available=[s for s in level['screws'] if s['id'] in remaining and all(b in cleared for b in s['blocker_plate_ids'])]
        assert available
        choice=rng.choice(available)
        if len(out) and rng.random()<0.42:
            previous=next(s for s in level['screws'] if s['id']==out[-1])
            same=[s for s in available if s['plate_id']==previous['plate_id']]
            if same:choice=rng.choice(same)
        out.append(choice['id']);remaining.remove(choice['id'])
        for p in level['plates']:
            if not any(s in remaining for s in p['screw_ids']):cleared.add(p['id'])
    return out

def color_route(queue,rng,pressure):
    """Conservation-aware constructive route, tracking FIFO transfers exactly."""
    remaining=collections.Counter(c for c in queue for _ in range(3))
    active=[{'color':c,'count':0,'index':i} for i,c in enumerate(queue[:2])]
    cursor=len(active);buffer=[];sequence=[];peak=0
    def settle():
        nonlocal cursor
        while True:
            changed=False
            for slot in range(len(active)):
                if active[slot] is not None and active[slot]['count']==3:
                    active[slot]={'color':queue[cursor],'count':0,'index':cursor} if cursor<len(queue) else None
                    if cursor<len(queue):cursor+=1
                    changed=True
            for i,c in enumerate(buffer):
                matches=[b for b in active if b is not None and b['color']==c]
                if matches:
                    min(matches,key=lambda b:b['index'])['count']+=1
                    buffer.pop(i);changed=True;break
            if not changed:break
    while sum(remaining.values()):
        active_colors={b['color'] for b in active if b is not None}
        direct=[c for c in COLORS if remaining[c] and c in active_colors]
        future=[c for c in COLORS if remaining[c] and c not in active_colors]
        use_buffer=future and len(buffer)<pressure and (not direct or rng.random()<0.53)
        if use_buffer:
            upcoming=[c for c in queue[cursor:cursor+3] if c in future]
            c=rng.choice(upcoming or future);buffer.append(c)
        else:
            assert direct, ('construction invariant', queue, remaining, active, buffer)
            c=rng.choice(direct)
            min((b for b in active if b is not None and b['color']==c),key=lambda b:b['index'])['count']+=1
        sequence.append(c);remaining[c]-=1;settle();peak=max(peak,len(buffer))
    assert not buffer and not any(active)
    return sequence,peak

def base_level(index, family,name,difficulty,lesson):
    return {'schema_version':1,'level_id':f'campaign_{index:04}','index':index,'name':name,'family':family,'chapter':(index-1)//5+1,'difficulty':difficulty,'revision':1,'ruleset_id':'classic_sort_v1','board_reference_size':[640,600],'boxes_in_activation_order':[],'plates':[],'screws':[],'reference_solution':[],'tutorial_tags':[],'lesson':lesson,'authoring':{'method':'deterministic_constrained_templates','human_playtest_verified':False,'phone_readability_verified':False,'generator_version':1}}

def fixture_level(level):
    source=json.loads((ROOT/'docs/reference/fixture_12_screws.json').read_text())
    level['boxes_in_activation_order']=source['boxes_in_activation_order']
    level['plates']=source['plates'];level['screws']=source['screws']
    positions={'B1':[180,300],'B2':[320,380],'B3':[460,220],'R1':[160,300],'R2':[320,300],'R3':[480,300],'G1':[320,300],'G2':[480,300],'G3':[110,125],'Y1':[280,125],'Y2':[380,125],'Y3':[480,125]}
    polys={'blue_plate':plank(315,300,260,142),'red_plate':plank(315,300,245,112),'green_cap_a':disc(320,300),'green_cap_b':disc(480,300),'green_spare':disc(110,125),'yellow_plate':plank(380,125,150,43)}
    for i,p in enumerate(level['plates']):p.update(polygon=polys[p['id']],material=i%4,position=[0,0],rotation=0)
    expected={s['id']:s['blocker_plate_ids'][:] for s in level['screws']}
    for s in level['screws']:s['position']=positions[s['id']]
    derive_blockers(level)
    for s in level['screws']:assert set(s['blocker_plate_ids'])==set(expected[s['id']]),s
    level['reference_solution']=source['traces']['straightforward']['actions']
    level['witness_peak_buffer']=2
    level['tutorial_tags']=['undo','full_buffer_direct_match']
    level['authoring']['method']='supplied_abstract_fixture_with_original_geometry'
    level['source_fixture']='two_green_caps_12'
    return level

def onboarding(level,index):
    if index==1:
        red=add_plate(level,'p01',0,plank(320,205,155,49),[[220,205],[320,205],[420,205]],0)
        blue=add_plate(level,'p02',0,plank(320,395,155,49),[[220,395],[320,395],[420,395]],1)
        colors=['red']*3+['blue']*3;route=red+blue
    elif index==2:
        blue=add_plate(level,'p01',0,plank(320,300,185,82,-12),[point(320,300,x,0,-12) for x in [-100,0,100]],1,-12)
        red=add_plate(level,'p02',1,plank(320,300,178,68,-12),[point(320,300,x,0,-12) for x in [-100,0,100]],0,-12)
        colors=['red']*3+['blue']*3;route=red+blue
    else:
        red=add_plate(level,'p01',0,plank(320,325),[[248,325],[320,325],[392,325]],0)
        blue=add_plate(level,'p02',0,plank(320,165),[[248,165],[320,165],[392,165]],1)
        green=add_plate(level,'p03',0,plank(320,475,100,43),[[268,475],[372,475]],2)
        cap=add_plate(level,'p04',1,disc(392,325),[[392,325]],2)
        route=red[:2]+cap+red[2:]+green+blue
        colors=['red','red','green','red','green','green','blue','blue','blue']
    colors_by_id=dict(zip(route,colors))
    for s in level['screws']:s['color_id']=colors_by_id[s['id']]
    derive_blockers(level);level['reference_solution']=route;level['witness_peak_buffer']=int(index==3)
    level['tutorial_tags']={1:['match_three'],2:['layers'],3:['buffer','automatic_transfer']}[index]
    level['authoring']['method']='original_tutorial_template'
    return level

def build(index,briefs):
    rng=random.Random(0x5C4E0000+index*7919)
    family=FAMILIES[((index-1)//5)%len(FAMILIES)]
    rhythm=RHYTHM[(index-1)%5]
    if index<=30:
        b=briefs[index-1];box_counts=b['box_count_by_color'];screw_count=b['total_screws'];plate_count=b['plate_count_target'];layers=b['logical_layer_count_target']
        name=b['working_title'];lesson=b['primary_learning_or_design_objective'];pressure=b['winning_reference_path_peak_buffer_target_at_most']
        queue=[c for c in COLORS if box_counts[c]]
        remaining=[c for c in COLORS for _ in range(max(0,box_counts[c]-1))]
        rng.shuffle(remaining);queue+=remaining
        family={1:'signpost',2:'keepsake',3:'house',4:'sailboat',5:'signpost',6:'windmill',7:'flower',8:'keepsake',10:'keepsake'}.get(index,family)
    else:
        era=min(4,(index-31)//180)
        boxes=([4,5,6,7,5][(index-1)%5]+era//2+rng.randrange(2))
        color_count=min(6,4+era//2)
        colors=COLORS[:color_count];rng.shuffle(colors)
        queue=(colors+[rng.choice(colors) for _ in range(boxes)])[:boxes]
        # Repeat colors can be concurrently active. Each finite queue is fixed.
        if index%7==0 and len(queue)>4:queue[2],queue[3]=queue[3],queue[2]
        screw_count=boxes*3;plate_count=math.ceil(screw_count/3)+rng.randrange(1,3)
        layers=2 if rhythm in ['warm-up','recovery'] else 3+(era>=2 and rhythm=='challenge')
        plate_count=min(plate_count,12,layers*6)
        pressure={'warm-up':1,'practice':2,'variation':3,'challenge':4,'recovery':2}[rhythm]
        title=FAMILY_NAMES[FAMILIES.index(family)]
        name=f'{title} {((index-1)//60)+1}'
        lesson={'warm-up':'Follow the visible colors and reveal the next layer.','practice':'Reserve a buffer space for the cap covering a useful color.','variation':'Read the upcoming orders before choosing between branches.','challenge':'Inspect covered colors and plan the order of plate releases.','recovery':'Enjoy a clear route and satisfying automatic transfers.'}[rhythm]
    level=base_level(index,family,name,rhythm,lesson)
    level['boxes_in_activation_order']=[{'id':f'box_{i+1:02}_{c}','color_id':c} for i,c in enumerate(queue)]
    if index==8:level=fixture_level(level)
    elif index<=3:level=onboarding(level,index)
    else:
        generic_geometry(level,screw_count,plate_count,layers,rng)
        route=topological_route(level,rng)
        colors,peak=color_route(queue,rng,pressure)
        assignments=dict(zip(route,colors))
        for s in level['screws']:s['color_id']=assignments[s['id']]
        level['reference_solution']=route;level['witness_peak_buffer']=peak
        if index==4:level['tutorial_tags']=['automatic_transfer']
        if index==5:level['tutorial_tags']=['queue']
        if index==7:level['tutorial_tags']=['blueprint']
        if index==9:level['tutorial_tags']=['repeated_orders']
        if index==14:level['tutorial_tags']=['purple']
        if index==23:level['tutorial_tags']=['teal']
    if index<=30:
        level['source_brief']=f'L{index:02}'
        level['authoring']['brief_inventory_exact']=True
    level['authoring']['seed']=0x5C4E0000+index*7919
    level['content_hash']=hashlib.sha256(json.dumps(level,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    return level

def main():
    briefs=json.loads((ROOT/'docs/reference/level_briefs.json').read_text())['levels']
    levels=[build(i,briefs) for i in range(1,1001)]
    target=ROOT/'content/levels/campaign.json';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(levels,separators=(',',':'))+'\n')
    art={'schema_version':1,'board_reference_size':[640,600],'materials':['beech','honey','walnut','ivory'],'families':[{'id':f,'title':n,'album_group_size':5} for f,n in zip(FAMILIES,FAMILY_NAMES)],'palette':{'red':'#DB6066','blue':'#568BD2','green':'#719A68','yellow':'#E4B544','purple':'#9D7AC2','teal':'#48A5A0'}}
    (ROOT/'content/art_catalog.json').write_text(json.dumps(art,indent=2)+'\n')
    print(f'Wrote {len(levels)} levels, {sum(len(l["screws"]) for l in levels)} screws; {target.stat().st_size:,} bytes.')

if __name__=='__main__':main()
