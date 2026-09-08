"""Small original, deterministic fire, rain and line-twitch recordings."""
from pathlib import Path
import wave
import numpy as np
out=Path(__file__).resolve().parents[1]/'assets/audio'
rng=np.random.default_rng(184809)
for name,seconds in [('fire',8),('rain',8),('line_twitch',.16)]:
    rate=24000;n=int(rate*seconds);x=rng.normal(0,1,n)
    if name=='fire':
        x=np.convolve(x,np.ones(15)/15,'same')*.2
        for i in rng.integers(0,n-500,65):
            x[i:i+500]+=rng.normal(0,.15,500)*np.exp(-np.arange(500)/70)
    elif name=='line_twitch':x*=np.exp(-np.arange(n)/500)
    else:x=np.convolve(x,[.3,.4,.3],'same')*.18
    x-=x.mean();x*=.65/max(abs(x))
    if name=='line_twitch':
        x[:120]*=np.linspace(0,1,120);x[-120:]*=np.linspace(1,0,120)
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setparams((1,2,rate,n,'NONE','not compressed'));f.writeframes((x*32767).astype('<i2').tobytes())
