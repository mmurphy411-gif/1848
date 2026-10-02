"""Diegetic campfire harmonica: three period tunes for the 2.0 crew camp.

Deterministic, NumPy-only model of a man at the fire playing a ten-hole
Richter-tuned C diatonic harmonica. Each note is a free reed: a phase-locked,
band-limited harmonic series whose partials are shaped by a nasal
mouth/cover-plate formant, a hand-cup low-pass that opens and closes on long
notes (tremolo + wah), and breath pressure (soft notes are darker). Breath
noise rides every note, tongued puffs mark onsets, inhales fill phrase gaps,
and on strong beats the neighbouring reeds under the mouth sometimes sound the
chord the instrument is built to give. A fixed seed humanizes timing,
dynamics, scoops and rubato. Outdoors: two -20 dB early reflections, no reverb.

Melodies are explicit note lists, `NAME+OCTAVE:BEATS`, `R` = rest, `|` = bar
line (every full bar is checked against the meter). Sources: Foster's tune as
printed in Howe's banjo preceptor (1848/1851); Bishop's 1823 vocal line;
Arkansas Traveler as written down by W. S. Mount (1852). All transposed to C.

  python audio/build_camp_music.py
"""
from pathlib import Path
import wave
import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
LEAD, TAIL = .75, 1.0
STEPS = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
BLOW = ['C4', 'E4', 'G4', 'C5', 'E5', 'G5', 'C6', 'E6', 'G6', 'C7']   # holes 1-10
DRAW = ['D4', 'G4', 'B4', 'D5', 'F5', 'A5', 'B5', 'D6', 'F6', 'A6']
THETA = np.random.default_rng(1848).uniform(0, 2 * np.pi, 64)       # this reed's waveform


def midi(name):
    return STEPS[name[0]] + name.count('#') - name[1:].count('b') + 12 * (int(name[-1]) + 1)


REEDS = {midi(n): (BLOW, i) for i, n in enumerate(BLOW)}
REEDS.update({midi(n): (DRAW, i) for i, n in enumerate(DRAW)})       # G4 is played 2-draw


def reed_of(m):
    """(row, hole index, bend in semitones) a player would use for this pitch."""
    if m in REEDS:
        return (*REEDS[m], 0)
    for i in range(4):                                                # draw bends, holes 1-4
        if 0 < midi(DRAW[i]) - m <= 3:
            return DRAW, i, midi(DRAW[i]) - m
    raise ValueError(f'{m} is not playable on a C harp')


def chord_under(m):
    """The one or two reeds beside the melody hole, kept only if they are consonant."""
    row, i, bend = reed_of(m)
    if bend:
        return []
    return [midi(row[j]) for j in (i - 1, i - 2)
            if j >= 0 and (m - midi(row[j])) in (3, 4, 5, 7, 8, 9)]


# --------------------------------------------------------------------------
# Oh! Susanna (Foster, 1848). C major, 4/4 with the printed 2/4 eighth = one
# beat. Verse = phrase A (half cadence on D) + A' (home on C), played twice;
# chorus = new four bars (up to F and A) + A'.
SUSANNA = dict(name='tune_susanna', seed=48001, bpm=108, meter=4, phrases=[
    # verse A: rise C-D-E-G-G-A, fall back, half cadence on D
    'C5:.5 D5:.5 | E5:1 G5:1 G5:1 A5:1 | G5:1 E5:1 C5:1.5 D5:.5 | E5:1 E5:1 D5:1 C5:1 | D5:3',
    # verse A': same opening, closes D-D-C on the tonic
    'C5:.5 D5:.5 | E5:1 G5:1 G5:1 A5:1 | G5:1 E5:1 C5:1 D5:1 | E5:1 E5:1 D5:1 D5:1 | C5:3',
    # verse A again
    'C5:.5 D5:.5 | E5:1 G5:1 G5:1 A5:1 | G5:1 E5:1 C5:1.5 D5:.5 | E5:1 E5:1 D5:1 C5:1 | D5:3',
    # verse A' again, then a beat's rest before the chorus
    'C5:.5 D5:.5 | E5:1 G5:1 G5:1 A5:1 | G5:1 E5:1 C5:1 D5:1 | E5:1 E5:1 D5:1 D5:1 | C5:3 R:1',
    # chorus B: F F, syncopated A A A, G G E C, half cadence on D
    '| F5:2 F5:2 | A5:1 A5:2 A5:1 | G5:1 G5:1 E5:1 C5:1 | D5:3',
    # chorus close = A'
    'C5:.5 D5:.5 | E5:1 G5:1 G5:1 A5:1 | G5:1 E5:1 C5:1 D5:1 | E5:1 E5:1 D5:1 D5:1 | C5:4',
], art=.9, art_rep=.8, rubato=.07, rubato_end=.22, fermata=1.35, lift=.06, breath=.24,
    vel=.8, trem=.26, scoop_p=.3, chord_p=.45, puff=.13, air=.045, attack=(.025, .05))

