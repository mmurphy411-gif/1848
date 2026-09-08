"""Measure the notes-round beauty renders against their diagnostic passes."""
import json
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts'
legend = json.loads((OUT/'notes-6-material-legend.json').read_text())
report = {}
failures = []

def read(name):
    return np.array(Image.open(OUT/('notes-6-'+name+'.png')).convert('RGB'))

def masks(name):
    im = read(name+'-material-ids').astype(np.int16)
    return {key: np.max(abs(im-np.array(rgb)),axis=2)<5 for key,rgb in legend.items()}

def check(ok, message):
    print(('PASS: ' if ok else 'FAIL: ')+message)
    if not ok: failures.append(message)

for shot in ['pan-side-swirl','pan-front-swirl','pan-front-wash','pan-showing','hands','miner-side','sack-stage-3']:
    categories = masks(shot)
    coverage = {key:float(value.mean()) for key,value in categories.items()}
    pan = sum(coverage[key] for key in ['pan_interior','pan_contents'])
    miner = sum(coverage[key] for key in ['shirt','trousers','leather','skin','hat','beard','suspenders'])
    report[shot] = coverage
    if shot=='pan-showing':
        check(pan>=.15,f'{shot}: pan interior and contents {pan:.1%}, minimum 15%')
        check(coverage['skin']<=.20,f'{shot}: skin {coverage["skin"]:.1%}, maximum 20%')
        dominant=max(coverage,key=coverage.get)
        check(coverage[dominant]<=.40,f'{shot}: largest material {dominant} {coverage[dominant]:.1%}, maximum 40%')
    elif shot=='sack-stage-3':
        check(coverage['sack']>=.015,f'{shot}: sack {coverage["sack"]:.1%}, minimum 1.5%')
    elif shot=='miner-side':
        check(miner>=.06,f'{shot}: miner {miner:.1%}, minimum 6%')
    elif shot=='hands':
        check(coverage['skin']>=.04,f'{shot}: skin in the grip review {coverage["skin"]:.1%}, minimum 4%')
        check(pan>=.10,f'{shot}: pan interior {pan:.1%}, minimum 10%')
    elif shot=='pan-side-swirl':
        check(miner>=.10,f'{shot}: crouched miner {miner:.1%}, minimum 10%')
    else:
        check(pan>=.025,f'{shot}: pan interior {pan:.1%}, minimum 2.5%')

# The actual gravel/sand mix is encoded by the terrain shader, and the stone
# population mask comes from the exact seeded gravel bake, not RGB guessing.
ids=masks('gravel-close')
probe=read('gravel-mix-probe')/255.
linear=np.where(probe<=.04045,probe/12.92,((probe+.055)/1.055)**2.4)
sand,stones=linear[:,:,0],linear[:,:,1]
stone_pixels=ids['terrain']&(sand<.2)&(stones>.95)
beauty=read('gravel-close')/255.
luminance=beauty@np.array([.2126,.7152,.0722])
valid=(luminance[stone_pixels]>=.25)&(luminance[stone_pixels]<=.85)
fraction=float(valid.mean()) if valid.size else 0.
check(valid.size>10000,'Gravel probe has more than 10,000 identified stone pixels')
check(fraction>=.95,f'Gravel stone luminance in [0.25,0.85]: {fraction:.1%}, minimum 95%')
transition=ids['terrain']&(abs(sand-.5)<.025)
longest=0
for row in transition:
    boundaries=np.flatnonzero(np.diff(np.r_[False,row,False]))
    if len(boundaries):longest=max(longest,int(np.max(boundaries[1::2]-boundaries[::2])))
check(longest<=200,f'Longest horizontal sand transition run {longest} pixels, maximum 200')
report['gravel']={'identified_pixels':int(valid.size),'luminance_in_range':fraction,'longest_transition_run':longest}

# Compare leaf shadows to the same frozen scene with the foliage still visible
# but casting disabled. Bark shadows remain in both images.
rock=masks('miner-standing')['nearest_boulder']
dark=read('miner-standing').astype(float)/255
light=read('standing-no-leaf-shadows').astype(float)/255
change=((light-dark)@np.array([.2126,.7152,.0722]))>.015
shadow=rock&change
ys,xs=np.where(shadow)
if len(xs):
    region=shadow[ys.min():ys.max()+1,xs.min():xs.max()+1]
    support=rock[ys.min():ys.max()+1,xs.min():xs.max()+1]
    density=float(region.sum()/max(1,support.sum()))
else:density=0.
check(int(shadow.sum())>=100,f'Oak leaf shadow affects {int(shadow.sum())} pixels on nearest boulder, minimum 100')
check(density>=.60,f'Oak canopy shadow fills {density:.1%} of its boulder footprint, minimum 60%')
report['oak_shadow']={'pixels':int(shadow.sum()),'footprint_density':density}
oak=masks('oak-under')['foliage'].mean()
check(oak>=.30,f'Oak-under crown coverage {oak:.1%}, minimum 30%')
report['oak_under_coverage']=float(oak)
report['failures']=failures
(OUT/'notes-6-render-probes.json').write_text(json.dumps(report,indent=2))
raise SystemExit(bool(failures))
