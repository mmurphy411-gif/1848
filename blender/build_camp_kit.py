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
NAMES = ["kit_bark", "kit_endgrain", "kit_canvas", "kit_rope", "kit_wool", "kit_iron", "kit_tin", "kit_blanket", "kit_wood", "kit_ash",
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


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def stake(b, foot, lean, seed, mat, end, height=.26, r=.026):
    """A whittled tent stake driven at a slant: split wood (pale, so it reads), notched top."""
    base = Vector(foot) + Vector((0, 0, -.08))
    top = Vector(foot) + Vector(lean).normalized() * .05 + Vector((0, 0, height))
    branch_pole(b, base, top, r, r * .8, seed, segs=2, sides=5, bark=mat, end=end, crook=0)
    return top


def canvas_sheet(b, pt, nu, ns, width, mat, dirt_z=.55):
    """A sheet from a point function pt(u, s) -> Vector; UVs in metres along both ways."""
    grid = [[pt(i / nu, j / ns) for i in range(nu + 1)] for j in range(ns + 1)]
    arc = [0.0]
    for j in range(1, ns + 1):
        arc.append(arc[-1] + (grid[j][nu // 2] - grid[j - 1][nu // 2]).length)
    ids = [[b.vert(p, .55 + .45 * min(1.0, max(0.0, p.z) / dirt_z)) for p in row] for row in grid]
    for j in range(ns):
        for i in range(nu):
            uv = [(width * i / nu, arc[j]), (width * (i + 1) / nu, arc[j]), (width * (i + 1) / nu, arc[j + 1]), (width * i / nu, arc[j + 1])]
            b.face([ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]], uv, mat)
    return grid


# ------------------------------------------------------------------ lean-to

def lean_to():
    """Wave C: the canvas hangs like cloth. It drapes over a ridge pole that bows between
    its forks, sags in a catenary down the slope, troughs between the four hem stakes and
    lifts in scallops between them; tension wrinkles run from each stake to the forks and
    the free side edges droop. Stakes are pale whittled wood, guy lines and hem ties
    thick enough to read at camp distance. The test bound (3 m inland of the fire) holds:
    nothing reaches in front of the ridge."""
    names = ["kit_bark", "kit_endgrain", "kit_canvas", "kit_rope", "kit_split"]
    b = K.MeshBuilder()
    bark, end, canvas, rope, split = 0, 0, 2, 3, 4  # thin poles: bark caps (one surface fewer)
    for s, seed in ((-1, 11), (1, 12)):
        branch_pole(b, (s * 1.03, .03, -.05), (s * 1.0, 0, 1.63), .05, .036, seed)
        for d, sd in ((1, 13), (-1, 14)):
            branch_pole(b, (s * 1.0, 0, 1.48), (s * (1.0 + .07 * d), -.05 * d, 1.76), .022, .014, seed * 10 + sd, segs=2, sides=4, crook=.01)

    def ridge_z(x):
        return 1.665 - .045 * math.sin(math.pi * max(0.0, min(1.0, (x + 1.0) / 2.0))) - .012 * (abs(x) > 1.0)
    ridge = [Vector((-1.32 + 2.64 * j / 8, .0, ridge_z(-1.32 + 2.64 * j / 8))) for j in range(9)]
    K.tube(b, ridge, [.045 - .008 * j / 8 for j in range(9)], bark, sides=8, cap_mat=end, wobble=.07, seed=15)
    for s in (-1, 1):
        K.wraps(b, (s * 1.0, 0, ridge_z(s * 1.0)), (1, 0, 0), .045, rope, turns=3, width=.05, thickness=.007, sides=4, seg=6)
    pegs_u = (0.0, 1 / 3, 2 / 3, 1.0)
    forks_u = ((1.17 - 1.0) / 2.34, (1.17 + 1.0) / 2.34)
    out = Vector((0, .68, .74)).normalized()  # outward normal of the slope (up and back)
    flap = [(-.1, -.32), (-.095, -.2), (-.085, -.08), (-.06, .02), (0.0, .05), (.06, .035)]  # (y, z over the ridge)

    def between(u):
        return abs(math.sin(3 * math.pi * u))

    def pt(u, s):
        x = -1.17 + 2.34 * u
        rz = ridge_z(x)
        sf = .2
        if s <= sf:  # the front flap over the ridge, hanging in folds
            t = s / sf * (len(flap) - 1)
            k = min(int(t), len(flap) - 2)
            f = t - k
            y = flap[k][0] + (flap[k + 1][0] - flap[k][0]) * f
            z = rz + flap[k][1] + (flap[k + 1][1] - flap[k][1]) * f
            hem = 1 - smooth(s / sf * 1.4)
            y -= .03 * (.5 + .5 * math.sin(u * 13 * math.pi + 1.3 + 2 * K.vnoise((u * 4, 0, 0), 1, 44))) * hem
            z += (.025 * math.sin(u * 7 * math.pi) + .02 * K.vnoise((u * 9, 0, 0), 1, 45)) * hem
            return Vector((x, y, z))
        t = (s - sf) / (1 - sf)
        f = between(u)
        crest = Vector((x, .06, rz + .035))
        hem = Vector((x, 1.84 - .09 * f, .05 + .14 * f))
        p = crest.lerp(hem, t)
        edge = 1 - smooth(min(u, 1 - u) / .12)
        depth = .24 * (.55 + .45 * math.sin(math.pi * u)) * math.sin(math.pi * t) ** .9
        depth += .11 * f * smooth(t / .7) * (1 - smooth((t - .85) / .15) * .6)  # troughs between stakes
        depth += (.14 + .03 * math.sin(t * 5 * math.pi)) * edge * math.sin(math.pi * t)  # free edges droop
        p -= out * depth
        # Tension wrinkles from each stake toward the nearer fork.
        w = 0.0
        for pu in pegs_u:
            fu = forks_u[0] if pu < .5 else forks_u[1]
            line_u = pu + (fu - pu) * (1 - t)
            d = (u - line_u) * 2.34
            w += .034 * math.exp(-(d / .06) ** 2) * math.sin(math.pi * min(1.0, t * 1.15)) * (.4 + .6 * t)
        p += out * w
        p.x -= math.copysign(.03 * edge * math.sin(math.pi * t), x)
        p += out * .008 * K.fbm((x, p.y, p.z), 2.5, 41)
        return p
    canvas_sheet(b, pt, 24, 18, 2.34, canvas)
    # Side wings: the canvas brought down each open side to the ground, bellying in
    # between the slope edge and its scalloped, staked foot, so the shelter reads as cloth
    # from the trail rather than a bare sloped sheet.
    for side_u, sgn in ((0.0, -1), (1.0, 1)):
        def wing(a, bb, side_u=side_u, sgn=sgn):
            e = pt(side_u, .2 + .8 * a)
            foot = Vector((e.x + sgn * .03, e.y + .03 * a, .03 + .05 * abs(math.sin(2.5 * math.pi * a))))
            p = e.lerp(foot, bb)
            belly = .08 * math.sin(math.pi * bb) * math.sin(math.pi * min(1.0, a * 1.25))
            p.x -= sgn * (belly + .012 * K.fbm((p.x, p.y * 1.5, p.z * 1.5), 3, 47 + int(side_u)))
            return p
        canvas_sheet(b, wing, 10, 6, 1.8, canvas)
        foot = Vector((sgn * 1.26, .12, 0))
        top = stake(b, foot, (sgn, -.3, .25), 75 + int(side_u), split, end, height=.24)
        K.rope(b, (sgn * 1.17, .07, .06), top + Vector((0, 0, -.03)), rope, radius=.007, sag=.01, n=3, sides=4)
    # Stakes along the hem with short ties; guy lines from the ridge ends to side stakes.
    for k, u in enumerate(pegs_u):
        x = -1.17 + 2.34 * u
        foot = Vector((x * 1.04, 2.04, 0))
        top = stake(b, foot, (0, -1, .2), 60 + k, split, end)
        K.rope(b, pt(u, 1.0), top + Vector((0, .02, -.03)), rope, radius=.008, sag=.012, n=4, sides=4)
    for s in (-1, 1):
        foot = Vector((s * 1.95, .55, 0))
        top = stake(b, foot, (-s, 0, .25), 70 + s, split, end, height=.3)
        K.rope(b, (s * 1.30, 0, ridge_z(s * 1.3) + .02), top + Vector((0, 0, -.03)), rope, radius=.008, sag=.05, n=8, sides=4)
    return save(b, "lean_to", names)


# ------------------------------------------------------------------ bedroll

def annulus(b, center, axis_x, r0, r1, mat, sides=12, flip=False):
    """A flat ring in the y-z plane at center (end of a roll seen along x)."""
    c = Vector(center)
    outer = [b.vert(c + Vector((0, math.cos(math.tau * k / sides) * r1, math.sin(math.tau * k / sides) * r1))) for k in range(sides)]
    inner = [b.vert(c + Vector((0, math.cos(math.tau * k / sides) * r0, math.sin(math.tau * k / sides) * r0))) if r0 > 0 else None for k in range(sides)]
    for k in range(sides):
        k2 = (k + 1) % sides
        uv = [(k / sides, 1), (k2 / sides, 1), (k2 / sides, 0), (k / sides, 0)]
        if r0 > 0:
            q = [outer[k], outer[k2], inner[k2], inner[k]]
        else:
            q = [outer[k], outer[k2], b.vert(c)]
            uv = uv[:3]
        if flip:
            q, uv = q[::-1], uv[::-1]
        b.face(q, uv, mat, True)


def bedroll():
    """A miner's bed by day: canvas ground cloth, the blankets rolled tight across its
    head and strapped (red wool outside, a striped trade blanket inside, layers showing
    at the ends), and a rolled coat behind for a pillow. The head faces the fire."""
    names = ["kit_canvas", "kit_wool", "kit_rope", "kit_blanket", "kit_leather"]
    b = K.MeshBuilder()
    canvas, wool, rope, blanket, leather = 0, 1, 2, 3, 4
    nx, ny = 6, 10
    g = [[b.vert((-.45 + .9 * i / nx + .012 * K.vnoise((i, j, 2), .8, 7),
                  -.98 + 1.96 * j / ny,
                  .006 + .01 * max(0, K.vnoise((i, j, 0), .9, 5)) + (.03 if i in (0, nx) or j in (0, ny) else 0) * max(0, K.vnoise((i, j, 1), .7, 6))), .72)
          for i in range(nx + 1)] for j in range(ny + 1)]
    for j in range(ny):
        for i in range(nx):
            b.face([g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i]],
                   [(.9 * i / nx, 1.96 * j / ny), (.9 * (i + 1) / nx, 1.96 * j / ny), (.9 * (i + 1) / nx, 1.96 * (j + 1) / ny), (.9 * i / nx, 1.96 * (j + 1) / ny)], canvas)
    # A grey-red wool blanket thrown loosely over the foot of the cloth.
    nx, ny = 8, 6
    w = []
    for j in range(ny + 1):
        y = -.92 + .7 * j / ny
        row = []
        for i in range(nx + 1):
            u = i / nx
            x = -.42 + .84 * u
            z = .02 + .05 * math.sin(math.pi * u) ** .7 * (1 - .4 * j / ny) + .02 * K.fbm((x, y, 0), 4.0, 21)
            if i in (0, nx):
                z -= .018
            row.append(b.vert((x + .015 * K.vnoise((x, y, 3), 5, 22), y, z), .65 + .35 * min(1.0, z / .06)))
        w.append(row)
    for j in range(ny):
        for i in range(nx):
            b.face([w[j][i], w[j][i + 1], w[j + 1][i + 1], w[j + 1][i]],
                   [(.84 * i / nx, .7 * j / ny), (.84 * (i + 1) / nx, .7 * j / ny), (.84 * (i + 1) / nx, .7 * (j + 1) / ny), (.84 * i / nx, .7 * (j + 1) / ny)], wool)
    # The roll: red wool outside; the ends show the wound layers (wool, blanket, wool).
    y0, z0, R, half = .64, .125, .12, .38
    pts = [Vector((-half + 2 * half * k / 6, y0 + .01 * math.sin(k * 1.3), z0 - .006 * math.sin(math.pi * k / 6))) for k in range(7)]
    K.tube(b, pts, [R * (1 - .06 * math.cos(math.pi * k / 3)) for k in range(7)], wool, sides=14, tile=.8, wobble=.05, seed=23)
    for e, x in ((0, -half), (1, half)):
        rings = [(R * .94, R, wool), (R * .7, R * .94, blanket), (R * .45, R * .7, wool), (R * .2, R * .45, blanket), (0, R * .2, wool)]
        for k, (r0, r1, mat) in enumerate(rings):
            annulus(b, (x + (-1 if e else 1) * .006 * k, y0, z0), 1, r0, r1, mat, sides=14, flip=(e == 0))
    for x in (-.2, .2):
        K.wraps(b, (x, y0, z0), (1, 0, 0), R * 1.0, leather, turns=1, width=.035, thickness=.008, sides=4, seg=14)
    # Rolled coat as a pillow, tied twice, behind the blankets.
    roll = [Vector((-.3 + .6 * k / 4, .3, .1)) for k in range(5)]
    K.tube(b, roll, .09, canvas, sides=10, tile=1.0, cap_mat=wool, wobble=.06, seed=24)
    for x in (-.16, .16):
        K.wraps(b, (x, .3, .1), (1, 0, 0), .09, rope, turns=2, width=.025, thickness=.006, sides=4, seg=10)
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
    """A cord of split wood seasoning between two pairs of stakes, with a few unsplit
    rounds and kindling beside it (Wave C: twice the old pile)."""
    names = ["kit_bark", "kit_split", "kit_endgrain"]
    b = K.MeshBuilder()
    rng = random.Random(77)
    for layer in range(6):
        n = 9 - layer // 3
        for k in range(n):
            y = -.62 + 1.24 * (k + .5) / n + rng.uniform(-.02, .02)
            r = rng.uniform(.07, .09)
            a0 = rng.uniform(0, math.tau)
            split_piece(b, (rng.uniform(-.05, .05), y, layer * .145 - .02), rng.uniform(.6, .72), r, a0,
                        a0 + rng.choice((math.pi / 2, 2 * math.pi / 3, math.pi)), rng.uniform(-.06, .06), 700 + layer * 10 + k, 0, 1, 2)
    for s in (-1, 1):
        for x in (-.12, .12):
            branch_pole(b, (x, s * .7, -.05), (x * 1.1, s * .73, .95), .03, .024, 790 + s * 3 + int(x * 10), segs=3, sides=6, crook=.01, end=2)
    # Unsplit rounds on end and lying, and a scatter of kindling.
    for k, (x, y, up) in enumerate(((.62, -.35, True), (.6, .1, True), (.75, .5, False))):
        if up:
            K.lathe(b, [(.15, 0), (.155, .02), (.15, .34)], 0, sides=10, tile=1.0, center=(x, y, 0), wobble=.06, seed=780 + k)
            K.lathe(b, [(.15, .34), (0, .345)], 2, sides=10, tile=.4, center=(x, y, 0))
        else:
            K.tube(b, [Vector((x - .25, y, .15)), Vector((x + .25, y + .05, .15))], .15, 0, sides=10, cap_mat=2, wobble=.06, seed=785)
    for k in range(7):
        a = rng.uniform(0, math.tau)
        c = Vector((.45 + rng.uniform(-.1, .25), rng.uniform(-.6, .6), .015))
        d = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(.12, .22)
        K.tube(b, [c - d, c + d], .012, 1, sides=4, tile=.4)
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
    """Cook gear by the fire: a tall tin coffee pot, a cast-iron Dutch oven with its
    flanged lid, legs and bail, a stack of tin plates and tin cups."""
    names = ["kit_iron", "kit_tin"]
    b = K.MeshBuilder()
    iron, tin = 0, 1
    # Tin coffee pot (conical, soldered seams), lid knob, spout and strap handle.
    c = Vector((-.12, .06, 0))
    K.lathe(b, [(0, 0), (.085, 0), (.09, .01), (.075, .2), (.06, .23), (.064, .235), (.045, .25), (.012, .26), (.016, .275), (0, .28)],
            tin, sides=10, tile=.3, center=tuple(c))
    K.tube(b, [c + Vector((.07, 0, .05)), c + Vector((.11, 0, .13)), c + Vector((.15, 0, .2)), c + Vector((.165, 0, .215))],
           [.018, .014, .009, .009], tin, sides=6, tile=.2)
    K.tube(b, [c + Vector((-.07, 0, .2)), c + Vector((-.13, 0, .19)), c + Vector((-.135, 0, .11)), c + Vector((-.082, 0, .06))],
           .009, tin, sides=4, tile=.2)
    # Dutch oven: three stub legs, a bellied pot, the flanged lid (coals sit on it), bail.
    d = Vector((.24, -.12, .045))
    for k in range(3):
        a = math.tau * k / 3 + .5
        K.tube(b, [d + Vector((math.cos(a) * .1, math.sin(a) * .1, .01)), d + Vector((math.cos(a) * .11, math.sin(a) * .11, -.045))], .014, iron, sides=5, tile=.2)
    K.lathe(b, [(0, 0), (.12, 0), (.15, .02), (.16, .07), (.158, .11), (.165, .115)], iron, sides=12, tile=.4, center=tuple(d))
    K.lathe(b, [(.168, .112), (.172, .118), (.15, .13), (.15, .145), (.13, .15), (0, .155)], iron, sides=12, tile=.4, center=tuple(d))
    K.tube(b, [d + Vector((-.03, 0, .158)), d + Vector((-.02, 0, .19)), d + Vector((.02, 0, .19)), d + Vector((.03, 0, .158))], .008, iron, sides=4, tile=.1)
    # The bail folded down over one side of the lid.
    bail = [d + Vector((math.cos(math.pi * k / 10) * .172, -math.sin(math.pi * k / 10) * .15, .1 + math.sin(math.pi * k / 10) * .055)) for k in range(11)]
    K.tube(b, bail, .005, iron, sides=4, tile=.1)
    # Tin plates stacked, one leaning on the stack; tin cups, one tipped over.
    p0 = Vector((-.08, -.3, 0))
    for k in range(4):
        K.lathe(b, [(0, 0), (.09, 0), (.115, .016), (.112, .019), (.087, .004), (0, .004)], tin, sides=10, tile=.2,
                center=tuple(p0 + Vector((.004 * k, -.003 * k, .009 * k))))
    for k, (x, y) in enumerate(((.12, .22), (.3, .16))):
        K.lathe(b, [(0, 0), (.04, 0), (.044, .085), (.04, .085), (.036, .006), (0, .006)], tin, sides=9, tile=.2, center=(x, y, 0))
        K.tube(b, [Vector((x + .042, y, .07)), Vector((x + .07, y, .06)), Vector((x + .07, y, .03)), Vector((x + .043, y, .02))], .005, tin, sides=4, tile=.1)
    first = len(b.v)
    K.lathe(b, [(0, 0), (.04, 0), (.044, .085), (.04, .085), (.036, .006), (0, .006)], tin, sides=9, tile=.2)
    tip = Matrix.Rotation(math.pi / 2 - .1, 3, "Y")
    for i in range(first, len(b.v)):
        b.v[i] = Vector((-.32, -.06, .044)) + tip @ (b.v[i] - Vector((0, 0, .042)))
    b.dirt(lambda p: .6 + .4 * min(1.0, p.z / .2))
    return save(b, "coffee", names)


def fire_ring():
    """Wave C: a ring of ten separate river cobbles round a bed of ash and charcoal.
    The cobbles are one normalised Poly Haven scan (stone_01: normalize_asset.py to 240
    tris and 512 maps with tint 0.55,0.53,0.49,0.6, written to
    <cache>/generated/fire_stone/fire_stone.glb), copied with seeded size, stretch, yaw
    and tilt, packed end to end and sunk a third into the ground. Soot is vertex colour:
    the faces toward the fire are blackened, and each stone gets its own tone (camp.gd
    turns vertex colour on for the stone surface). One mesh, two surfaces (stone, kit_ash);
    everything stays inside camp.glb FireRing's collision hull (radius 0.72)."""
    from mathutils import Matrix as Mx
    path = K.cache_root() / "generated" / "fire_stone" / "fire_stone.glb"
    if not path.exists():
        raise SystemExit("normalise the fire stone first (see fire_ring's docstring)")
    bpy.ops.import_scene.gltf(filepath=str(path))
    src = next(o for o in bpy.context.selected_objects if o.type == "MESH")
    src.data.materials[0].name = "fire_stone"
    rng = random.Random(1101)
    n, ring_r = 10, .52
    sizes = []
    for k in range(n):
        sc = rng.uniform(1.75, 2.5)
        sizes.append((sc * rng.uniform(.82, 1.08), sc * rng.uniform(1.0, 1.3), sc * rng.uniform(1.25, 1.7)))
    lengths = [.142 * s[0] for s in sizes]
    total = sum(lengths)
    gap = (math.tau * ring_r - total) / n  # spread the slack evenly (negative: overlap a little)
    stones = []
    a = rng.uniform(0, math.tau)
    for k in range(n):
        o = src.copy()
        o.data = src.data.copy()
        bpy.context.collection.objects.link(o)
        a += (lengths[k] / 2 + (lengths[k - 1] / 2 if k else 0) + (gap if k else 0)) / ring_r
        r = ring_r + rng.uniform(-.02, .04)
        o.scale = sizes[k]
        # Long axis (x) along the ring; lean in or out a little, roll about the long axis.
        # Small tilts only: the scan's cut base must stay in the ground.
        o.rotation_euler = (rng.uniform(-.12, .12), rng.uniform(-.12, .12), a + math.pi / 2 + rng.uniform(-.3, .3))
        o.location = (math.cos(a) * r, math.sin(a) * r, -.071 * sizes[k][2] * rng.uniform(.3, .42))
        stones.append(o)
    bpy.data.objects.remove(src)
    bpy.context.view_layer.update()
    for k, o in enumerate(stones):
        tone = rng.uniform(.72, 1.0)
        col = o.data.color_attributes.new(name="Color", type="BYTE_COLOR", domain="POINT")
        mw = o.matrix_world
        for i, v in enumerate(o.data.vertices):
            p = mw @ v.co
            d = math.hypot(p.x, p.y)
            inward = smooth((ring_r - .02 - d) / .1)  # only the faces toward the fire, softly
            g = tone * (1 - .5 * inward) * (.85 + .15 * smooth(p.z / .12))
            col.data[i].color = (g, g, g, 1)
        o.data.color_attributes.active_color = col
    # The ash bed: a low irregular disc, mounded a little, charcoal cells in its texture.
    b = K.MeshBuilder()
    rings = []
    for j in range(5):
        rr = .43 * j / 4
        ring = []
        for k in range(20 if j else 1):
            ang = math.tau * k / 20
            rad = rr * (1 + .08 * K.vnoise((math.cos(ang) * 2, math.sin(ang) * 2, 0), 1.5, 1102))
            z = .035 * (1 - (j / 4) ** 2) + .006 * K.vnoise((math.cos(ang) * rad * 8, math.sin(ang) * rad * 8, 1), 1, 1103) - .004
            ring.append(b.vert((math.cos(ang) * rad, math.sin(ang) * rad, z), .75))
        rings.append(ring)
    for j in range(1, 5):
        for k in range(20):
            k2 = (k + 1) % 20
            inner = rings[j - 1]
            if j == 1:
                q = [inner[0], rings[j][k], rings[j][k2]]
            else:
                q = [inner[k], rings[j][k], rings[j][k2], inner[k2]]
            b.face(q, [(b.v[v].x / .4 + .5, b.v[v].y / .4 + .5) for v in q], 0)
    bed = b.build("fire_ring", [K.placeholder("kit_ash")])
    bpy.ops.object.select_all(action="DESELECT")
    for o in stones + [bed]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = bed
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    K.export_glb([bed], OUT / "fire_ring.glb", images=True)
    return bed


def flames():
    """Fire for when it burns (camp.gd shows it): crossed flame ribbons and a heap of
    coals, drawn by shaders/fire.gdshader. COLOR carries each ribbon's phase."""
    b = K.MeshBuilder()
    rng = random.Random(1201)
    for k in range(9):
        a = rng.uniform(0, math.pi)
        off = rng.uniform(.03, .15)
        oa = math.tau * k / 9 + rng.uniform(-.3, .3)
        base = Vector((math.cos(oa) * off, math.sin(oa) * off, .03))
        w, h = rng.uniform(.1, .18), rng.uniform(.3, .68)
        side = Vector((math.cos(a), math.sin(a), 0))
        normal = Vector((-math.sin(a), math.cos(a), 0))
        bend = rng.uniform(-.06, .06)
        phase = k / 9
        cols = 3
        ids = []
        for j in range(7):
            t = j / 6
            row = []
            for i in range(cols):
                s = i / (cols - 1) - .5
                p = base + side * s * w * (1 - .55 * t) + normal * bend * t * t + Vector((0, 0, h * t))
                row.append(b.vert(p, phase))
            ids.append(row)
        for j in range(6):
            for i in range(cols - 1):
                b.face([ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]],
                       [(i / (cols - 1), j / 6), ((i + 1) / (cols - 1), j / 6), ((i + 1) / (cols - 1), (j + 1) / 6), (i / (cols - 1), (j + 1) / 6)], 0)
    fire = bpy.data.materials.new("fire_tongue")
    tongues = b.build("Tongues", [fire])
    b = K.MeshBuilder()
    for k in range(12):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0, .22)
        c = (math.cos(a) * rr, math.sin(a) * rr, .045 + .025 * (1 - rr / .22))
        s = rng.uniform(.03, .055)
        K.lathe(b, [(0, -s * .5), (s * .9, -s * .3), (s, .0), (s * .7, s * .4), (0, s * .55)], 0, sides=5, tile=.1, center=c,
                wobble=.25, seed=1210 + k)
    coals = b.build("Coals", [bpy.data.materials.new("fire_coals")])
    K.export_glb([tongues, coals], OUT / "flames.glb")


