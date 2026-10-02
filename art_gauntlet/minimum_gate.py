"""Minimum gate: isolated ID/matte, protected data, two-failure stop.

No art scoring, depth/position passes, rig posing or model calls.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image,ImageChops
from .runner import executable

ROOT=Path(__file__).resolve().parents[1]


def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def write(path,value):Path(path).write_text(json.dumps(value,indent=2,sort_keys=True),encoding='utf-8')
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def capture(config,source,out,operations=(),render=True):
    out=Path(out)
    if out.exists():raise ValueError(f'Refusing to overwrite evidence: {out}')
    out.mkdir(parents=True)
    write(out/'job.json',{'config':config,'source':str(source),'output':str(out),'operations':operations,'render':render})
    with (out/'blender.log').open('w') as log:
        subprocess.run([executable('blender'),'--background','--factory-startup','--disable-autoexec',
                        '--python-exit-code','1','--python',str(ROOT/'art_gauntlet/minimum_worker.py'),'--',str(out/'job.json')],
                       cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)


def pixel_difference(a,b):
    a=Image.open(a).convert('RGBA');b=Image.open(b).convert('RGBA')
    if a.size!=b.size:raise ValueError('Evidence dimensions changed')
    diff=ImageChops.difference(a,b)
    return {'max_channel_delta':max(high for low,high in diff.getextrema()),
            'changed_pixels':sum(any(p) for p in diff.get_flattened_data())}


def compare(config,baseline,candidate,render=True):
    baseline,candidate=Path(baseline),Path(candidate)
    a,b=read(baseline/'snapshot.json'),read(candidate/'snapshot.json')
    data={key:a[key]==b[key] for key in ['geometry','materials','transforms','rig']}
    images={}
    if render:
        for view in config['views']:
            for kind in ['id','matte']:
                name=f'{view}_{kind}.png'
                images[name]=pixel_difference(baseline/name,candidate/name)
    return {'passed':all(data.values()) and all(d['max_channel_delta']<=config['pixel_max_delta'] for d in images.values()),
            'data_unchanged':data,'images':images}


def reserve(state):
    if state['consecutive_failures']>=2:raise ValueError('Stopped after two consecutive failures; no third dispatch')
    state['dispatched']+=1


def record(state,passed):
    state['consecutive_failures']=0 if passed else state['consecutive_failures']+1
    state['stopped']=state['consecutive_failures']>=2


def move(vertices,delta):return [{'type':'move_vertices','vertices':vertices,'delta':delta}]


def attempt(config,run,name,operations,render=True,state_name='loop_state.json'):
    """Persist the streak and refuse work before invoking Blender on failure 3."""
    run=Path(run);path=run/state_name
    state=read(path) if path.exists() else {'consecutive_failures':0,'dispatched':0,'stopped':False}
    reserve(state);write(path,state)
    try:
        capture(config,run/'baseline/candidate.blend',run/name,operations,render)
        result=compare(config,run/'baseline',run/name,render)
    except Exception:
        record(state,False);write(path,state)
        raise
    record(state,result['passed']);write(path,state)
    write(run/name/'result.json',result)
    return result


def validate(config_path,run):
    config=read(config_path);run=Path(run).resolve()
    if run.exists():raise ValueError('Use a fresh validation output directory')
    run.mkdir(parents=True)
    source=Path(config['source'])
    if digest(source)!=config['source_sha256']:raise ValueError('Acquired source changed')
    write(run/'config.json',config)
    print('Capturing baseline and repeatability evidence',flush=True)
    capture(config,source,run/'baseline')
    baseline=run/'baseline/candidate.blend'
    capture(config,baseline,run/'repeat')
    repeated=compare(config,run/'baseline',run/'repeat')
    write(run/'repeat/result.json',repeated)
    if not repeated['passed']:raise ValueError('Baseline is not repeatable; inspect evidence before editing')
    print('Testing deliberate protected edit',flush=True)
    bad=attempt(config,run,'protected_failure',move([25],[.45,0,.25]))
    print('Testing permitted adjacent ear edit and changed shadow',flush=True)
    capture(config,baseline,run/'adjacent_success',move(config['editable_vertices'],[.35,.10,-.06]))
    good=compare(config,run/'baseline',run/'adjacent_success')
    shadow=pixel_difference(run/'baseline/shadow_witness.png',run/'adjacent_success/shadow_witness.png')
    good['shadow_witness_delta']=shadow
    good['beauty_delta']=pixel_difference(run/'baseline/beauty.png',run/'adjacent_success/beauty.png')
    write(run/'adjacent_success/result.json',good)
    # The source has real weights, materials and transforms: exercise their
    # data checks independently without paying for redundant renders.
    extra={}
    for name,ops in [('weight_failure',[{'type':'weight','group':'Head','vertex':110,'value':.2}]),
                     ('material_failure',[{'type':'material','value':.99}]),
                     ('transform_failure',[{'type':'transform','delta':.1}])]:
        if name=='weight_failure':extra[name]=attempt(config,run,name,ops,render=False)
        else:
            capture(config,baseline,run/name,ops,render=False)
            extra[name]=compare(config,run/'baseline',run/name,render=False)
        write(run/name/'result.json',extra[name])
    state=read(run/'loop_state.json')
    try:attempt(config,run,'forbidden_third',move(config['editable_vertices'],[.01,0,0]));blocked=False
    except ValueError:blocked=True
    stop={'blocked_third_dispatch':blocked,**state}
    passed=(repeated['passed'] and not bad['passed'] and not bad['data_unchanged']['geometry']
            and any(d['changed_pixels'] for d in bad['images'].values()) and good['passed']
            and shadow['changed_pixels']>0 and all(not r['passed'] for r in extra.values()) and blocked)
    result={'passed':passed,'repeat':repeated,'protected_failure':bad,'adjacent_success':good,
            'extra_data_tests':extra,'stop_rule':stop,'config_sha256':digest(run/'config.json'),
            'baseline_sha256':digest(baseline),'source_sha256':digest(source)}
    write(run/'validation.json',result)
    print(json.dumps(result,indent=2),flush=True)
    return result


def edit(run):
    run=Path(run).resolve();validation=read(run/'validation.json');config=read(run/'config.json')
    if not validation['passed']:raise ValueError('Step 3 must pass before the single regional edit')
    if digest(run/'config.json')!=validation['config_sha256'] or digest(run/'baseline/candidate.blend')!=validation['baseline_sha256']:
        raise ValueError('Validated protocol or baseline changed')
    out=run/'single_edit'
    if out.exists():raise ValueError('Single proof edit already dispatched')
    # Smaller than the stress fixture: a single 0.10-unit outward ear-tip move.
    result=attempt(config,run,'single_edit',move(config['editable_vertices'],[.10,0,0]),state_name='proof_loop_state.json')
    result['state']=read(run/'proof_loop_state.json')
    result['beauty_delta']=pixel_difference(run/'baseline/beauty.png',out/'beauty.png')
    result['edit']={'region':config['editable_region'],'vertices':config['editable_vertices'],'delta':[.10,0,0]}
    write(out/'result.json',result)
    print(json.dumps(result,indent=2))
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    p=sub.add_parser('validate');p.add_argument('config');p.add_argument('run')
    p=sub.add_parser('edit');p.add_argument('run')
    args=parser.parse_args()
    result=validate(args.config,args.run) if args.command=='validate' else edit(args.run)
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
