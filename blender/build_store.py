"""Lambert's store: the stall (store.glb) and the shelf goods (goods.glb).

  blender --background --python blender/build_store.py

Stage 6 rebuild on the shared kit materials of blender/prop_kit.py: bark log walls
with end grain and clay chinking, hewn counter and shelves, a canvas roof on rafters,
a brass balance, and sacks, tubs, packets, coils and bundles for the goods. Layout is
the Milestone 10 layout (scripts/store_layout.gd), unchanged. Seeds are explicit.

Names the game relies on: `Scale*`, `Pan*`, `Beam`, `Weight*` (store.gd animates the
beam and weights about their object origins; the coverage probe reads the prefixes),
`Counter*` (the counter, for the coverage probe) and `* proxy`: the original log-wall
and counter meshes, rebuilt exactly as before, which store.gd hides and uses only for
collision, so the walkable space is unchanged. Goods are named <item>[_<fill>] as
scripts/shelves.gd looks them up. assets/miner/rod.glb is no longer written here.
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prop_kit as K  # noqa: E402
from prop_kit import gd  # noqa: E402

OUT = K.ASSETS / "store"


class Kit:
    def __init__(self, names):
        self.names = names
        self.mats = [K.placeholder(n) for n in names]

    def __getattr__(self, item):
        return self.names.index("kit_" + item)


def obj(b, name, kit, pivot=None):
    if pivot is not None:
        pv = Vector(pivot)
        b.v = [p - pv for p in b.v]
    o = b.build(name, kit.mats)
    if pivot is not None:
        o.location = pv
    return o


# ------------------------------------------------------------------ legacy collision proxies

def legacy_proxies():
    """The Milestone 10 log walls and counter, exactly as built before (collision only)."""
    rng = random.Random(184810)

    def coord(p):
        return (p[0], -p[2], p[1])

    def cylinder(name, a, b_, r, vertices=10):
        a, b_ = Vector(coord(a)), Vector(coord(b_))
        d = b_ - a
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=r, depth=d.length, location=(a + b_) / 2)
        o = bpy.context.object
        o.name = name
        o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
        return o

    def cube(name, p, size):
        bpy.ops.mesh.primitive_cube_add(size=1, location=coord(p))
        o = bpy.context.object
        o.name = name
        o.scale = coord((size[0], size[1], -size[2]))
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bevel = o.modifiers.new('Worn corners', 'BEVEL')
        bevel.width = .008
        bevel.segments = 1
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        return o
    out = []
    for i in range(7):
        out.append(cylinder('Back log proxy', (-2.5, .18 + i * .25, -2.3), (2.5, .18 + i * .25, -2.3), .14 + rng.random() * .012))
    for x in [-2.6, 2.6]:
        for i in range(6):
            out.append(cylinder('Side log proxy', (x, .16 + i * .26, -2.3), (x, .16 + i * .26, -1.25), .14))
    for x in [-1.35, 1.35]:
        out.append(cube('Counter leg proxy', (x, .48, 0), (.14, .96, .64)))
    out.append(cube('Counter proxy', (0, 1.0, 0), (3.2, .13, .85)))
    # Triangulate the cylinder caps (same planar surfaces) so tangents, and so the
    # exported bytes, are deterministic.
    import bmesh
    for o in out:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        bm.to_mesh(o.data)
        bm.free()
        # The bevel leaves its new faces' UVs undefined; proxies are never textured.
        for layer in o.data.uv_layers:
            for item in layer.data:
                item.uv = (0.0, 0.0)
    return out


# ------------------------------------------------------------------ stall

def log(b, kit, a, c, r, seed, sides=10):
    a, c = Vector(a), Vector(c)
    pts = [a.lerp(c, t / 6) for t in range(7)]
    rng = random.Random(seed)
    for j, p in enumerate(pts):
        t = j / 6
        p.z -= .012 * math.sin(math.pi * t) * rng.uniform(.5, 1.5)
    radii = [r * (1.04 - .08 * j / 6) for j in range(7)]
    return K.tube(b, pts, radii, kit.bark, sides=sides, tile=1.0, cap_mat=kit.endgrain, wobble=.07, seed=seed,
                  u_offset=rng.random(), dirt=lambda q: .62 + .38 * min(1.0, q.z / .5))


def pole(b, kit, a, c, r0, r1, seed, sides=8, segs=6, crook=.025):
    a, c = Vector(a), Vector(c)
    rng = random.Random(seed)
    d = (c - a)
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    ph = rng.random() * 6
    pts = [a.lerp(c, t / segs) + side * crook * math.sin(math.pi * t / segs + ph) for t in range(segs + 1)]
    return K.tube(b, pts, [r0 + (r1 - r0) * t / segs for t in range(segs + 1)], kit.bark, sides=sides, tile=1.0,
                  cap_mat=kit.endgrain, wobble=.06, seed=seed, dirt=K.ground_dirt(.55, .4))


def plank(b, kit, center, size, axis, seed, mat=None, tile=1.6):
    """A sawn board; `axis` is its long Blender axis. Each board takes its own strip of the texture."""
    rng = random.Random(seed)
    off = (rng.random() * 6, rng.random() * 6)
    return K.box(b, center, size, kit.wood if mat is None else mat, tile=tile, grain=axis, uv_offset=off)


def stall():
    kit = Kit(["kit_bark", "kit_endgrain", "kit_wood", "kit_daub", "kit_canvas", "kit_rope", "kit_iron", "kit_brass",
               "kit_slate", "kit_leather", "kit_paper", "kit_wool", "kit_cotton"])
    objs = legacy_proxies()

    # Log walls: overhanging saddle-notched corners; side logs ride half a log higher.
    b = K.MeshBuilder()
    for i in range(7):
        log(b, kit, gd(-2.8, .18 + i * .25, -2.3), gd(2.8, .18 + i * .25, -2.3), .135, 300 + i)
    for s in (-1, 1):
        for i in range(6):
            y = .305 + i * .25
            log(b, kit, gd(s * 2.6, y, -2.48), gd(s * 2.6, y, -1.08), .13, 320 + i + (10 if s > 0 else 0))
    objs.append(obj(b, "Log walls", kit))
    b = K.MeshBuilder()
    K.box(b, gd(0, .9, -2.3), (5.3, .06, 1.75), kit.daub, tile=1.2)
    for s in (-1, 1):
        K.box(b, gd(s * 2.6, 1.0, -1.75), (.06, 1.0, 1.65), kit.daub, tile=1.2)
    objs.append(obj(b, "Chinking", kit))

    # Posts, plates, rafters and ridge.
    b = K.MeshBuilder()
    for k, (x, z) in enumerate(((-2.6, -2.3), (2.6, -2.3), (-2.6, 1.0), (2.6, 1.0))):
        pole(b, kit, gd(x, -.05, z), gd(x + .02, 2.9, z), .095, .08, 400 + k)
    for s in (-1, 1):
        pole(b, kit, gd(s * 2.68, 2.86, -2.62), gd(s * 2.68, 2.84, 1.3), .065, .058, 410 + s, segs=8, crook=.02)
    for k, z in enumerate((-2.5, 1.18)):
        for s in (-1, 1):
            pole(b, kit, gd(s * 2.75, 2.8, z), gd(-s * .12, 3.47, z), .055, .05, 420 + k * 2 + s, segs=5, crook=.015)
    pole(b, kit, gd(0, 3.42, -2.72), gd(0, 3.42, 1.42), .07, .06, 430, segs=8, crook=.02)
    pole(b, kit, gd(0, -.05, -2.55), gd(0, 3.4, -2.55), .085, .075, 431, segs=6, crook=.03)
    for s in (-1, 1):
        for z in (-2.5, 1.18):
            K.wraps(b, gd(s * .02, 3.42, z), (0, 1, 0), .07, kit.rope, turns=2, width=.06, thickness=.007, sides=4, seg=6)
    objs.append(obj(b, "Frame", kit))

    # Canvas roof: two sheets from the ridge to the eaves, sagging between the rafters.
    for s in (-1, 1):
        b = K.MeshBuilder()
        nu, nv = 10, 16
        rows = []
        for j in range(nv + 1):
            t = j / nv
            z = -2.78 + 4.28 * t
            row = []
            for i in range(nu + 1):
                u = i / nu
                x = s * (.04 + 2.86 * u)
                y = 3.49 - 2.86 * u * .245
                between = 0.0
                if -2.5 < z < 1.18:
                    between = math.sin(math.pi * (z + 2.5) / 3.68)
                y -= .16 * between * math.sin(math.pi * min(1.0, u * 1.08)) ** .8
                if z > 1.18:
                    y -= .05 * (z - 1.18) / .32 * u
                y += .012 * K.fbm((x, y, z), 1.6, 70 + s)
                p = gd(x, y, z)
                row.append(b.vert(p, .8 + .2 * (1 - u)))
            rows.append(row)
        for j in range(nv):
            for i in range(nu):
                q = [rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]]
                uv = [(2.9 * i / nu, 4.28 * j / nv), (2.9 * (i + 1) / nu, 4.28 * j / nv), (2.9 * (i + 1) / nu, 4.28 * (j + 1) / nv), (2.9 * i / nu, 4.28 * (j + 1) / nv)]
                if s > 0:
                    q, uv = q[::-1], uv[::-1]
                b.face(q, uv, kit.canvas)
        objs.append(obj(b, "Canvas roof" + ("" if s < 0 else " east"), kit))
    # Guy lines from the eave corners to pegs.
    b = K.MeshBuilder()
    for s in (-1, 1):
        for z, dz in ((1.45, .75), (-2.75, -.7)):
            peg = gd(s * 3.45, 0, z + dz)
            pole(b, kit, peg + Vector((0, 0, -.06)), peg + Vector((s * .04, 0, .26)), .025, .018, 440 + int(z), sides=5, segs=2, crook=0)
            K.rope(b, gd(s * 2.9, 2.72, z), peg + Vector((s * .04, 0, .23)), kit.rope, radius=.006, sag=.04, n=8, sides=4)
    objs.append(obj(b, "Guy lines", kit))

    # Canvas sign hung between the front posts (the Label3D sits at z = 1.09).
    b = K.MeshBuilder()
    nu = 10
    top, bot = [], []
    for i in range(nu + 1):
        u = i / nu
        x = -1.75 + 3.5 * u
        sag = .015 * math.sin(math.pi * u)
        top.append(b.vert(gd(x, 3.12 - sag, 1.06 + .004 * math.sin(i * 1.7)), 1))
        bot.append(b.vert(gd(x, 2.80 - sag * 1.6, 1.065 + .004 * math.sin(i * 2.3)), .9))
    for i in range(nu):
        b.face([bot[i], bot[i + 1], top[i + 1], top[i]], [(3.5 * i / nu, 0), (3.5 * (i + 1) / nu, 0), (3.5 * (i + 1) / nu, .32), (3.5 * i / nu, .32)], kit.canvas)
    for s in (-1, 1):
        for y in (3.1, 2.82):
            K.rope(b, gd(s * 1.75, y, 1.06), gd(s * 2.55, y + .04, 1.0), kit.rope, radius=.006, sag=.02, n=5, sides=4)
    objs.append(obj(b, "Canvas sign", kit))

    # Counter: three planks on a hewn frame, boarded front.
    b = K.MeshBuilder()
    for k, z in enumerate((-.28, 0, .28)):
        plank(b, kit, gd(0, 1.037, z), (3.26, .27, .05), 0, 500 + k)  # top at 1.062, just under the legacy 1.065
    for z in (-.36, .36):
        plank(b, kit, gd(0, .96, z), (3.1, .1, .1), 0, 510 + int(z * 10))
    for x in (-1.4, 1.4):
        for z in (-.3, .3):
            plank(b, kit, gd(x, .46, z), (.11, .11, .96), 2, 520 + int(x * 10 + z * 10))
        plank(b, kit, gd(x, .2, 0), (.08, .62, .08), 1, 530 + int(x * 10))
    objs.append(obj(b, "Counter top", kit))
    b = K.MeshBuilder()
    for k in range(11):
        x = -1.5 + .3 * k
        plank(b, kit, gd(x, .5, .405), (.28, .03, .9), 2, 540 + k)
    objs.append(obj(b, "Front boards", kit))

    # Shelves: three deep tiers on posts, a peg rail for the middle goods.
    b = K.MeshBuilder()
    for k, (y, z0, z1) in enumerate(((.44, -2.12, -1.2), (1.15, -2.12, -1.32), (1.9, -2.12, -1.42))):
        for n, (za, zb) in enumerate(((z0, (z0 + z1) / 2 - .005), ((z0 + z1) / 2 + .005, z1))):
            plank(b, kit, gd(0, y, (za + zb) / 2), (4.5, zb - za, .04), 0, 600 + k * 2 + n)
        plank(b, kit, gd(0, y - .07, z1 - .03), (4.4, .05, .1), 0, 610 + k)
    for x in (-2.2, 2.2):
        for z in (-2.08, -1.36):
            plank(b, kit, gd(x, 1.08, z), (.09, .09, 2.16), 2, 620 + int(x * 10 + z * 10))
    plank(b, kit, gd(0, 1.53, -1.6), (4.4, .03, .13), 0, 630)
    # A shallow tray for the hook papers on the middle shelf.
    plank(b, kit, gd(-1.25, 1.176, -1.5), (.34, .3, .012), 0, 640)
    for x, z, sx, sz in ((-1.42, -1.5, .015, .3), (-1.08, -1.5, .015, .3), (-1.25, -1.65, .34, .015), (-1.25, -1.35, .34, .015)):
        plank(b, kit, gd(x, 1.19, z), (sx, sz, .03), 0 if sx > sz else 1, 641 + int(x * 10 + z * 10))
    objs.append(obj(b, "Shelf", kit))

    # Stock that is not for sale on the slate: folded blankets, bolts of cloth, candle boxes
    # and a soap crate on the middle shelf, clear of the hook tray, coils and rod.
    b = K.MeshBuilder()
    rng = random.Random(650)
    for k in range(3):
        c = gd(1.62 + rng.uniform(-.02, .02), 1.205 + .075 * k, -1.62)
        rot = Matrix.Rotation(rng.uniform(-.08, .08), 3, "Z")
        K.box(b, c, (.5, .42, .07), kit.wool, tile=.5, rot=rot)
        K.tube(b, [c + rot @ Vector((-.25, -.21, 0)), c + rot @ Vector((.25, -.21, 0))], .035, kit.wool, sides=6, tile=.5)
    # Bolts of cloth standing on edge, wound on their boards.
    for k, (x, mat) in enumerate(((-.82, kit.wool), (-.7, kit.cotton), (-.58, kit.canvas))):
        c = gd(x, 1.17, -1.64)
        rot = Matrix.Rotation(rng.uniform(-.05, .05), 3, "Z")
        K.box(b, c + Vector((0, 0, .17)), (.085, .4, .32), mat, tile=.3, rot=rot)
        K.box(b, c + Vector((0, 0, .17)), (.02, .42, .34), kit.wood, tile=.4, rot=rot)
    for k, x in enumerate((.42, .62)):
        plank(b, kit, gd(x, 1.245, -1.66), (.18, .3, .15), 0, 660 + k)
        K.box(b, gd(x, 1.322, -1.62), (.16, .002, .07), kit.paper, tile=.2)
    plank(b, kit, gd(-1.86, 1.25, -1.7), (.36, .4, .16), 0, 670)
    objs.append(obj(b, "Shelf stock", kit))

    # Price board on two legs beside the stall; slate on an easel at the counter.
    b = K.MeshBuilder()
    K.box(b, gd(-3.25, 1.78, 1.1), (1.05, .055, 1.85), kit.slate, tile=1.2)
    objs.append(obj(b, "Board", kit))
    b = K.MeshBuilder()
    for x in (-3.84, -2.66):
        plank(b, kit, gd(x, 1.36, 1.08), (.07, .07, 2.72), 2, 700 + int(x * 10))
    for y in (.82, 2.74):
        plank(b, kit, gd(-3.25, y, 1.1), (1.2, .08, .06), 0, 710 + int(y * 10))
    for x in (-3.8, -2.7):
        plank(b, kit, gd(x, 1.78, 1.1), (.05, .08, 1.9), 2, 720 + int(x * 10))
    plank(b, kit, gd(-2.95, 1.12, 1.06), (.7, .07, .05), 0, 730)
    objs.append(obj(b, "Board frame", kit))
    b = K.MeshBuilder()
    K.box(b, gd(1.2, 1.38, .22), (.98, .055, .68), kit.slate, tile=1.0)
    objs.append(obj(b, "Slate", kit))
    b = K.MeshBuilder()
    for y in (1.06, 1.71):
        plank(b, kit, gd(1.2, y, .21), (1.04, .07, .05), 0, 740 + int(y * 10))
    for x in (.69, 1.71):
        plank(b, kit, gd(x, 1.38, .21), (.05, .07, .7), 2, 750 + int(x * 10))
    for x in (.8, 1.6):
        plank(b, kit, gd(x, 1.18, .05), (.04, .3, .04), 1, 760 + int(x * 10), tile=1.0)
    objs.append(obj(b, "Slate frame", kit))

    # Ledger on the counter.
    b = K.MeshBuilder()
    c = gd(.63, 1.07, -.1)
    K.box(b, c + Vector((0, 0, .0045)), (.24, .31, .009), kit.leather, tile=.3)
    K.box(b, c + Vector((.004, 0, .025)), (.23, .30, .032), kit.paper, tile=.3)
    K.box(b, c + Vector((0, 0, .0455)), (.24, .31, .009), kit.leather, tile=.3)
    objs.append(obj(b, "Book", kit))

    # Brass balance: names and object origins are the ones store.gd animates.
    b = K.MeshBuilder()
    for k, x in enumerate((-1.42, -.48)):
        K.box(b, gd(x, 1.083, 0), (.08, .3, .026), kit.wood, tile=.4)
    plank(b, kit, gd(-.95, 1.10, 0), (1.15, .34, .045), 0, 770)
    objs.append(obj(b, "Scale base", kit))
    b = K.MeshBuilder()
    K.lathe(b, [(.07, 0), (.07, .015), (.04, .03), (.03, .05), (.026, .45), (.038, .47), (.016, .51)], kit.brass, sides=10, tile=.2, center=gd(-.95, 1.12, 0))
    objs.append(obj(b, "Scale upright", kit))
    b = K.MeshBuilder()
    beam = [gd(-1.47, 1.65, 0), gd(-1.2, 1.655, 0), gd(-.95, 1.66, 0), gd(-.7, 1.655, 0), gd(-.42, 1.65, 0)]
    K.tube(b, beam, [.02, .024, .034, .024, .02], kit.brass, sides=8, tile=.2)
    K.tube(b, [gd(-.95, 1.66, 0), gd(-.95, 1.55, 0)], [.006, .002], kit.brass, sides=4, tile=.2)
    objs.append(obj(b, "Beam", kit, pivot=gd(-.945, 1.65, 0)))
    for x in (-1.37, -.52):
        b = K.MeshBuilder()
        K.lathe(b, [(0, 0), (.12, .004), (.165, .022), (.182, .042), (.176, .044), (.158, .026), (.11, .012), (0, .01)], kit.brass, sides=18, tile=.2, center=gd(x, 1.185, 0))
        objs.append(obj(b, "Pan", kit))
        b = K.MeshBuilder()
        for a in (90, 210, 330):
            r = math.radians(a)
            b0 = gd(x + .165 * math.cos(r), 1.226, .165 * math.sin(r))
            K.tube(b, [b0, gd(x, 1.64, 0)], .006, kit.brass, sides=4, tile=.1)
        objs.append(obj(b, "Pan chain", kit))
    for i in range(3):
        b = K.MeshBuilder()
        cx = -.42 + i * .12
        r = .045 - i * .006
        K.lathe(b, [(0, 0), (r, 0), (r, .06 - i * .008), (r * .55, .07 - i * .008), (r * .35, .075 - i * .008), (r * .4, .09 - i * .008), (0, .095 - i * .008)],
                kit.brass, sides=10, tile=.2, center=gd(cx, 1.08, -.28))
        objs.append(obj(b, "Weight", kit, pivot=gd(cx, 1.125, -.28)))

    # Fish plank over the barrel (the barrel itself is assets/props/barrel.glb).
    b = K.MeshBuilder()
    for k, z in enumerate((-.2, .02, .24)):
        plank(b, kit, gd(2.45, .905, .6 + z), (.92, .21, .04), 0, 780 + k)
    objs.append(obj(b, "Fish plank", kit))

    # Hitching rail.
    b = K.MeshBuilder()
    for k, z in enumerate((-1, 4, 7)):
        pole(b, kit, gd(-5, -.08, z), gd(-5.01, 1.12, z), .07, .06, 800 + k, segs=4)
    for z0, z1 in ((-1, 4), (4, 7)):
        K.rope(b, gd(-5, .97, z0), gd(-5, .97, z1), kit.rope, radius=.011, sag=.18, n=10, sides=5)
    objs.append(obj(b, "Picket", kit))
    K.export_glb(objs, OUT / "store.glb")


# ------------------------------------------------------------------ goods

def sack(b, kit, height, radius, fill, mat, seed, tied=True, content=None, slump=0.0):
    """A sack: a lathe profile (rounded base, body, gathered neck and tuft for a tied
    sack, a rolled mouth for an open one), then slumped, flattened, leaned and creased
    with seeded noise; gathers fold toward the tie."""
    def smooth(t):
        t = max(0.0, min(1.0, t))
        return t * t * (3 - 2 * t)
    prof = [(0, 0), (radius * .72, 0), (radius * .9, .02 * height)]
    n = 14
    for k in range(1, n + 1):
        t = k / n
        z = height * t
        if tied:
            if t < .7:
                r = radius * (1 + .05 * math.sin(math.pi * t / .7))
            elif t < .88:
                r = radius * (1 - .8 * smooth((t - .7) / .18))
            else:
                r = radius * (.2 + .2 * smooth((t - .88) / .12))
        else:
            r = radius * (1 + .05 * math.sin(math.pi * t))
        prof.append((r, z))
    if tied:
        prof.append((radius * .26, height * 1.04))
        prof.append((0, height * 1.02))
    else:
        top = height
        prof += [(radius * 1.1, top + .02), (radius * 1.17, top + .004), (radius * 1.12, top - .022), (radius * .99, top - .012)]
    rings = K.lathe(b, prof, mat, sides=16, tile=.5, dirt=lambda p: .68 + .32 * min(1.0, p.z / .3))
    first = rings[0][0][0]
    rng = random.Random(seed)
    lean = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * .035
    flat = rng.uniform(.8, .9)
    ph = rng.uniform(0, 6)
    for i in range(first, len(b.v)):
        p = b.v[i]
        t = p.z / max(height, 1e-6)
        a = math.atan2(p.y, p.x)
        radial = Vector((p.x, p.y, 0))
        r = radial.length
        crease = .03 * radius / .2 * K.fbm((p.x * 1.3, p.y * 1.3, p.z), 6, seed)
        crease += .012 * K.vnoise((p.x, p.y, p.z), 18, seed + 1)
        gather = smooth((t - .45) / .4) if tied else smooth((t - .75) / .2)
        crease += .022 * radius / .2 * gather * math.sin(7 * a + ph + 2.5 * K.vnoise((p.x, p.y, p.z), 5, seed + 2))
        spread = 1 + slump * (1 - min(t, 1.0)) ** 2 * 1.3
        q = Vector((p.x * spread, p.y * spread * flat, p.z * (1 - .3 * slump)))
        if r > 1e-4:
            q += Vector((p.x / r, p.y / r * flat, 0)) * crease * min(1.0, t * 8)
        q += lean * min(t, 1.0) * height / .5
        b.v[i] = q
    top_z = height * (1 - .3 * slump)
    if tied:
        K.wraps(b, Vector((0, 0, top_z * .9)) + lean * .9 * height / .5, (0, 0, 1), .2 * radius, kit.rope,
                turns=3, width=.022, thickness=.0045, sides=4, seg=8)
    elif content is not None:
        hz = top_z * (.5 + .42 * fill)
        rr = radius * (1.02 + slump * .25)
        c = lean * (hz / max(top_z, 1e-6)) * height / .5
        K.lathe(b, [(rr, hz - .02), (rr * .75, hz + .012), (rr * .4, hz + .028), (0, hz + .034)], content, sides=16, tile=.25,
                center=(c.x, c.y, 0))


def goods():
    kit = Kit(["kit_burlap", "kit_cotton", "kit_rope", "kit_beans", "kit_coffee", "kit_flour", "kit_salt", "kit_pork",
               "kit_paper", "kit_iron", "kit_wood", "kit_split", "kit_bark", "kit_endgrain", "kit_leather", "kit_canvas",
               "kit_glass"])
    objs = []
    spec = {  # item: (material, height at full, radius, tied, content)
        "flour": (kit.cotton, .62, .2, True, None),
        "beans": (kit.burlap, .5, .19, False, kit.beans),
        "coffee": (kit.burlap, .42, .16, False, kit.coffee),
        "salt": (kit.cotton, .36, .15, True, None),
    }
    for item, (mat, h, r, tied, content) in spec.items():
        for fill in range(4):
            b = K.MeshBuilder()
            f = (fill + 1) / 4
            sack(b, kit, h * (.55 + .45 * f), r * (.9 + .1 * f), f, mat, 900 + fill * 7 + len(item), tied, content, slump=.45 * (1 - f))
            objs.append(obj(b, "%s_%d" % (item, fill), kit))
    # Salt pork in brine: slabs inside the tub (assets/props/tub.glb, added by shelves.gd).
    for fill in range(4):
        b = K.MeshBuilder()
        rng = random.Random(950 + fill)
        level = .1 + .055 * fill
        K.lathe(b, [(.27, level - .01), (0, level)], kit.pork, sides=16, tile=.3)
        for k in range(1 + fill):
            yaw = rng.uniform(0, math.pi)
            K.box(b, (rng.uniform(-.08, .08), rng.uniform(-.08, .08), level + .012 + .02 * k), (.24, .14, .045), kit.pork,
                  tile=.25, rot=Matrix.Rotation(yaw, 3, "Z"), grain=0)
        objs.append(obj(b, "pork_%d" % fill, kit))
    # Hooks: a folded paper of hooks.
    b = K.MeshBuilder()
    K.box(b, (0, 0, .004), (.12, .16, .008), kit.paper, tile=.15)
    K.box(b, (0, -.06, .0095), (.12, .04, .003), kit.paper, tile=.15)
    objs.append(obj(b, "hook", kit))
    # Line: a coil with a binding.
    b = K.MeshBuilder()
    pts = []
    for i in range(49):
        a = math.tau * i / 48
        pts.append(Vector((math.cos(a) * .1, .003 * math.sin(a * 5), math.sin(a) * .1)))
    K.tube(b, pts, .016, kit.rope, sides=6, tile=.05, twist=40)
    K.wraps(b, (0, 0, .1), (1, 0, 0), .016, kit.rope, turns=3, width=.025, thickness=.004, sides=4, seg=6)
    objs.append(obj(b, "line", kit))
    # Rod: a peeled willow rod with a wrapped grip (the legacy length).
    b = K.MeshBuilder()
    pts = [Vector((0, 0, 0)).lerp(gd(.09, 1.8, 0), t / 6) for t in range(7)]
    K.tube(b, pts, [.015 - .009 * t / 6 for t in range(7)], kit.split, sides=6, tile=.6)
    K.wraps(b, gd(.012, .3, 0), (0, 0, 1), .014, kit.rope, turns=6, width=.12, thickness=.003, sides=4, seg=6)
    objs.append(obj(b, "rod", kit))
    # Boots: a pair, built from swept sections.
    b = K.MeshBuilder()
    for s in (-1, 1):
        x0 = s * .065
        sole = []
        for k in range(9):
            t = k / 8
            y = -.13 + .27 * t
            w = .045 + .012 * math.sin(math.pi * min(1.0, t * 1.3))
            sole.append((y, w))
        # Foot: lofted ellipses along the sole, toe rising.
        pts, radii = [], []
        for y, w in sole:
            pts.append(Vector((x0, y, .045 + .02 * max(0.0, (y - .08) / .06))))
            radii.append(w)
        rings = K.tube(b, pts, radii, kit.leather, sides=10, tile=.3)
        for ring in rings:
            for vi, _ in ring:
                p = b.v[vi]
                if p.z < .01:
                    p.z = .012
                b.v[vi] = Vector((p.x, p.y, max(.012, .045 + (p.z - .045) * .85)))
        shaft = [Vector((x0, -.07, .07)), Vector((x0, -.075, .18)), Vector((x0, -.07, .3))]
        K.tube(b, shaft, [.05, .046, .05], kit.leather, sides=10, tile=.3)
        K.box(b, (x0, .0, .006), (.1, .29, .012), kit.leather, tile=.3)
    objs.append(obj(b, "boots", kit))
    # Rocker kit: sawn boards and a rolled iron hopper sheet, tied.
    b = K.MeshBuilder()
    for k in range(4):
        plank(b, kit, (0, .0, .018 + .036 * k), (.36, .7, .034), 1, 960 + k)
    K.tube(b, [Vector((-.08, -.3, .2)), Vector((-.08, .3, .2))], .055, kit.iron, sides=10, tile=.3, cap_mat=kit.iron)
    for y in (-.22, .22):
        K.wraps(b, (0, y, .08), (0, 1, 0), .2, kit.rope, turns=1, width=.01, thickness=.006, sides=4, seg=10)
    objs.append(obj(b, "rocker", kit))
    # Powder: a small keg with iron hoops.
    b = K.MeshBuilder()
    K.lathe(b, [(0, 0), (.1, 0), (.115, .06), (.12, .12), (.115, .18), (.1, .24), (0, .24)], kit.wood, sides=14, tile=.3)
    for z in (.03, .21, .09, .15):
        K.lathe(b, [(.112 + .006 * (1 - abs(z - .12) / .12), z - .008), (.118 + .006 * (1 - abs(z - .12) / .12), z), (.112 + .006 * (1 - abs(z - .12) / .12), z + .008)], kit.iron, sides=14, tile=.3)
    objs.append(obj(b, "powder", kit))
    # Tent: rolled canvas with its poles, tied twice.
    b = K.MeshBuilder()
    K.tube(b, [Vector((-.32, 0, .11)), Vector((0, 0, .115)), Vector((.32, 0, .11))], [.1, .105, .1], kit.canvas, sides=12, tile=.5, cap_mat=kit.canvas, wobble=.05, seed=970)
    for y in (-.09, .09):
        K.tube(b, [Vector((-.4, y, .03)), Vector((.4, y, .035))], .016, kit.split, sides=5, tile=.5, cap_mat=kit.endgrain)
    for x in (-.18, .18):
        K.wraps(b, (x, 0, .11), (1, 0, 0), .105, kit.rope, turns=2, width=.02, thickness=.005, sides=4, seg=10)
    objs.append(obj(b, "tent", kit))
    # Outfitting: whiskey bottle, iron strongbox, dam timber, bunk-tent roll.
    b = K.MeshBuilder()
    K.lathe(b, [(0, .0), (.04, 0), (.042, .01), (.042, .19), (.03, .23), (.014, .26), (.013, .3)], kit.glass, sides=12, tile=.2, close_top=False)
    K.lathe(b, [(.0125, .29), (.0135, .31), (.0, .315)], kit.split, sides=8, tile=.1)
    K.box(b, (0, -.0415, .1), (.05, .002, .07), kit.paper, tile=.1)
    objs.append(obj(b, "whiskey", kit))
    b = K.MeshBuilder()
    K.box(b, (0, 0, .15), (.6, .38, .3), kit.iron, tile=.5)
    K.box(b, (0, 0, .32), (.62, .4, .06), kit.iron, tile=.5)
    for x in (-.2, .2):
        K.box(b, (x, 0, .19), (.05, .41, .32), kit.iron, tile=.3)
    K.box(b, (0, -.205, .26), (.07, .02, .1), kit.iron, tile=.2)
    objs.append(obj(b, "strongbox", kit))
    b = K.MeshBuilder()
    for k, (y, z) in enumerate(((-.2, .08), (0, .08), (.2, .08), (-.1, .24), (.1, .24))):
        plank(b, kit, (0, y, z), (1.6, .17, .16), 0, 980 + k, mat=kit.split, tile=1.2)
    for x in (-.55, .55):
        K.wraps(b, (x, 0, .16), (1, 0, 0), .26, kit.rope, turns=1, width=.01, thickness=.008, sides=4, seg=12)
    objs.append(obj(b, "timber", kit))
    b = K.MeshBuilder()
    K.tube(b, [Vector((-.5, 0, .14)), Vector((0, 0, .145)), Vector((.5, 0, .14))], [.13, .14, .13], kit.canvas, sides=12, tile=.5, cap_mat=kit.canvas, wobble=.06, seed=990)
    for x in (-.3, 0, .3):
        K.wraps(b, (x, 0, .14), (1, 0, 0), .14, kit.rope, turns=2, width=.02, thickness=.005, sides=4, seg=10)
    objs.append(obj(b, "bunk", kit))
    # Counter parcel (a pound of anything, weighed into paper and tied), rail peg, price tag.
    b = K.MeshBuilder()
    K.box(b, (0, 0, .045), (.15, .11, .09), kit.paper, tile=.2)
    K.box(b, (0, 0, .093), (.07, .05, .012), kit.paper, tile=.2, rot=Matrix.Rotation(.3, 3, "Z"))
    for axis in ((1, 0, 0), (0, 1, 0)):
        K.wraps(b, (0, 0, .045), axis, .066, kit.rope, turns=1, width=.002, thickness=.002, sides=3, seg=12)
    objs.append(obj(b, "parcel", kit))
    b = K.MeshBuilder()
    K.tube(b, [Vector((0, 0, 0)), Vector((0, -.12, .005)), Vector((0, -.18, .02))], [.013, .011, .012], kit.split, sides=6, tile=.2, cap_mat=kit.endgrain)
    objs.append(obj(b, "peg", kit))
    b = K.MeshBuilder()
    K.box(b, (0, 0, 0), (.075, .002, .05), kit.paper, tile=.1)
    K.tube(b, [Vector((0, .0, .02)), Vector((0, -.006, .02))], .0025, kit.iron, sides=4, tile=.1)
    objs.append(obj(b, "tag", kit))
    K.export_glb(objs, OUT / "goods.glb")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not argv or "stall" in argv:
        stall()
    if not argv or "goods" in argv:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        goods()
    print("BUILT store")