# Home! Sweet Home! (Bishop, 1823). C major, 4/4, andante. First two lines of
# the verse (the second closing on the tonic) and the refrain; the verse's
# third and fourth lines are left out to keep the night tune under a minute.
HOME = dict(name='tune_home', seed=48002, bpm=77, meter=4, phrases=[
    # verse line 1: do-re | mi. fa fa. sol | sol. mi mi sol | fa. mi fa re | mi
    'C5:.75 D5:.25 | E5:1.5 F5:.5 F5:1.5 G5:.5 | G5:1.5 E5:.5 E5:1 G5:1 | F5:1.5 E5:.5 F5:1 D5:1 | E5:3',
    # verse line 2: same rise, sol mi sol, fa. mi fa re, home on do
    'C5:.75 D5:.25 | E5:1.5 F5:.5 F5:1.5 G5:.5 | G5:2 E5:1 G5:1 | F5:1.5 E5:.5 F5:1 D5:1 | C5:2 R:2',
    # refrain line 1: long sol, fa-re, do . re . mi, lead-in sol
    '| G5:4 | F5:2 D5:2 | C5:1 R:1 D5:1 R:1 | E5:2 R:1',
    # refrain line 2: up to high do, ti-la-sol, sol mi sol, fa. mi fa re, do
    'G5:1 | C6:1.5 B5:.5 A5:1.5 G5:.5 | G5:2 E5:1 G5:1 | F5:1.5 E5:.5 F5:1 D5:1 | C5:3',
], art=.96, art_rep=.85, rubato=.1, rubato_end=.3, fermata=1.5, lift=.12, breath=.32,
    vel=.72, trem=.32, scoop_p=.35, chord_p=.35, puff=.07, air=.05, attack=(.04, .06))

# Arkansas Traveler (fiddle tune, c.1847), from W. S. Mount's 1852 manuscript.
# D major transposed to C: the low B, and A, become A4 (3-draw bent) and G4
# (2-draw). 2/4, quarter = one beat, AABB.
_A1 = ('| C5:.25 D5:.25 E5:.25 C5:.25 A4:.5 A4:.25 C5:.25 | G4:.5 G4:.25 A4:.25 C5:.5 C5:.5'
       ' | D5:.5 D5:.5 E5:.5 E5:.5 | C5:.25 D5:.25 E5:.25 C5:.25 A4:.5 C5:.5')
_A2 = ('| C5:.25 D5:.25 E5:.25 C5:.25 A4:.5 A4:.25 C5:.25 | G4:.5 G4:.25 A4:.25 C5:.5 G5:.5'
       ' | C6:.25 B5:.25 C6:.25 G5:.25 A5:.25 C6:.25 G5:.25 F5:.25 | E5:.25 C5:.25 D5:.25 E5:.25 C5:1')
_B1 = ('| G6:.25 F6:.25 E6:.25 G6:.25 F6:.25 E6:.25 D6:.25 F6:.25 | E6:.25 D6:.25 C6:.25 E6:.25 D6:.25 B5:.25 G5:.5'
       ' | C6:.25 C6:.25 C6:.5 D6:.25 D6:.25 D6:.5 | E6:.25 D6:.25 C6:.25 E6:.25 D6:1')