def tent():
    """Wave C: the canvas A tent the crew sleep in and the miner can buy, seen in place
    of assets/expedition/tent.glb (still the collision, hidden; camp.gd tent_instance).
    Same frame: ridge 1.7 m, hem 1.12 m either side, 2.7 m long, open end toward -Y.
    The slopes sag between ridge and hem and trough between the pegs; the door flaps are
    rolled back and tied; guy lines run from the ridge ends to stakes fore and aft."""
    names = ["kit_bark", "kit_endgrain", "kit_canvas", "kit_rope", "kit_split"]
    b = K.MeshBuilder()
    bark, end, canvas, rope, split = 0, 0, 2, 3, 4
    L, W, H = 1.35, 1.12, 1.7

    def ridge_z(y):
        return H - .06 * math.sin(math.pi * (y + L) / (2 * L))
    for y in (-L, L):
        branch_pole(b, (0, y, -.04), (0, y, H + .04), .03, .026, 1300 + int(y * 10), segs=4, sides=6, crook=.01)
    K.tube(b, [Vector((0, -L - .1 + (2 * L + .2) * k / 6, ridge_z(-L + 2 * L * k / 6) + .03)) for k in range(7)], .03, bark,
           sides=6, cap_mat=end, wobble=.05, seed=1310)
    pegs = (0.0, 1 / 3, 2 / 3, 1.0)
    out_n = Vector((1.7, 0, 1.12)).normalized()

    for s in (-1, 1):
        def pt(u, t, s=s):
            y = -L + 2 * L * u
            f = abs(math.sin(3 * math.pi * u))
            top = Vector((0, y, ridge_z(y) + .015))
            hem = Vector((s * (W + .02 * f), y, .08 + .07 * f))
            p = top.lerp(hem, t)
            n = Vector((s * out_n.x, 0, out_n.z))
            depth = .11 * math.sin(math.pi * t) * (.5 + .5 * math.sin(math.pi * u)) + .08 * f * smooth(t / .8)
            w = 0.0
            for pu in pegs:
                line_u = pu + (.5 - pu) * (1 - t) * .5
                w += .028 * math.exp(-(((u - line_u) * 2 * L) / .06) ** 2) * math.sin(math.pi * min(1.0, t * 1.1))
            p += n * (w - depth)
            p += n * .006 * K.fbm((p.x, p.y, p.z), 3, 1320 + s)
            return p
        grid = [[pt(i / 12, j / 8) for i in range(13)] for j in range(9)]
        ids = [[b.vert(p, .55 + .45 * min(1.0, p.z / .6)) for p in row] for row in grid]
        for j in range(8):
            for i in range(12):
                q = [ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]]
                uv = [(2.7 * i / 12, 1.9 * j / 8), (2.7 * (i + 1) / 12, 1.9 * j / 8), (2.7 * (i + 1) / 12, 1.9 * (j + 1) / 8), (2.7 * i / 12, 1.9 * (j + 1) / 8)]
                if s > 0:
                    q, uv = q[::-1], uv[::-1]
                b.face(q, uv, canvas)
        # Stakes and short ties along the hem.
        for k, u in enumerate(pegs):
            hem = grid[8][round(u * 12)]
            top = stake(b, Vector((s * (W + .28), hem.y, 0)), (-s, 0, .2), 1330 + k + (10 if s > 0 else 0), split, end, height=.24)
            K.rope(b, hem, top + Vector((0, 0, -.03)), rope, radius=.007, sag=.01, n=3, sides=3)
        # The door flap on this side, rolled back to the front slope edge and tied.
        roll = [grid[j][0] + Vector((s * .03, -.03, 0)) for j in range(1, 9)]
        K.tube(b, roll, [.018 + .03 * (j / 7) ** 1.5 for j in range(8)], canvas, sides=6, tile=.8, wobble=.35, seed=1340 + s)
        mid = roll[3]
        K.wraps(b, mid, (roll[4] - roll[2]).normalized(), .05, rope, turns=2, width=.025, thickness=.006, sides=3, seg=8)
    # Rear wall: a triangle of canvas bellied inward a little.
    rows = 6
    rear = []
    for j in range(rows + 1):
        t = j / rows
        z = H - .03 - (H - .1) * t
        half = W * t
        row = []
        for i in range(5):
            u = i / 4
            x = -half + 2 * half * u
            row.append(b.vert((x, L + .01 - .05 * math.sin(math.pi * u) * math.sin(math.pi * t), z), .55 + .45 * min(1.0, z / .6)))
        rear.append(row)
    for j in range(rows):
        for i in range(4):
            q = [rear[j][i], rear[j][i + 1], rear[j + 1][i + 1], rear[j + 1][i]]
            b.face(q, [(i / 4, j / rows), ((i + 1) / 4, j / rows), ((i + 1) / 4, (j + 1) / rows), (i / 4, (j + 1) / rows)], canvas)
    # Guy lines from the ridge ends to stakes fore and aft.
    for y in (-1, 1):
        top = stake(b, Vector((0, y * (L + .75), 0)), (0, -y, .25), 1350 + y, split, end, height=.28)
        K.rope(b, (0, y * (L + .08), ridge_z(y * L) + .05), top + Vector((0, 0, -.03)), rope, radius=.008, sag=.05, n=6, sides=4)
    return save(b, "tent", names)


