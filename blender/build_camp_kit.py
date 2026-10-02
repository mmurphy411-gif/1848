"""Stage 6 camp kit: the visible camp props, built from parameters (no hand-placed
organic vertices) on the shared kit materials of blender/prop_kit.py.

  blender --background --python blender/build_camp_kit.py

Each prop keeps the frame of its legacy mesh in assets/camp/camp.glb, which stays the
collision source (camp.gd builds shapes from it, so collision is unchanged); this
script also rewrites camp.glb without its embedded 2k atlas (geometry and node names
untouched). Outputs in assets/camp/: lean_to, bedroll, pot, skillet, rack, cache,
firewood, ledger, chopping_block, fish_strips. Seeds are explicit.
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prop_kit as K  # noqa: E402

OUT = K.ASSETS / "camp"
NAMES = ["kit_bark", "kit_endgrain", "kit_canvas", "kit_rope", "kit_wool", "kit_iron",
         "kit_split", "kit_leather", "kit_paper", "kit_burlap", "kit_pork"]


def mats():
    return {n: K.placeholder(n) for n in NAMES}


def slots(*names):
    return [M[n] for n in names]


def save(builder, name, slot_names):
    obj = builder.build(name, slots(*slot_names))
    K.export_glb([obj], OUT / (name + ".glb"))
    return obj


def ix(names, n):
    return names.index(n)


def branch_pole(b, base, top, r0, r1, seed, segs=6, sides=7, bark=0, end=0, crook=.04):
    """A peeled-bark pole with a gentle random crook."""
    base, top = Vector(base), Vector(top)
    rng = random.Random(seed)
    pts, radii = [], []
    side = (top - base).cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    other = (top - base).normalized().cross(side)
    ph = rng.random() * 6
    for j in range(segs + 1):
        t = j / segs
        p = base.lerp(top, t) + side * crook * math.sin(math.pi * t + ph) * .5 + other * crook * .4 * math.sin(2 * math.pi * t + ph)
        pts.append(p)
        radii.append(r0 + (r1 - r0) * t)
    return K.tube(b, pts, radii, bark, sides=sides, tile=1.0, cap_mat=end, wobble=.08, seed=seed, dirt=K.ground_dirt(.55, .35))


# ------------------------------------------------------------------ lean-to

def lean_to():
    names = ["kit_bark", "kit_endgrain", "kit_canvas", "kit_rope"]
    b = K.MeshBuilder()
    bark, end, canvas, rope = 0, 0, 2, 3  # thin poles: bark caps (one surface fewer)
    # Forked uprights at the open front; the ridge pole rests in the forks.
    for s, seed in ((-1, 11), (1, 12)):
        branch_pole(b, (s * 1.03, .03, -.05), (s * 1.0, 0, 1.63), .05, .036, seed)
        for d, sd in ((1, 13), (-1, 14)):
            branch_pole(b, (s * 1.0, 0, 1.48), (s * (1.0 + .07 * d), -.05 * d, 1.76), .022, .014, seed * 10 + sd, segs=2, sides=4, crook=.01)
    ridge = []
    for j in range(9):
        t = j / 8
        ridge.append(Vector((-1.32 + 2.64 * t, .0, 1.665 - .025 * math.sin(math.pi * t))))
    K.tube(b, ridge, [.045 - .008 * t for t in [j / 8 for j in range(9)]], bark, sides=8, cap_mat=end, wobble=.07, seed=15)
    for s in (-1, 1):
        K.wraps(b, (s * 1.0, 0, 1.665), (1, 0, 0), .045, rope, turns=2, width=.04, thickness=.005, sides=4, seg=6)
    # Canvas: draped over the ridge with a short front flap, then down to its stakes.
    profile = [(-.085, 1.50), (-.08, 1.60), (-.055, 1.685), (0.0, 1.715), (.06, 1.70)]
    for k in range(1, 12):
        t = k / 11
        profile.append((.06 + (1.84 - .06) * t, 1.70 - (1.70 - .05) * t))
    nu = 14
    rows = []
    stakes_u = [0, 1 / 3, 2 / 3, 1]
    for j, (y, z) in enumerate(profile):
        row = []
        slope_t = max(0.0, (y - .06) / 1.78)
        for i in range(nu + 1):
            u = i / nu
            x = -1.17 + 2.34 * u
            sag = .11 * math.sin(math.pi * u) * math.sin(math.pi * min(1.0, slope_t * 1.05)) if slope_t > 0 else 0
            # The free bottom edge lifts between its pegs (scalloped hem).
            if j == len(profile) - 1:
                z_edge = .05 + .06 * abs(math.sin(3 * math.pi * u))
                z = z_edge
            elif j == len(profile) - 2:
                z += .025 * abs(math.sin(3 * math.pi * u))
            p = Vector((x, y, z - sag))
            p.z += .013 * K.fbm((x, y, z), 2.2, 41)
            p.y += .010 * K.fbm((x, y, z), 2.2, 43)
            c = .55 + .45 * min(1.0, p.z / .5)
            row.append(p)
        rows.append(row)
    arc = [0.0]
    for j in range(1, len(profile)):
        arc.append(arc[-1] + math.hypot(profile[j][0] - profile[j - 1][0], profile[j][1] - profile[j - 1][1]))
    ids = [[b.vert(p, .55 + .45 * min(1.0, p.z / .55)) for p in row] for row in rows]
    for j in range(len(rows) - 1):
        for i in range(nu):
            q = [ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]]
            uv = [(2.34 * i / nu, arc[j]), (2.34 * (i + 1) / nu, arc[j]), (2.34 * (i + 1) / nu, arc[j + 1]), (2.34 * i / nu, arc[j + 1])]
            b.face(q, uv, canvas)
    # Pegs and ties along the hem; guy lines from the ridge ends, angled back from the fire.
    for k, u in enumerate(stakes_u):
        x = -1.17 + 2.34 * u
        peg = Vector((x * 1.04, 2.0, 0))
        branch_pole(b, peg + Vector((0, -.03, -.06)), peg + Vector((x * .03, .05, .2)), .022, .016, 60 + k, segs=2, sides=5, crook=.0)
        K.rope(b, (x, 1.84, .06), peg + Vector((x * .03, .045, .17)), rope, radius=.005, sag=.01, n=4, sides=4)
    for s in (-1, 1):
        peg = Vector((s * 1.95, .55, 0))
        branch_pole(b, peg + Vector((0, 0, -.06)), peg + Vector((s * .05, .04, .22)), .022, .016, 70 + s, segs=2, sides=5, crook=.0)
        K.rope(b, (s * 1.30, 0, 1.68), peg + Vector((s * .05, .04, .19)), rope, radius=.005, sag=.05, n=7, sides=4)
    return save(b, "lean_to", names)


# ------------------------------------------------------------------ bedroll

def bedroll():
    names = ["kit_canvas", "kit_wool", "kit_rope"]
    b = K.MeshBuilder()
    canvas, wool, rope = 0, 1, 2
    # Ground cloth.
    nx, ny = 4, 8
    g = [[b.vert((-.45 + .9 * i / nx, -.98 + 1.96 * j / ny, .006 + .006 * K.vnoise((i, j, 0), .9, 5) + (.015 if i in (0, nx) or j in (0, ny) else 0) * max(0, K.vnoise((i, j, 1), .7, 6))), .7)
          for i in range(nx + 1)] for j in range(ny + 1)]
    for j in range(ny):
        for i in range(nx):
            b.face([g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i]],
                   [(.9 * i / nx, 1.96 * j / ny), (.9 * (i + 1) / nx, 1.96 * j / ny), (.9 * (i + 1) / nx, 1.96 * (j + 1) / ny), (.9 * i / nx, 1.96 * (j + 1) / ny)], canvas)
    # Wool blanket over bedding: a soft mound, folded back at the chest.
    nx, ny = 10, 14
    w = []
    for j in range(ny + 1):
        row = []
        y = -.92 + 1.38 * j / ny
        for i in range(nx + 1):
            u = i / nx
            x = -.40 + .80 * u
            across = math.sin(math.pi * u) ** .6
            along = min(1.0, (y + .92) / .25) * min(1.0, (.46 - y) / .08 + .2)
            z = .018 + .085 * across * max(0.0, along)
            if j == ny:
                z += .03 * across
            z += .012 * K.fbm((x, y, 0), 4.0, 21) * across
            row.append(b.vert((x + .01 * K.vnoise((x, y, 3), 5, 22), y, z), .62 + .38 * min(1.0, z / .09)))
        w.append(row)
    for j in range(ny):
        for i in range(nx):
            b.face([w[j][i], w[j][i + 1], w[j + 1][i + 1], w[j + 1][i]],
                   [(.8 * i / nx, 1.38 * j / ny), (.8 * (i + 1) / nx, 1.38 * j / ny), (.8 * (i + 1) / nx, 1.38 * (j + 1) / ny), (.8 * i / nx, 1.38 * (j + 1) / ny)], wool)
    # Turned-back fold: a flattened roll across the chest.
    fold = [Vector((-.40 + .80 * k / 8, .47, .11 + .01 * math.sin(k))) for k in range(9)]
    K.tube(b, fold, .035, wool, sides=6, tile=1.0)
    # Rolled coat as a pillow, tied twice.
    roll = [Vector((-.32 + .64 * k / 4, .74, .11)) for k in range(5)]
    K.tube(b, roll, .1, canvas, sides=10, tile=1.0, cap_mat=wool, wobble=.06, seed=23)
    for x in (-.18, .18):
        K.wraps(b, (x, .74, .11), (1, 0, 0), .1, rope, turns=2, width=.025, thickness=.005, sides=4, seg=10)
    return save(b, "bedroll", names)


# ------------------------------------------------------------------ pot and skillet

def pot():
    names = ["kit_bark", "kit_endgrain", "kit_iron", "kit_rope"]
    b = K.MeshBuilder()
    bark, end, iron, rope = 0, 0, 2, 3  # thin poles: bark caps (one surface fewer)
    apex = Vector((0, 0, .92))
    for k, (ang, seed) in enumerate(((90, 31), (210, 32), (330, 33))):
        a = math.radians(ang)
        foot = Vector((math.cos(a) * .36, math.sin(a) * .36, -.03))
        over = apex + (apex - foot).normalized() * .1
        branch_pole(b, foot, over, .02, .014, seed, segs=5, sides=6, crook=.02)
    K.wraps(b, apex + Vector((0, 0, .01)), (0, 0, 1), .03, rope, turns=4, width=.06, thickness=.006, sides=4, seg=8)
    # Pot-hook chain: alternating links down to the bail.
    z = .90
    for k in range(5):
        a = k * math.pi / 2
        ring = []
        for i in range(9):
            t = math.tau * i / 8
            ring.append(Vector((math.cos(a) * .012 * math.cos(t), math.sin(a) * .012 * math.cos(t), z - .022 * math.sin(t) - .022)))
        K.tube(b, ring, .0045, iron, sides=4, tile=.05)
        z -= .036
    hook = [Vector((0, 0, z)), Vector((0, 0, z - .03)), Vector((.012, 0, z - .045)), Vector((.02, 0, z - .03))]
    K.tube(b, hook, .005, iron, sides=4, tile=.05)
    # Cast-iron kettle with a rolled lip and an inner wall, hanging from its bail.
    bottom = .30
    prof = [(0, bottom), (.08, bottom), (.13, bottom + .012), (.163, bottom + .05), (.172, bottom + .11), (.165, bottom + .17),
            (.156, bottom + .19), (.164, bottom + .198), (.16, bottom + .205), (.148, bottom + .196), (.15, bottom + .12), (.12, bottom + .03), (0, bottom + .025)]
    K.lathe(b, prof, iron, sides=18, tile=.4, dirt=lambda p: .8 + .2 * min(1.0, (p.z - bottom) / .2))
    for s in (-1, 1):
        K.box(b, (s * .168, 0, bottom + .175), (.02, .03, .03), iron, tile=.3)
    bail = []
    for i in range(13):
        t = math.pi * i / 12
        bail.append(Vector((math.cos(t) * .168, 0, bottom + .175 + math.sin(t) * (z - .045 - (bottom + .175)))))
    K.tube(b, bail, .0045, iron, sides=4, tile=.05)
    return save(b, "pot", names)


def skillet():
    names = ["kit_iron"]
    b = K.MeshBuilder()
    prof = [(0, .018), (.15, .018), (.178, .026), (.191, .05), (.196, .068), (.19, .072), (.181, .066), (.172, .04), (.155, .03), (0, .029)]
    K.lathe(b, prof, 0, sides=20, tile=.3)
    # Handle along +X (camp.gd grips it there), slightly upturned, with a hang hole look.
    pts = [Vector((.175, 0, .058)), Vector((.26, 0, .064)), Vector((.40, 0, .074)), Vector((.48, 0, .079))]
    rings = K.tube(b, pts, [.016, .014, .013, .016], 0, sides=6, tile=.3)
    # Flatten the handle into a bar.
    start = rings[0][0][0]
    for i in range(start, len(b.v)):
        p = b.v[i]
        if p.x > .17:
            axis_z = .058 + (p.x - .175) * .07
            b.v[i] = Vector((p.x, p.y * 1.25, axis_z + (p.z - axis_z) * .55))
    b.dirt(lambda p: .9 if p.z > .05 else .75)
    return save(b, "skillet", names)


# ------------------------------------------------------------------ smoking rack, cache, firewood

def rack():
    names = ["kit_bark", "kit_endgrain", "kit_rope"]
    b = K.MeshBuilder()
    bark, end, rope = 0, 0, 2  # thin poles: bark caps (one surface fewer)
    for s, seed in ((-1, 41), (1, 42)):
        branch_pole(b, (s * .61, .02, -.05), (s * .6, 0, 1.24), .036, .028, seed)
        for d, sd in ((1, 3), (-1, 4)):
            branch_pole(b, (s * .6, 0, 1.12), (s * (.6 + .05 * d), -.04 * d, 1.32), .016, .011, seed * 10 + sd, segs=3, sides=5, crook=.008)
        K.wraps(b, (s * .6, 0, 1.2), (1, 0, 0), .03, rope, turns=3, width=.04, thickness=.005, sides=4, seg=8)
    bar = [Vector((-.74 + 1.48 * k / 6, 0, 1.205 + .01 * math.sin(k))) for k in range(7)]
    K.tube(b, bar, .028, bark, sides=7, cap_mat=end, wobble=.06, seed=43)
    # A lower brace and thin hanging sticks for strips of fish or meat.
    brace = [Vector((-.6 + 1.2 * k / 4, .0, .55 + .015 * math.sin(k * 2))) for k in range(5)]
    K.tube(b, brace, .018, bark, sides=6, cap_mat=end, wobble=.05, seed=44)
    for k, x in enumerate((-.36, -.12, .12, .36)):
        K.rope(b, (x, 0, 1.18), (x + .01, .0, .98), rope, radius=.004, sag=.0, n=2, sides=4)
    return save(b, "rack", names)


def fish_strips():
    """Split fish and meat strips hanging on the rack while it smokes (shown by camp.gd)."""
    names = ["kit_pork"]
    b = K.MeshBuilder()
    for k, x in enumerate((-.36, -.12, .12, .36)):
        n = 6
        ring = []
        for j in range(n + 1):
            t = j / n
            w = .05 * math.sin(math.pi * (.15 + .85 * t)) + .012
            z = .98 - .38 * t
            curl = .015 * math.sin(t * 3 + k)
            # Front and back sheets 4 mm apart (a split fillet has thickness).
            ring.append((b.vert((x - w, curl, z), .8), b.vert((x + w, curl + .01, z), .8),
                         b.vert((x - w, curl + .004, z), .7), b.vert((x + w, curl + .014, z), .7)))
        for j in range(n):
            a, c = ring[j], ring[j + 1]
            b.face([a[0], a[1], c[1], c[0]], [(0, j / n), (1, j / n), (1, (j + 1) / n), (0, (j + 1) / n)], 0)
            b.face([c[2], c[3], a[3], a[2]], [(0, (j + 1) / n), (1, (j + 1) / n), (1, j / n), (0, j / n)], 0)
    return save(b, "fish_strips", names)


def sack_profile(height, radius, neck, fill=1.0, tied=True):
    """(r, z) profile of a tied or open sack, base at z=0."""
    prof = [(0, 0)]
    for k in range(1, 11):
        t = k / 10
        z = height * t
        belly = math.sin(math.pi * min(1.0, t / .92) * .5 + .15) if t < .92 else .0
        if tied:
            r = radius * (.82 + .3 * math.sin(math.pi * min(t, .78) / .78 * .55)) * (1 - max(0, t - .7) / .3 * (1 - neck / radius))
        else:
            r = radius * (.9 + .12 * math.sin(math.pi * t)) * (1 + (1 - fill) * .15 * (1 - t))
        if k == 1:
            r = radius * .78
        prof.append((max(r, neck), z))
    return prof


def cache():
    names = ["kit_burlap", "kit_rope"]
    b = K.MeshBuilder()
    burlap, rope = 0, 1
    prof = []
    for k in range(13):
        t = k / 12
        z = -.62 + .62 * t
        if t < .08:
            r = .05 + .15 * t / .08
        elif t < .75:
            r = .2 * (1 - .15 * ((t - .45) / .3) ** 2)
        else:
            r = .2 - .165 * (t - .75) / .25
        prof.append((max(r, .035), z - .06))
    prof.insert(0, (0, -.68))
    rings = K.lathe(b, prof, burlap, sides=12, tile=.4, squash=(1.0, .82))
    for i, p in enumerate(b.v):
        n = Vector((p.x, p.y, 0))
        if n.length > 1e-4:
            b.v[i] = p + n.normalized() * .018 * K.fbm(p, 6, 51)
    K.lathe(b, [(.035, -.06), (.05, -.02), (.03, .02), (.0, .05)], burlap, sides=8, tile=.3)
    K.wraps(b, (0, 0, -.075), (0, 0, 1), .033, rope, turns=3, width=.03, thickness=.005, sides=4, seg=8)
    K.tube(b, [Vector((0, 0, -.06)), Vector((.005, 0, .3)), Vector((0, .004, .8))], .007, rope, sides=4, tile=.05)
    return save(b, "cache", names)


def split_piece(b, center, length, radius, a0, a1, yaw, seed, bark, split, end):
    """A split firewood piece: bark on the arc, split faces, end grain at both ends."""
    rot = Matrix.Rotation(yaw, 3, "Z")
    c = Vector(center)
    arcn = 4
    section = [(0.0, 0.0)] + [(math.cos(a0 + (a1 - a0) * k / arcn) * radius, math.sin(a0 + (a1 - a0) * k / arcn) * radius) for k in range(arcn + 1)]
    ends = []
    for e, x in enumerate((-length / 2, length / 2)):
        ring = []
        for k, (sy, sz) in enumerate(section):
            jitter = .006 * K.vnoise((x, sy, sz), 30, seed + k)
            p = c + rot @ Vector((x + jitter, sy, sz + radius * .9))
            ring.append(b.vert(p, .6 + .4 * min(1.0, p.z / .25)))
        ends.append(ring)
    n = len(section)
    for k in range(n):
        k2 = (k + 1) % n
        is_bark = 1 <= k < n - 1
        mat = bark if is_bark else split
        w = math.hypot(section[k2][0] - section[k][0], section[k2][1] - section[k][1])
        uv = [(0, 0), (w, 0), (w, length), (0, length)]
        b.face([ends[0][k], ends[0][k2], ends[1][k2], ends[1][k]], uv, mat, not is_bark)
    for e, ring in enumerate(ends):
        uvs = [(.5 + .5 * sy / radius, .5 + .5 * sz / radius) for sy, sz in section]
        ids = list(ring)
        if e == 0:
            ids, uvs = ids[::-1], uvs[::-1]
        b.face(ids, uvs, end, True)


def firewood():
    names = ["kit_bark", "kit_split", "kit_endgrain"]
    b = K.MeshBuilder()
    rng = random.Random(61)
    pieces = [((-.04, -.16, 0), 0), ((-.02, -.02, 0), 1), ((.0, .13, 0), 2), ((-.03, -.09, .1), 3), ((.02, .06, .1), 4), ((0, -.02, .19), 5)]
    for (x, y, z), k in pieces:
        r = rng.uniform(.075, .095)
        a0 = rng.uniform(0, math.tau)
        span = rng.choice((math.pi / 2, math.pi / 2, 2 * math.pi / 3, math.pi))
        split_piece(b, (x, y, z), rng.uniform(.55, .68), r, a0, a0 + span, rng.uniform(-.12, .12), 600 + k, 0, 1, 2)
    for k, (y, z) in enumerate(((.24, .02), (-.27, .025))):
        pts = [Vector((-.33 + .66 * t, y + .03 * math.sin(t * 3 + k), z + .015 * math.sin(t * 5))) for t in [j / 4 for j in range(5)]]
        K.tube(b, pts, .03, 0, sides=6, cap_mat=2, wobble=.08, seed=70 + k)
    return save(b, "firewood", names)


def woodpile():
    """A cord of split wood stacked against two stakes, seasoning beside the camp."""
    names = ["kit_bark", "kit_split", "kit_endgrain"]
    b = K.MeshBuilder()
    rng = random.Random(77)
    for layer in range(4):
        n = 6 - layer // 2
        for k in range(n):
            y = -.42 + .84 * (k + .5) / n + rng.uniform(-.02, .02)
            r = rng.uniform(.07, .09)
            a0 = rng.uniform(0, math.tau)
            split_piece(b, (rng.uniform(-.05, .05), y, layer * .15 - .02), rng.uniform(.6, .7), r, a0,
                        a0 + rng.choice((math.pi / 2, 2 * math.pi / 3, math.pi)), rng.uniform(-.06, .06), 700 + layer * 10 + k, 0, 1, 2)
    for s in (-1, 1):
        branch_pole(b, (0, s * .5, -.05), (s * .01, s * .53, .7), .03, .024, 790 + s, segs=3, sides=6, crook=.01, end=2)
    return save(b, "woodpile", names)


def embers():
    """Charred ends of split wood crossed in the ash of the fire ring."""
    names = ["kit_bark", "kit_split", "kit_endgrain"]
    b = K.MeshBuilder()
    rng = random.Random(91)
    for k in range(4):
        yaw = k * math.pi / 2.2 + rng.uniform(-.2, .2)
        c = (math.cos(yaw) * .12, math.sin(yaw) * .12, -.055 + .02 * (k % 2))
        start = len(b.v)
        split_piece(b, c, rng.uniform(.34, .42), rng.uniform(.04, .055), rng.uniform(0, 6), rng.uniform(0, 6) + 2.2, yaw, 900 + k, 0, 1, 2)
        for i in range(start, len(b.v)):
            p = b.v[i]
            # Burnt toward the middle of the fire, a little bark left at the outer end.
            d = math.hypot(p.x, p.y)
            b.c[i] = .06 + .3 * max(0.0, min(1.0, (d - .12) / .14))
            b.v[i] = Vector((p.x, p.y, p.z + .01 * (d < .1)))
    return save(b, "embers", names)


def coffee():
    """A blackened coffee pot and two tin cups on a flat stone by the fire."""
    names = ["kit_iron", "kit_bark"]
    b = K.MeshBuilder()
    K.lathe(b, [(0, .0), (.075, 0), (.08, .01), (.07, .09), (.055, .17), (.05, .18), (.057, .185), (.03, .2), (0, .205)], 0, sides=14, tile=.3)
    spout = [Vector((.065, 0, .04)), Vector((.1, 0, .1)), Vector((.13, 0, .155)), Vector((.14, 0, .165))]
    K.tube(b, spout, [.016, .012, .008, .008], 0, sides=6, tile=.2)
    handle = [Vector((-.06, 0, .15)), Vector((-.1, 0, .14)), Vector((-.11, 0, .09)), Vector((-.075, 0, .04))]
    K.tube(b, handle, .007, 0, sides=4, tile=.2)
    for k, (x, y) in enumerate(((.2, .1), (.17, -.12))):
        K.lathe(b, [(0, .002), (.036, .002), (.04, .075), (.036, .075), (.032, .008), (0, .008)], 0, sides=10, tile=.2, center=(x, y, 0))
    b.dirt(lambda p: .55 + .45 * min(1.0, p.z / .2))
    return save(b, "coffee", names)


def ledger():
    names = ["kit_leather", "kit_paper"]
    b = K.MeshBuilder()
    K.box(b, (0, 0, .0045), (.275, .355, .009), 0, tile=.3)
    K.box(b, (.004, 0, .023), (.262, .345, .028), 1, tile=.3)
    K.box(b, (0, 0, .0415), (.275, .355, .009), 0, tile=.3)
    K.box(b, (-.137, 0, .023), (.012, .355, .046), 0, tile=.3)
    return save(b, "ledger", names)


def chopping_block():
    names = ["kit_bark", "kit_endgrain"]
    b = K.MeshBuilder()
    prof = [(.21, 0), (.215, .05), (.205, .2), (.2, .36)]
    K.lathe(b, prof, 0, sides=12, tile=1.0, wobble=.08, seed=81, close_top=True, cap_mat=1, dirt=K.ground_dirt(.5, .3))
    return save(b, "chopping_block", names)


def strip_camp_glb():
    """camp.glb stays the collision source; drop its 2k atlas (geometry unchanged)."""
    path = OUT / "camp.glb"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in objs:
        o.data.materials.clear()
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    settings = dict(K.GLTF_EXPORT)
    settings.update(export_apply=False, export_vertex_color="NONE", export_all_vertex_colors=False)
    bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_materials="NONE", **settings)
    print("EXPORTED assets/camp/camp.glb (collision proxies):", ", ".join(sorted(o.name for o in objs)))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--strip-camp" in argv:
        strip_camp_glb()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M = mats()
    wanted = [a for a in argv if not a.startswith("--")]
    for build in (lean_to, bedroll, pot, skillet, rack, fish_strips, cache, firewood, woodpile, embers, coffee, ledger, chopping_block):
        if not wanted or build.__name__ in wanted:
            build()
    print("BUILT camp kit")