_B2 = ('| G6:.25 F6:.25 E6:.25 G6:.25 F6:.25 E6:.25 D6:.25 F6:.25 | E6:.25 D6:.25 C6:.25 E6:.25 D6:.25 B5:.25 G5:.5'
       ' | C6:.25 B5:.25 C6:.25 G5:.25 A5:.25 C6:.25 G5:.25 F5:.25 | E5:.25 C5:.25 D5:.25 E5:.25 C5:1')
TRAVELER = dict(name='tune_traveler', seed=48003, bpm=104, meter=2, phrases=[
    _A1,   # A part, first half: low turn, bent A, climbs to E
    _A2,   # A part, second half: leaps to G, high C turn, home on C
    _A1, _A2,
    _B1,   # B part: descending sequences from high G, sits on D
    _B2,   # B part close: same run, ends with the A-part cadence
    _B1, _B2,
], art=.82, art_rep=.7, rubato=.03, rubato_end=.18, fermata=1.6, lift=.02, breath=.12,
    vel=.78, trem=.2, scoop_p=.18, chord_p=.5, puff=.16, air=.04, attack=(.02, .03))

TUNES = [SUSANNA, HOME, TRAVELER]


def parse(phrases, meter):
    """Note lists -> events with phrase position, bar accents and a bar-length check."""
    events, bar, first, down = [], 0.0, True, False
    for p, text in enumerate(phrases):
        pos, start = 0.0, len(events)
        for tok in text.split():
            if tok == '|':
                assert first or abs(bar - meter) < 1e-9, f'bar of {bar} beats in phrase {p}'
                first, bar, down = False, 0.0, True
                continue
            name, beats = tok.split(':')
            events.append(dict(m=None if name == 'R' else midi(name), beats=float(beats), phrase=p,
                               pos=pos, down=down, mid=meter == 4 and abs(bar - 2) < 1e-9))
            pos += float(beats)
            bar += float(beats)
            down = False
        for e in events[start:]:
            e['plen'] = pos
    return events


def perform(tune, rng):
    """Place every note in seconds: rubato, jitter, articulation, breaths, dynamics."""
    ev, spb = parse(tune['phrases'], tune['meter']), 60 / tune['bpm']
    last_p = ev[-1]['phrase']
    notes, inhales, t = [], [(.12, LEAD - .1, 1.0)], LEAD
    for i, e in enumerate(ev):
        final, nxt = i == len(ev) - 1, ev[i + 1] if i + 1 < len(ev) else None
        ramp = float(np.clip((e['pos'] + e['beats'] - e['plen'] + 2) / 2, 0, 1))   # last two beats
        dur = e['beats'] * spb * (1 + (tune['rubato_end'] if e['phrase'] == last_p else tune['rubato']) * ramp)
        dur *= tune['fermata'] if final else 1
        phrase_end = final or nxt['phrase'] != e['phrase']
        if e['m'] is None:
            if dur > .6:
                inhales.append((t + .05, t + dur - .05, .6))
        else:
            length = dur * (tune['art_rep'] if nxt and nxt['m'] == e['m'] else tune['art'])
            if phrase_end and not final:
                length = max(.12, dur - tune['breath'])
                inhales.append((t + length + .06, t + dur + tune['lift'] - .04, 1.0))
            vel = tune['vel'] * (1 + .1 * e['down'] + .04 * e['mid']) * rng.uniform(.93, 1.07)
            vel *= 1 + .08 * np.sin(np.pi * e['pos'] / e['plen'])
            if e['phrase'] == last_p:
                vel *= 1 - .15 * ramp
            jitter = 0.0 if i == 0 else float(np.clip(rng.normal(0, .006), -.015, .015))
            notes.append(dict(m=e['m'], t=t + jitter, length=length, vel=vel, down=e['down'],
                              first=e['pos'] == 0 or (e['pos'] < 1 and e['beats'] < 1), final=final))
        t += dur + (tune['lift'] if phrase_end else 0)
    return notes, inhales