def notice():
    """The crew's claim notice (crew.gd): a paper sheet nailed to a weathered board on a
    peeled post, under two shakes. Two objects: Post (post, board, shakes, nails) and
    Paper; the Label3D sits on the paper's face (Godot -Z, 1.12 m up)."""
    names = ["kit_bark", "kit_endgrain", "kit_wood", "kit_iron", "kit_paper"]
    b = K.MeshBuilder()
    branch_pole(b, (0, 0, -.1), (.01, .0, 1.62), .05, .042, 1401, segs=5, sides=7, crook=.012)
    for k in range(3):  # three boards, face toward Godot -Z (Blender +Y)
        plank_c = Vector((0, .07, 1.0 + .19 * k))
        K.box(b, plank_c, (.7, .025, .18), 2, tile=.9, grain=0, uv_offset=(k * 1.7, k * .9))
    for s in (-1, 1):  # two shakes over the top
        K.box(b, Vector((0, .07 + s * .07, 1.53)), (.8, .16, .018), 2, tile=.9, grain=0, rot=Matrix.Rotation(-s * .5, 3, "X"))
    for x in (-.21, .21):
        for z in (.94, 1.3):
            K.box(b, (x, .0875, z), (.012, .006, .012), 3, tile=.05)
    post = b.build("Post", [K.placeholder(n) for n in names])
    b = K.MeshBuilder()
    nx, nz = 6, 6
    ids = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            x, z = -.25 + .5 * i / nx, .93 + .4 * j / nz
            curl = .012 * max(0.0, 1 - (i / nx) * 1.6) * max(0.0, 1 - j / nz * 2.2) + .004 * K.vnoise((x, z, 0), 9, 1402)
            row.append(b.vert((x, .084 + curl, z), .85))
        ids.append(row)
    for j in range(nz):
        for i in range(nx):
            q = [ids[j][i + 1], ids[j][i], ids[j + 1][i], ids[j + 1][i + 1]]
            b.face(q, [((i + 1) / nx * .5, j / nz * .4), (i / nx * .5, j / nz * .4), (i / nx * .5, (j + 1) / nz * .4), ((i + 1) / nx * .5, (j + 1) / nz * .4)], 0)
    paper = b.build("Paper", [K.placeholder("kit_paper")])
    K.export_glb([post, paper], OUT / "notice.glb")


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
    for build in (lean_to, bedroll, pot, skillet, rack, fish_strips, cache, firewood, woodpile, embers, coffee, ledger, chopping_block,
                  fire_ring, flames, tent, notice):
        if not wanted or build.__name__ in wanted:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            globals()["M"] = mats()
            build()
    print("BUILT camp kit")
