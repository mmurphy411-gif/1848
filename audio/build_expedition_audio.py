"""Original deterministic encounter foley; no downloaded recordings."""
from pathlib import Path
import wave
import numpy as np
out=Path(__file__).resolve().parents[1]/'assets/audio'
rng=np.random.default_rng(184812)
for name,seconds in [('shout',.65),('spear',.8),('rifle',1.6),('harvest',1.1)]:
    rate=24000;n=int(rate*seconds);t=np.arange(n)/rate;noise=rng.normal(0,1,n)
    if name=='shout':
        # A short nonverbal voiced call, with breath and falling pitch.
        phase=2*np.pi*(145*t-30*t*t)
        x=sum(np.sin(phase*k)/k for k in range(1,13))*.15+noise*.035
        x*=np.sin(np.pi*t/seconds)**.7
    elif name=='rifle':
        x=noise*np.exp(-t*32)*.7+np.convolve(noise,np.ones(28)/28,'same')*np.exp(-t*3)*.35
        for delay in [.13,.25,.41]:
            i=int(delay*rate);x[i:]+=noise[:n-i]*np.exp(-t[:n-i]*18)*.11
    elif name=='spear':
        x=np.convolve(noise,np.ones(4)/4,'same')*np.exp(-t*6)
        x+=np.sin(2*np.pi*(180*t-40*t*t))*np.exp(-t*12)*.14
    else:x=np.convolve(noise,np.ones(8)/8,'same')*(.25+.75*np.sin(t*13)**2)*np.sin(np.pi*t/seconds)
    x-=x.mean();x*=.75/max(abs(x));x[:60]*=np.linspace(0,1,60);x[-240:]*=np.linspace(1,0,240)
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setparams((1,2,rate,n,'NONE','not compressed'));f.writeframes((x*32767).astype('<i2').tobytes())