def wander(rng, n, hz):
    """Smooth random motion, unit scale, about `hz` changes per second."""
    pts = rng.normal(size=int(n / RATE * hz) + 3)
    return np.interp(np.arange(n) / RATE * hz, np.arange(pts.size), pts)


def shaped_noise(rng, n, lo, hi):
    f = np.fft.rfftfreq(n, 1 / RATE)
    shape = (1 - np.exp(-(f / lo) ** 2)) * np.exp(-(f / hi) ** 2)
    x = np.fft.irfft((rng.normal(size=f.size) + 1j * rng.normal(size=f.size)) * shape, n)
    return x / np.std(x)


def formant(f):
    """Mouth and cover-plate resonance: nasal peaks near 1.4 and 2.5 kHz, soft top end."""
    return (.7 + 1.0 * np.exp(-((f - 1400) / 450) ** 2) + .6 * np.exp(-((f - 2500) / 700) ** 2)) \
        / (1 + (f / 6000) ** 4)


def reed(f0, length, vel, rng, air, attack, release, scoop=0.0, trem=0.0, rate=5.0, tph=0.0,
         sag=.12, aspiration=.045):
    """One free reed sounding `length` s plus its release, with breath through it."""
    n_on = max(int(length * RATE), 2)
    n = n_on + int(release * RATE)
    t = np.arange(n) / RATE
    env = np.ones(n)
    na = min(max(int(attack * RATE), 2), n_on)
    env[:na] = .5 - .5 * np.cos(np.pi * np.arange(na) / na)
    env *= 1 - sag * (1 - np.exp(-t / 1.6))                                   # breath sags
    env[n_on:] *= np.cos(.5 * np.pi * np.arange(n - n_on) / (n - n_on)) ** 2
    # hand cup: 0 = open, rising toward `trem` as the hand closes, ~5 Hz
    cup = trem * np.clip((t - .22) / .45, 0, 1) * (.5 - .5 * np.sin(2 * np.pi * rate * t + tph))
    fc = np.maximum(5000 * (1 - 2.4 * cup), 900)
    cents = 3 * wander(rng, n, 3) - 30 * cup + scoop * np.exp(-t / rng.uniform(.02, .045))
    phi = 2 * np.pi * np.cumsum(f0 * 2 ** (cents / 1200)) / RATE + rng.uniform(0, 2 * np.pi)
    x, norm = np.zeros(n), 0.0
    for k in range(1, int(11000 / f0) + 1):
        fk = k * f0
        a = k ** -.75 * (.6 + .4 * abs(np.sin(np.pi * k * .37))) * formant(fk)
        norm += (a / np.sqrt(1 + (fk / 5000) ** 2)) ** 2 / 2
        x += a / np.sqrt(1 + (fk / fc) ** 2) * env ** (.07 * (k - 1)) * np.sin(k * phi + THETA[k])
    level = env * (1 - cup) * (1 + .02 * wander(rng, n, 18)) * vel
    x = x / np.sqrt(norm) * level * (f0 / 600) ** -.1
    return x + air[:n] * level * aspiration * (1 + .6 * np.sin(phi))       # air through the slot


def fftconv(x, h):
    size = 1 << int(np.ceil(np.log2(len(x) + len(h))))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(h, size), size)
    return y[(len(h) - 1) // 2:(len(h) - 1) // 2 + len(x)]


def lowpass(fc, taps=255):
    m = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * fc / RATE * m) * np.hamming(taps)
    return h / h.sum()


