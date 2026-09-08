"""Read actual ID captures, color renders and the recorded game mix."""
from pathlib import Path
import json
import wave
import numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[1]/'artifacts'
legend=json.loads((root/'notes-6-material-legend.json').read_text())
results={}
for kind, count in [('pan-tier',5),('sack-stage',5),('pan-night',1)]:
    for i in range(count):
        label=f'{kind}-{i}' if count>1 else kind
        pixels=np.array(Image.open(root/f'notes-6-m8-{label}-material-ids.png').convert('RGB')).astype(int)
        masks={k:(np.max(abs(pixels-np.array(rgb)),axis=2)<5) for k,rgb in legend.items()}
        coverage={k:float(m.mean()) for k,m in masks.items()}
        pan=coverage['pan_interior']+coverage['pan_contents']
        if kind.startswith('pan'):
            passed=pan>=.15 and coverage['skin']<=.20 and max(coverage.values())<=.40
        else:
            passed=coverage['sack']>=[.008,.010,.012,.015,.018][i] and max(coverage.values())<=.50
        results[label]={'pass':passed,'pan':pan,'sack':coverage['sack'],'skin':coverage['skin'],'dominant':max(coverage.values())}
        print(label,results[label])
sacks=[results[f'sack-stage-{i}']['sack'] for i in range(5)]
assert all(a<b for a,b in zip(sacks,sacks[1:])),sacks
for time in [0,4]:
    path=root/f'notes-6-m8-oak-wind-{time}-material-ids.png'
    if not path.exists(): continue
    pixels=np.array(Image.open(path).convert('RGB')).astype(int)
    foliage=float((np.max(abs(pixels-np.array(legend['foliage'])),axis=2)<5).mean())
    results[f'oak-wind-{time}']={'pass':foliage>=.30,'foliage':foliage}
    print('oak',time,results[f'oak-wind-{time}'])
for name in ['day','night']:
    path=root/f'milestone-8-{name}-audio.wav'
    if not path.exists(): continue
    with wave.open(str(path),'rb') as source:
        rate=source.getframerate()
        channels=source.getnchannels()
        x=np.frombuffer(source.readframes(source.getnframes()),dtype='<i2').astype(float)/32768
    peak=float(abs(x).max())
    rms=float(np.sqrt(np.mean(x*x)))
    passed=bool(peak<.95 and rms>.0005 and abs(x.mean())<.01)
    results[f'audio-{name}']={'pass':passed,'seconds':len(x)/rate/channels,'peak':peak,'rms':rms,'dc':float(x.mean())}
    print(name,results[f'audio-{name}'])
(root/'milestone-8-probes.json').write_text(json.dumps(results,indent=2))
assert all(item['pass'] for item in results.values()),'Polish probe failure'
