"""Create, execute, visually review and retain up to eleven scoped deer edits."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/deer_eleven_01'
SOURCE=ROOT/'blender/deer_from_scratch_working.blend'
BLENDER=Path('C:/Program Files/Blender Foundation/Blender 5.2/blender.exe')
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def write(p,x):Path(p).write_text(json.dumps(x,indent=2,sort_keys=True),encoding='utf-8')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def plans():
    body='Buck anatomy'; eyes=['Eye -1','Eye 1']; mouths=['Seated mouth crease -1','Seated mouth crease 1']
    hooves=[f'{leg} hoof {side} {toe}' for leg in ('Fore','Hind') for side in (-1,1) for toe in (-1,1)]
    return [
        dict(operation='eyes',region='face',objects=eyes,color_objects=eyes,hypothesis='Replace flattened slanted eye patches with seated convex eyes and a readable iris.'),
        dict(operation='muzzle',region='face',objects=[body,'Nose',*mouths],body_box=[[-.3,.82,1.43],[.3,1.2,1.70]],hypothesis='Broaden the pointed muzzle and lift its lip plane slightly while retaining the recessed nostrils.'),
        dict(operation='ears',region='ears',objects=[body,'Ear inner -1','Ear inner 1'],body_box=[[-.5,.42,1.78],[.5,.74,2.04]],hypothesis='Give thin ear blades a fuller leaf section and a visible curved cup.'),
        dict(operation='neck',region='neck',objects=[body],body_box=[[-.4,.20,1.12],[.4,.88,1.61]],hypothesis='Add a restrained neck-root transition to reduce the straight tapered tube.'),
        dict(operation='chest',region='torso',objects=[body],body_box=[[-.4,-.5,.68],[.4,.57,1.18]],hypothesis='Tuck the heavy lower barrel while preserving a broader forechest.'),
        dict(operation='croup',region='hindquarters',objects=[body,'Black tail'],body_box=[[-.4,-.8,.88],[.4,-.10,1.45]],hypothesis='Round the flat croup slightly and narrow the hanging tail toward its tip.'),
        dict(operation='forelegs',region='forelegs',objects=[body],body_box=[[-.4,.22,.12],[.4,.66,.72]],hypothesis='Differentiate knees and cannon segments while keeping all forefeet planted.'),
        dict(operation='hindlegs',region='hindlegs',objects=[body],body_box=[[-.4,-.85,.14],[.4,-.13,.78]],hypothesis='Soften the abrupt rear-leg kink and give the distal hind limbs more section.'),
        dict(operation='hooves',region='feet',objects=[body,*hooves],body_box=[[-.5,-1,0],[.5,1,.18]],hypothesis='Slope hoof walls and their pastern connection without moving the ground-contact vertices.'),
        dict(operation='antlers',region='antlers',objects=['Buck antler -1','Buck antler 1'],color_objects=['Buck antler -1','Buck antler 1'],hypothesis='Spread upper branches modestly and introduce darker bases with lighter tips.'),
        dict(operation='coat',region='coat',objects=[],color_objects=[body,'Ear inner -1','Ear inner 1'],material_names=['Buck coat.002'],hypothesis='Replace flat tan with restrained tawny/dorsal variation, eye surrounds, and directional microtexture; no fur or quality approval claim.')]

def init():
    OUT.mkdir(parents=True,exist_ok=False)
    manifest=read(ROOT/'characters/deer/gauntlet_from_scratch.json')
    reference=ROOT/manifest['references']['front']['path']
    retained=ROOT/'artifacts/gauntlet/deer_from_scratch/20260910-175537-7ba9a5/candidates/ff3c4925c882/candidate.blend'
    assert sha(SOURCE)==sha(retained)
    protocol={'source':str(SOURCE),'source_sha256':sha(SOURCE),'reference_sha256':sha(reference),
              'manifest':manifest,'max_new_candidates':11,'plans':plans(),
              'purpose':'Exploratory continuation of retained deer, explicitly authorized by user. Existing exhausted runs and source assets remain untouched.',
              'acceptance':'Exact protected vertices/data, unchanged topology and static rig status, no structural/budget errors, saved-scene verification; coordinator compares each candidate with its parent and reference before retention. No automatic acceptance from mechanical pass.',
              'stopping':'At most 11 new candidates. Two consecutive unsuccessful candidates stop that anatomical region; no resetting or third attempt in the stopped region. Execution errors are preserved. No quality, 8/10, deformation, delivery or credit claim.',
              'rendering':'Fixed existing 640px five-camera protocol; four silhouette views. Baseline is rerendered under the same configuration.',
              'auditor_correction_qualification':str(ROOT/'artifacts/routing_economics_03_corrected/summary.json')}
    write(OUT/'protocol.json',protocol)
    write(OUT/'state.json',{'best':0,'attempts':0,'pending':None,'decisions':[],'region_failures':{}})
    return execute(0)

def board(folder):
    views=['front','side','back','three_quarter','head_detail'];canvas=Image.new('RGB',(1600,340),(230,228,222));draw=ImageDraw.Draw(canvas)
    for i,v in enumerate(views):
        im=Image.open(folder/'renders'/f'{v}.png').convert('RGBA');im.thumbnail((320,320))
        canvas.paste(im,(i*320,20),im);draw.text((i*320+8,4),v,fill='black')
    canvas.save(folder/'contact.png')

def execute(number):
    protocol=read(OUT/'protocol.json');state=read(OUT/'state.json')
    assert sha(SOURCE)==protocol['source_sha256']
    assert state['pending'] is None
    if number:
        assert number==state['attempts']+1 and number<=11
        plan=protocol['plans'][number-1]
        amendment=OUT/f'plan_amendment_{number:02d}.json'
        if amendment.exists():
            change=read(amendment)
            assert change['original_plan']==plan and change['reason']
            assert change['replacement_plan']['region']==plan['region'], 'Amendment cannot rename region to reset failures'
            plan=change['replacement_plan']
        assert state['region_failures'].get(plan['region'],0)<2, 'Region stopped'
        source=OUT/f'pass_{state["best"]:02d}'/'candidate.blend'
        state['attempts']=number;state['pending']=number;write(OUT/'state.json',state)
    else:plan={'operation':'baseline','objects':[]};source=SOURCE
    output=OUT/f'pass_{number:02d}'
    job={'root':str(ROOT),'input':str(source),'output':str(output),'manifest':protocol['manifest'],'plan':plan}
    write(OUT/f'job_{number:02d}.json',job)
    snapshot=OUT/f'worker_{number:02d}.py';shutil.copy2(Path(__file__).with_name('worker.py'),snapshot)
    start=time.perf_counter()
    with (OUT/f'pass_{number:02d}.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([str(BLENDER),'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(snapshot),'--',str(OUT/f'job_{number:02d}.json')],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600)
    write(OUT/f'timing_{number:02d}.json',{'exit_code':result.returncode,'wall_seconds':time.perf_counter()-start})
    if result.returncode:raise RuntimeError(f'Worker failed, preserved {output}')
    board(output)
    print(json.dumps({'pass':number,'contact':str(output/'contact.png'),'scene':str(output/'candidate.blend')},indent=2))

def decide(accept,reason):
    state=read(OUT/'state.json');n=state['pending'];assert n is not None
    plan=read(OUT/'protocol.json')['plans'][n-1];complete=(OUT/f'pass_{n:02d}'/'complete.json').exists()
    assert not accept or complete, 'Cannot retain incomplete evidence'
    record={'pass':n,'retained':accept,'reason':reason,'region':plan['region'],'parent':state['best'],'mechanically_complete':complete}
    state['decisions'].append(record)
    state['region_failures'][plan['region']]=0 if accept else state['region_failures'].get(plan['region'],0)+1
    if accept:state['best']=n
    state['pending']=None;write(OUT/'state.json',state);print(json.dumps(record))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['init','run','accept','reject']);p.add_argument('value',nargs='?');a=p.parse_args()
    if a.action=='init':init()
    elif a.action=='run':execute(int(a.value))
    else:decide(a.action=='accept',a.value)
