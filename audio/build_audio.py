"""Author the small, deterministic mono sound library. Requires NumPy only.
FFT-shaped periodic noise gives ambient loops a continuous seam. No recordings,
music, downloaded samples, or runtime synthesis dependencies are used.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 24000
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(184807)


def noise(seconds, low, high, slope=0):
    n = round(seconds * RATE)
    f = np.fft.rfftfreq(n, 1 / RATE)
    shape = (1 - np.exp(-(f / low)**4)) * np.exp(-(f / high)**2)
    shape *= np.maximum(f, low)**slope
    spectrum = (rng.normal(size=len(f)) + 1j*rng.normal(size=len(f))) * shape
    x = np.fft.irfft(spectrum, n)
    return x / np.std(x)


def save(name, x, loop=False):
    x -= x.mean()
    if not loop:
        edge = min(480, len(x)//3)
        x[:edge] *= np.linspace(0, 1, edge)
        x[-edge:] *= np.linspace(1, 0, edge)
    x *= .72 / max(abs(x))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as stream:
        stream.setparams((1, 2, RATE, len(x), 'NONE', 'not compressed'))
        stream.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'{name}: {len(x)/RATE:.2f}s, peak {max(abs(x)):.3f}, RMS {np.sqrt(np.mean(x*x)):.3f}')


for name, seconds, lo, hi, slope in [('river', 16, 65, 5800, -.45), ('rapids', 12, 160, 8000, -.25), ('wind', 24, 110, 3200, -.8)]:
    t = np.arange(round(seconds*RATE))/RATE
    envelope = .76 + .13*np.sin(2*np.pi*t/seconds) + .08*np.sin(2*np.pi*3*t/seconds+.4)
    save(name, noise(seconds,lo,hi,slope)*envelope,True)

t = np.arange(18*RATE)/RATE
crickets = np.zeros_like(t)
for freq, beat, offset in [(4300, 54/18, .1), (5100, 43/18, 1.4), (3700, 37/18, .6)]:
    pulses = np.maximum(0, np.sin(2*np.pi*beat*t+offset))**14
    groups = .25+.75*np.maximum(0,np.sin(2*np.pi*(3/18)*t+offset))**2
    crickets += np.sin(2*np.pi*freq*t)*pulses*groups
save('crickets', crickets, True)

for variant in range(3):
    t = np.arange(round(2.4*RATE))/RATE
    bird = np.zeros_like(t)
    for start, duration, f in [(0,.16,2700),(.24,.25,3400),(.68,.18,2900),(1.02,.38,2300)]:
        u = np.clip((t-start)/duration,0,1)
        envelope = np.sin(np.pi*u)**2
        phase = 2*np.pi*((f+variant*230)*t + 260*duration*np.sin(np.pi*u))
        bird += envelope*(np.sin(phase)+.15*np.sin(2*phase))
    save(f'bird_{variant}',bird)
    owl = np.zeros_like(t)
    for start, duration in [(0,.28),(.4,.23),(.86,.65)]:
        u = np.clip((t-start)/duration,0,1)
        phase = 2*np.pi*(340+variant*19)*t + 1.8*np.sin(np.pi*u)
        owl += np.sin(np.pi*u)**1.4*(np.sin(phase)+.18*np.sin(2*phase))
    save(f'owl_{variant}',owl)
    for kind, seconds in [('gravel',.38),('step_water',.65),('scoop',1.3),('wash',1.5)]:
        t = np.arange(round(seconds*RATE))/RATE
        x = noise(seconds,160 if kind=='gravel' else 85,6800,-.35)
        envelope = (1-np.exp(-t*80))*np.exp(-t*(12 if kind=='gravel' else 4))
        envelope *= .4+.6*(.5+.5*np.sin(2*np.pi*(17+variant*3)*t))**2
        if kind!='gravel':
            x += .6*np.sin(2*np.pi*(320*t+80*np.sin(t*11))) * np.exp(-t*7)
        save(f'{kind}_{variant}',x*envelope)
t = np.arange(2*RATE)/RATE
save('swirl',noise(2,140,5400,-.4)*(.45+.55*(.5+.5*np.sin(2*np.pi*t))**2),True)