def render(tune):
    rng = np.random.default_rng(tune['seed'])
    notes, inhales = perform(tune, rng)
    end = notes[-1]['t'] + notes[-1]['length'] + .5
    n = int((end + TAIL) * RATE)
    air, puffs, sighs = (shaped_noise(rng, n, lo, hi) for lo, hi in ((900, 4500), (1500, 6000), (350, 2200)))
    y = np.zeros(n)
    for e in notes:
        f0 = 440 * 2 ** ((e['m'] - 69) / 12)
        bend = reed_of(e['m'])[2]
        long = e['length'] > .6
        trem = tune['trem'] * rng.uniform(.75, 1.15) if long else 0.0
        rate, tph = rng.uniform(4.5, 5.5), rng.uniform(0, 2 * np.pi)
        if bend:
            scoop = rng.uniform(35, 70)                    # bent note: falls in from the reed's own pitch
        elif rng.random() < tune['scoop_p'] * (1.6 if e['first'] or long else 1):
            scoop = -rng.uniform(25, 60)
        else:
            scoop = 0.0
        scoop *= min(1.0, e['length'] / .3)                # quick notes only flick at the pitch
        attack = float(np.clip(rng.uniform(*tune['attack']), .02, max(.02, .4 * e['length'])))
        release = .45 if e['final'] else rng.uniform(.06, .12)
        i0 = int(e['t'] * RATE)
        x = reed(f0, e['length'], e['vel'], rng, air[i0:], attack, release, scoop, trem, rate, tph,
                 sag=.4 if e['final'] else .12, aspiration=tune['air'])
        tt = np.arange(min(int(.12 * RATE), n - i0)) / RATE                       # tongued puff
        x[:tt.size] += puffs[i0:i0 + tt.size] * (1 - np.exp(-tt / .003)) * np.exp(-tt / rng.uniform(.02, .035)) \
            * tune['puff'] * e['vel'] * rng.uniform(.6, 1.3)
        y[i0:i0 + x.size] += x[:n - i0]
        # neighbouring reeds under the lips: a short slap or a soft held chord
        if e['length'] >= .25 and rng.random() < tune['chord_p'] * (e['down'] + .7 * (e['length'] > .9)):
            slap = rng.random() < .6 or e['length'] < .5
            clen = min(e['length'], rng.uniform(.14, .28)) if slap else e['length'] * .9
            for j, m in enumerate(chord_under(e['m'])):
                c0 = i0 + int(rng.uniform(.005, .02) * RATE)
                cx = reed(440 * 2 ** ((m - 69) / 12), clen, e['vel'] * (.2 if slap else .11) * (.7 if j else 1),
                          rng, air[c0:], attack, .08, 0.0, trem, rate, tph, aspiration=0)
                y[c0:c0 + cx.size] += cx[:n - c0]
    for a, b, g in inhales:                                                       # breaths between phrases
        i0, i1 = int(a * RATE), int(b * RATE)
        if i1 - i0 > int(.08 * RATE):
            y[i0:i1] += sighs[i0:i1] * np.hanning(i1 - i0) ** 1.5 * .035 * g * rng.uniform(.8, 1.2)
    y += .35 * fftconv(y, lowpass(2600) - lowpass(1000))                           # nasal presence
    y -= y.mean()
    echo = np.zeros(n)                                                            # ground + a nearby wagon
    for sec, gain in ((.013, .1), (.029, .1), (.061, .03), (.097, .02)):
        d = int(sec * RATE)
        echo[d:] += y[:-d] * gain
    y += fftconv(echo, lowpass(3500, 63))
    fade = int(.5 * RATE)
    ramp = .5 - .5 * np.cos(np.pi * np.arange(fade) / fade)
    y[:fade] *= ramp
    y[-fade:] *= ramp[::-1]
    return y * (10 ** (-3 / 20) / np.max(np.abs(y))), notes


def save(name, x):
    pcm = np.round(x * 32767).astype('<i2')
    with wave.open(str(OUT / (name + '.wav')), 'wb') as stream:
        stream.setparams((1, 2, RATE, len(pcm), 'NONE', 'not compressed'))
        stream.writeframes(pcm.tobytes())


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for tune in TUNES:
        x, notes = render(tune)
        save(tune['name'], x)
        print(f"{tune['name']}: {len(x) / RATE:.2f}s, {len(notes)} notes, {tune['bpm']} bpm, "
              f"peak {20 * np.log10(np.max(np.abs(x))):.2f} dBFS, RMS {20 * np.log10(np.sqrt(np.mean(x * x))):.1f} dBFS")
