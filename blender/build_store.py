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
               "kit_slate", "kit_leather", "kit_paper", "kit_wool", "kit_cotton", "kit_split", "kit_paint", "kit_sign",
               "kit_labels", "kit_stencil", "kit_tin", "kit_crock", "kit_blanket", "kit_osnaburg", "kit_glass", "kit_flour",
               "kit_pork", "kit_beans"])
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
        # The painted lettering spans the sheet once (kit_sign, tools/art/build_prop_labels.py).
        b.face([bot[i], bot[i + 1], top[i + 1], top[i]], [(i / nu, 0), ((i + 1) / nu, 0), ((i + 1) / nu, 1), (i / nu, 1)], kit.sign)
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
        plank(b, kit, gd(x, .5, .405), (.28, .03, .9), 2, 540 + k, mat=kit.split)  # newer boards: the counter reads from the trail
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

    # Stock that is not for sale on the slate, stocked like a trading post: tinned goods
    # and canisters with paper labels, bolts of cloth and folded trade blankets, candles,
    # jars, stoneware, a nail keg; clear of the hook tray, coils and rod (shelves.gd).
    b = K.MeshBuilder()
    rng = random.Random(650)
    mid, low, top = 1.17, .46, 1.92  # shelf top surfaces (Godot y)
    # Middle shelf, left: soap and candle boxes at the back, tea canisters and pepper in front.
    paper_box(b, kit, gd(-1.88, mid, -1.92), (.38, .24, .16), .05, LABEL["soap"], 651)
    paper_box(b, kit, gd(-1.86, mid + .16, -1.9), (.34, .2, .12), -.06, LABEL["candles"], 652)
    for k, x in enumerate((-2.07, -1.95, -1.83)):
        tin(b, kit, gd(x, mid, -1.55 + .02 * k), .046, .15, LABEL["tea"])
    tin(b, kit, gd(-1.68, mid, -1.52), .035, .1, LABEL["pepper"])
    tin(b, kit, gd(-1.6, mid, -1.62), .035, .1, LABEL["mustard"])
    # Middle, between hooks and line: bolts of cloth at the back, sardines and oysters in front.
    for k, (x, mat) in enumerate(((-.96, kit.wool), (-.85, kit.osnaburg), (-.74, kit.canvas), (-.63, kit.cotton), (-.52, kit.wool))):
        bolt(b, kit, gd(x, mid, -1.86), .085, .4, .32 - .02 * (k % 2), rng.uniform(-.06, .06), mat)
    for k in range(4):
        y = mid + .026 * k
        c = gd(-.82 + .01 * (k % 2), y, -1.5)
        K.box(b, c + Vector((0, 0, .013)), (.16, .1, .026), kit.tin, tile=.2, rot=Matrix.Rotation(rng.uniform(-.1, .1), 3, "Z"))
        label_quad(b, c + Vector((0, -.0505, .013)), (1, 0, 0), (0, 0, 1), .15, .024, LABEL["sardines"], kit.labels)
    for k, x in enumerate((-.6, -.49)):
        tin(b, kit, gd(x, mid, -1.5), .05, .12, LABEL["oysters"], lid=False)
    tin(b, kit, gd(-.545, mid + .12, -1.5), .05, .12, LABEL["oysters"], lid=False)
    # Middle, between line and rod: candle and match boxes, jars of pickles, candles on the rail.
    paper_box(b, kit, gd(.32, mid, -1.9), (.32, .22, .14), .04, LABEL["candles"], 653)
    paper_box(b, kit, gd(.3, mid + .14, -1.92), (.26, .18, .1), -.08, LABEL["matches"], 654)
    paper_box(b, kit, gd(.62, mid, -1.88), (.24, .2, .12), .1, LABEL["saleratus"], 655)
    for k, x in enumerate((.18, .3, .42)):
        c = gd(x, mid, -1.5)
        K.lathe(b, [(0, 0), (.042, 0), (.045, .01), (.045, .15), (.035, .17), (.03, .19)], kit.glass, sides=12, tile=.2, center=tuple(c))
        K.lathe(b, [(.03, .185), (.032, .205), (0, .21)], kit.endgrain, sides=8, tile=.1, center=tuple(c))
        K.lathe(b, [(.028, .03), (.038, .05), (.04, .1), (.03, .14), (0, .14)], kit.beans if k == 1 else kit.pork, sides=8, tile=.2, center=tuple(c))
        label_band(b, c, .045, .05, .11, -math.pi / 2 - 1.1, -math.pi / 2 + 1.1, LABEL["onions"], kit.labels, sides=6)
    for k, x in enumerate((.62, .72, .82)):
        candles(b, kit, gd(x, 1.5, -1.53), count=5 + k % 2, seed=656 + k)
    # Middle, right: folded trade blankets and stoneware.
    for k in range(3):
        folded_blanket(b, kit, gd(1.78 + rng.uniform(-.02, .02), mid + .085 * k, -1.72), .56, .34, .08,
                       rng.uniform(-.06, .06), kit.blanket if k != 1 else kit.wool, 660 + k)
    crock(b, kit, gd(1.38, mid, -1.5), .085, .2, jug=False)
    label_band(b, gd(1.38, mid, -1.5), .088, .07, .13, -math.pi / 2 - .9, -math.pi / 2 + .9, LABEL["lard"], kit.labels, sides=6)
    crock(b, kit, gd(2.06, mid, -1.52), .08, .3, jug=True)
    # Bottom shelf ends: a nail keg and stoneware jugs either side of the bulk sacks.
    keg(b, kit, gd(-2.0, low, -1.62), .15, .34, cell=STENCIL["nails"])
    crock(b, kit, gd(1.96, low, -1.55), .1, .36, jug=True)
    crock(b, kit, gd(2.12, low, -1.85), .09, .3, jug=True)
    crock(b, kit, gd(1.9, low, -1.9), .11, .24, jug=False)
    # Top shelf ends: stacked tin plates and cups, a tin coffee pot, boxes of flints and caps.
    for k in range(6):
        K.lathe(b, [(0, 0), (.1, 0), (.125, .018), (.122, .02), (.097, .003), (0, .003)], kit.tin, sides=10, tile=.2,
                center=tuple(gd(-2.05 + .003 * k, top + .008 * k, -1.6)))
    for k, (x, z) in enumerate(((-1.95, -1.88), (-2.1, -1.86))):
        K.lathe(b, [(0, 0), (.04, 0), (.044, .09), (.04, .09), (.036, .005), (0, .005)], kit.tin, sides=10, tile=.2, center=tuple(gd(x, top, z)))
    c = gd(2.05, top, -1.75)
    K.lathe(b, [(0, 0), (.08, 0), (.085, .01), (.07, .16), (.05, .2), (.055, .21), (.03, .23), (0, .235)], kit.tin, sides=12, tile=.3, center=tuple(c))
    K.tube(b, [c + Vector((.07, 0, .04)), c + Vector((.12, 0, .12)), c + Vector((.15, 0, .17))], [.014, .01, .007], kit.tin, sides=5, tile=.2)
    paper_box(b, kit, gd(1.98, top, -1.52), (.14, .1, .06), .1, LABEL["flints"], 657)
    paper_box(b, kit, gd(-1.98, top + .05, -1.5), (.14, .1, .06), -.1, LABEL["caps"], 658)
    objs.append(obj(b, "Shelf stock", kit))

    # Goods hung on pegs on the outside of the east wall, facing the trail: a coil of
    # rope, a frying pan, a tin kettle and a bundle of candles.
    b = K.MeshBuilder()
    wall = 2.76
    for z, y in ((-2.25, 1.62), (-1.72, 1.62), (-1.3, 1.5)):
        K.tube(b, [gd(wall - .06, y, z), gd(wall + .1, y + .02, z)], .014, kit.split, sides=5, tile=.2, cap_mat=kit.endgrain)
    coil = []
    for i in range(25):
        a = math.tau * i / 24
        coil.append(gd(wall + .05, 1.42 + .19 * math.sin(a) - .02 * (1 - math.cos(a)) ** 2, -2.25 + .17 * math.cos(a)))
    for k in range(2):
        K.tube(b, [p + Vector((.022 * k, 0, 0)) for p in coil], .022, kit.rope, sides=5, tile=.05, twist=30)
    K.wraps(b, gd(wall + .05, 1.6, -2.25), (1, 0, 0), .03, kit.rope, turns=3, width=.03, thickness=.006, sides=4, seg=6)
    # Frying pan hung by its handle, the bottom toward the trail: built flat, then stood up.
    first = len(b.v)
    K.lathe(b, [(0, .0), (.14, 0), (.165, .01), (.178, .045), (.172, .05), (.16, .02), (0, .012)], kit.iron, sides=16, tile=.3)
    K.tube(b, [Vector((0, .17, .03)), Vector((0, .3, .036)), Vector((0, .42, .04))], [.014, .012, .014], kit.iron, sides=5, tile=.3)
    pan_c = gd(wall + .02, 1.18, -1.72)
    stand = Matrix.Rotation(math.pi / 2, 3, "X")  # handle (+Y) up, bowl toward +X after the yaw
    yaw = Matrix.Rotation(math.pi / 2, 3, "Z")
    for i in range(first, len(b.v)):
        b.v[i] = pan_c + yaw @ (stand @ b.v[i])
    # Tin kettle on the third peg.
    kc = gd(wall + .07, 1.12, -1.3)
    K.lathe(b, [(0, 0), (.09, 0), (.1, .02), (.1, .16), (.08, .2), (.04, .22), (0, .225)], kit.tin, sides=12, tile=.3, center=tuple(kc))
    K.tube(b, [kc + Vector((0, -.1, .17)), kc + Vector((0, -.06, .36)), kc + Vector((0, .06, .36)), kc + Vector((0, .1, .17))], .004, kit.iron, sides=4, tile=.1)
    objs.append(obj(b, "Wall goods", kit))

    # Price board: dark-painted planks (prices hand-lettered by price_board.gd), on two
    # peeled poles set in the ground with rails and a little board roof over it.
    b = K.MeshBuilder()
    for k in range(6):
        y = 1.78 - .925 + (k + .5) * 1.85 / 6
        # Butted boards (no see-through gaps: the background must not read as lettering).
        plank(b, kit, gd(-3.25, y, 1.1 - .004 * (k % 2)), (1.05, .047, 1.85 / 6), 0, 690 + k, mat=kit.paint, tile=1.0)
    objs.append(obj(b, "Board", kit))
    b = K.MeshBuilder()
    for k, x in enumerate((-3.86, -2.64)):
        pole(b, kit, gd(x, -.1, 1.06), gd(x + .01, 2.95, 1.06), .055, .045, 700 + k, segs=6, crook=.015)
    for y in (.8, 2.76):
        plank(b, kit, gd(-3.25, y, 1.06), (1.3, .07, .08), 0, 710 + int(y * 10))
    for s in (-1, 1):  # board roof: two boards meeting over the top rail
        K.box(b, gd(-3.25, 2.86, 1.06 + s * .1), (1.42, .2, .025), kit.wood, tile=1.0, grain=0,
              rot=Matrix.Rotation(s * .55, 3, "X"))
    for x in (-3.8, -2.7):
        for y in (.95, 2.6):
            K.wraps(b, gd(x + (-.06 if x < -3.25 else .06), y, 1.06), (0, 0, 1), .05, kit.rope, turns=3, width=.05, thickness=.006, sides=4, seg=6)
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


# ------------------------------------------------------------------ lettering helpers

# Cells of the kit's lettered atlases (tools/art/build_prop_labels.py).
STENCIL = {"flour": 0, "salt": 1, "coffee": 2, "beans": 3, "nails": 4, "powder": 5, "mark": 6, "pork": 7}
LABEL = {"tea": 0, "candles": 1, "soap": 2, "tobacco": 3, "sardines": 4, "oysters": 5, "matches": 6, "pepper": 7,
         "saleratus": 8, "caps": 9, "mustard": 10, "chocolate": 11, "lard": 12, "onions": 13, "snaps": 14, "flints": 15}


def stencil_uv(cell, s, t):
    """Atlas UV for (s, t) in [0,1]^2 of stencil cell `cell` (2 columns x 4 rows)."""
    return ((cell % 2 + s) / 2, 1 - (cell // 2 + 1 - t) / 4)


def label_uv(cell, s, t):
    """Atlas UV for (s, t) in [0,1]^2 of label cell `cell` (4 x 4)."""
    return ((cell % 4 + s) / 4, 1 - (cell // 4 + 1 - t) / 4)


def label_quad(b, center, right, up, w, h, cell, mat, atlas=label_uv, out=None):
    """A flat lettered patch (paper label or painted mark) facing right x up."""
    c, r, u = Vector(center), Vector(right).normalized(), Vector(up).normalized()
    if out is not None:
        c = c + Vector(out).normalized() * .0015
    q = [c - r * w / 2 - u * h / 2, c + r * w / 2 - u * h / 2, c + r * w / 2 + u * h / 2, c - r * w / 2 + u * h / 2]
    ids = [b.vert(p) for p in q]
    b.face(ids, [atlas(cell, 0, 0), atlas(cell, 1, 0), atlas(cell, 1, 1), atlas(cell, 0, 1)], mat, True)


def label_band(b, center, radius, z0, z1, a0, a1, cell, mat, sides=10):
    """A paper label wrapped round a tin or jar from angle a0 to a1 (radians, about +Z)."""
    c = Vector(center)
    ids = []
    for k in range(sides + 1):
        a = a0 + (a1 - a0) * k / sides
        d = Vector((math.cos(a), math.sin(a), 0))
        ids.append((b.vert(c + d * (radius + .0012) + Vector((0, 0, z0))), b.vert(c + d * (radius + .0012) + Vector((0, 0, z1)))))
    for k in range(sides):
        s0, s1 = k / sides, (k + 1) / sides
        b.face([ids[k][0], ids[k + 1][0], ids[k + 1][1], ids[k][1]],
               [label_uv(cell, s0, 0), label_uv(cell, s1, 0), label_uv(cell, s1, 1), label_uv(cell, s0, 1)], mat, False)


# ------------------------------------------------------------------ period stock

def tin(b, kit, center, radius, height, cell=None, lid=True, seed=0):
    """A soldered tinplate canister or can, optionally with a paper label."""
    c = Vector(center)
    K.lathe(b, [(0, 0), (radius * .97, 0), (radius, .004), (radius, height - .006), (radius * .97, height)] +
            ([(radius * 1.02, height), (radius * 1.02, height + .012), (0, height + .014)] if lid else [(0, height)]),
            kit.tin, sides=10, tile=.2, center=tuple(c))
    if cell is not None:
        label_band(b, c, radius, height * .18, height * .82, -math.pi * .5 - 1.3, -math.pi * .5 + 1.3, cell, kit.labels)


def crock(b, kit, center, radius, height, jug=False, seed=0):
    """Salt-glazed stoneware: a jug (narrow neck, strap handle, cork) or a crock."""
    c = Vector(center)
    if jug:
        prof = [(0, 0), (radius * .82, 0), (radius * .96, .02), (radius, height * .3), (radius * .97, height * .52),
                (radius * .78, height * .68), (radius * .38, height * .8), (radius * .27, height * .86),
                (radius * .27, height * .95), (radius * .31, height * .97), (radius * .3, height)]
    else:
        prof = [(0, 0), (radius * .9, 0), (radius, .02), (radius * 1.02, height * .5), (radius * .95, height * .9),
                (radius * 1.0, height * .94), (radius * .98, height), (radius * .9, height * .99), (0, height * .97)]
    arc = sum(math.hypot(prof[j][0] - prof[j - 1][0], prof[j][1] - prof[j - 1][1]) for j in range(1, len(prof)))
    K.lathe(b, prof, kit.crock, sides=14, tile=arc, center=tuple(c))
    if jug:
        K.lathe(b, [(radius * .2, height * .98), (radius * .24, height * 1.06), (radius * .2, height * 1.1), (0, height * 1.1)],
                kit.endgrain, sides=8, tile=.1, center=tuple(c))
        h = [c + Vector((radius * .3, 0, height * .9)), c + Vector((radius * .75, 0, height * .92)),
             c + Vector((radius * .98, 0, height * .78)), c + Vector((radius * .9, 0, height * .62))]
        K.tube(b, h, .011, kit.crock, sides=5, tile=arc)


def candles(b, kit, center, count=6, seed=0):
    """A bundle of dipped candles hung by their joined wicks."""
    c = Vector(center)
    rng = random.Random(seed)
    for k in range(count):
        a = math.tau * k / count + rng.uniform(-.2, .2)
        top = c + Vector((math.cos(a) * .018, math.sin(a) * .018, 0))
        bot = top + Vector((math.cos(a) * .012, math.sin(a) * .012, -.24 - rng.uniform(0, .03)))
        K.tube(b, [top, bot], [.009, .012], kit.flour, sides=6, tile=.3)
    K.tube(b, [c + Vector((0, 0, -.004)), c + Vector((0, 0, .05))], .003, kit.rope, sides=3, tile=.05)


def folded_blanket(b, kit, center, w, d, h, yaw, mat, seed):
    """A folded blanket: a soft slab with rounded fold edges front and back."""
    rot = Matrix.Rotation(yaw, 3, "Z")
    c = Vector(center)
    nx, nz = 8, 4
    rows = []
    for j in range(nz + 1):
        t = j / nz
        row = []
        for i in range(nx + 1):
            s = i / nx
            x = -w / 2 + w * s
            bulge = .006 * math.sin(math.pi * s) * math.sin(math.pi * t)
            z = h * t + .003 * K.vnoise((x, t, seed), 9, seed)
            row.append((x, z, bulge))
        rows.append(row)
    # Front fold: a half round across the front edge, so the layers read.
    for side in (-1, 1):
        ring = []
        for i in range(nx + 1):
            col = []
            for k in range(7):
                a = math.pi * k / 6
                x, z, bulge = rows[0][i][0], h / 2 - math.cos(a) * h / 2, 0
                y = side * (d / 2 + math.sin(a) * h / 2 * .8 + bulge)
                col.append(b.vert(c + rot @ Vector((x, y, z))))
            ring.append(col)
        for i in range(nx):
            for k in range(6):
                q = [ring[i][k], ring[i + 1][k], ring[i + 1][k + 1], ring[i][k + 1]]
                if side < 0:
                    q = q[::-1]
                uv = [(w * i / nx, .02 + .5 * k / 6 * h), (w * (i + 1) / nx, .02 + .5 * k / 6 * h),
                      (w * (i + 1) / nx, .02 + .5 * (k + 1) / 6 * h), (w * i / nx, .02 + .5 * (k + 1) / 6 * h)]
                b.face(q, uv, mat)
    # Top and bottom sheets between the folds (the top shows the stripe bands near the fold).
    for z, flip in ((h, False), (0, True)):
        ids = [b.vert(c + rot @ Vector((x, y, z))) for y in (-d / 2, d / 2) for x in (-w / 2, w / 2)]
        q = [ids[0], ids[1], ids[3], ids[2]]
        uv = [(0, .02), (w, .02), (w, .02 + d), (0, .02 + d)]
        if flip:
            q, uv = q[::-1], uv[::-1]
        b.face(q, uv, mat)
    # Raw ends (folded layers seen edge-on).
    for x in (-w / 2, w / 2):
        ids = [b.vert(c + rot @ Vector((x, y, z))) for z in (0, h) for y in (-d / 2 - h * .4, d / 2 + h * .4)]
        q = [ids[0], ids[1], ids[3], ids[2]] if x > 0 else [ids[1], ids[0], ids[2], ids[3]]
        b.face(q, [(0, 0), (d, 0), (d, h), (0, h)], mat)


def bolt(b, kit, center, w, d, h, yaw, mat):
    """A bolt of cloth wound flat on its board, standing on edge."""
    rot = Matrix.Rotation(yaw, 3, "Z")
    c = Vector(center)
    pts = []
    for k in range(17):
        a = math.tau * k / 16
        # Rounded rectangle section in the x-z plane (bolt stands on its long edge).
        x, z = math.cos(a), math.sin(a)
        r = 1 / max(abs(x) ** 4 + abs(z) ** 4, 1e-6) ** .25
        pts.append((x * r * w / 2, z * r * h / 2 + h / 2))
    rings = []
    for y in (-d / 2, d / 2):
        rings.append([b.vert(c + rot @ Vector((x, y, z))) for x, z in pts])
    per = 0.0
    us = [0.0]
    for k in range(1, 17):
        per += math.hypot(pts[k][0] - pts[k - 1][0], pts[k][1] - pts[k - 1][1])
        us.append(per)
    for k in range(16):
        b.face([rings[0][k], rings[0][k + 1], rings[1][k + 1], rings[1][k]], [(us[k], 0), (us[k + 1], 0), (us[k + 1], d), (us[k], d)], mat)
    # End faces: the wound layers (rough board in the middle).
    for e, ring in enumerate(rings):
        ids = ring[:16]
        uv = [(.5 + .5 * pts[k][0] / (w / 2), .5 + .5 * (pts[k][1] - h / 2) / (h / 2)) for k in range(16)]
        if e == 0:
            ids, uv = ids[::-1], uv[::-1]
        b.face(ids, uv, mat, True)
    K.box(b, c + rot @ Vector((0, 0, h / 2)), (w * .25, d + .012, h * 1.04), kit.wood, tile=.4, rot=rot)


def keg(b, kit, center, radius, height, seed=0, cell=None):
    """A small coopered keg (nails, powder) with iron hoops and a painted mark."""
    c = Vector(center)
    prof = [(0, 0), (radius * .86, 0)] + [(radius * (.88 + .12 * math.sin(math.pi * t / 8)), height * t / 8) for t in range(1, 8)] + [(radius * .86, height), (0, height)]
    K.lathe(b, prof, kit.wood, sides=16, tile=.25, center=tuple(c))
    for z in (.06, .22, .78, .94):
        rr = radius * (.88 + .12 * math.sin(math.pi * z)) + .003
        K.lathe(b, [(rr, height * z - .012), (rr + .004, height * z), (rr, height * z + .012)], kit.iron, sides=16, tile=.3, center=tuple(c))
    if cell is not None:
        rr = radius * .99 + .004
        n = 6
        ids = []
        for k in range(n + 1):
            a = -math.pi / 2 - .75 + 1.5 * k / n
            d = Vector((math.cos(a), math.sin(a), 0))
            ids.append((b.vert(c + d * rr + Vector((0, 0, height * .32))), b.vert(c + d * rr + Vector((0, 0, height * .68)))))
        for k in range(n):
            b.face([ids[k][0], ids[k + 1][0], ids[k + 1][1], ids[k][1]],
                   [stencil_uv(cell, k / n, 0), stencil_uv(cell, (k + 1) / n, 0), stencil_uv(cell, (k + 1) / n, 1), stencil_uv(cell, k / n, 1)], kit.stencil)


def crate(b, kit, center, size, yaw, seed, cell=None, lid=True):
    """A nailed crate of sawn boards with corner battens and a painted mark on its face."""
    rot = Matrix.Rotation(yaw, 3, "Z")
    c = Vector(center)
    sx, sy, sz = size
    rng = random.Random(seed)
    boards = max(2, round(sz / .11))
    for side in (-1, 1):  # long faces: horizontal boards with gaps
        for k in range(boards):
            z = sz * (k + .5) / boards
            K.box(b, c + rot @ Vector((0, side * (sy / 2 - .008), z)), (sx, .016, sz / boards - .006), kit.wood, tile=.9,
                  rot=rot, grain=0, uv_offset=(rng.random() * 5, rng.random() * 5))
    for side in (-1, 1):  # ends
        K.box(b, c + rot @ Vector((side * (sx / 2 - .008), 0, sz / 2)), (.016, sy - .032, sz - .004), kit.wood, tile=.9,
              rot=rot, grain=1, uv_offset=(rng.random() * 5, rng.random() * 5))
        for s2 in (-1, 1):  # corner battens
            K.box(b, c + rot @ Vector((side * (sx / 2 - .022), s2 * (sy / 2 + .004), sz / 2)), (.03, .012, sz), kit.wood, tile=.9, rot=rot, grain=2)
    if lid:
        for k in range(3):
            y = sy * ((k + .5) / 3 - .5)
            K.box(b, c + rot @ Vector((0, y, sz + .008)), (sx + .01, sy / 3 - .006, .016), kit.wood, tile=.9, rot=rot, grain=0,
                  uv_offset=(rng.random() * 5, rng.random() * 5))
    K.box(b, c + rot @ Vector((0, 0, .008)), (sx - .03, sy - .03, .016), kit.wood, tile=.9, rot=rot)
    if cell is not None:
        face = c + rot @ Vector((0, -sy / 2 - .0005, sz * .5))
        label_quad(b, face, rot @ Vector((1, 0, 0)), Vector((0, 0, 1)), min(sx * .8, sz * 3.2), min(sx * .8, sz * 3.2) / 4,
                   cell, kit.stencil, atlas=stencil_uv, out=rot @ Vector((0, -1, 0)))


def paper_box(b, kit, center, size, yaw, cell, seed):
    """A small dovetailed box (candles, soap, matches) with a pasted paper label."""
    rot = Matrix.Rotation(yaw, 3, "Z")
    c = Vector(center)
    sx, sy, sz = size
    K.box(b, c + rot @ Vector((0, 0, sz / 2)), size, kit.split, tile=.6, rot=rot, grain=0,
          uv_offset=(random.Random(seed).random() * 4, 0))
    w = sx * .82
    label_quad(b, c + rot @ Vector((0, -sy / 2, sz * .5)), rot @ Vector((1, 0, 0)), Vector((0, 0, 1)), w, min(sz * .8, w / 2), cell,
               kit.labels, out=rot @ Vector((0, -1, 0)))


# ------------------------------------------------------------------ goods

def sack_body(b, kit, height, radius, fill, mat, seed, tied=True, content=None, slump=0.0, mark=None):
    """A sewn sack: two panels with side seams (an elliptic, pillow-like section),
    bottom ears, a slight belly, then either a gathered neck tied with cord and a
    flared tuft above the tie, or a rolled-down mouth over its contents. Slumped,
    leaned and creased with seeded noise; gathers fold toward the tie. `mark` is a
    stencil cell painted on the front panel (decal on the same surface)."""
    def smooth(t):
        t = max(0.0, min(1.0, t))
        return t * t * (3 - 2 * t)
    rng = random.Random(seed)
    lean = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * .035
    flat = rng.uniform(.80, .88)
    ph = rng.uniform(0, 6)
    ax, ay = radius * 1.1, radius * .88

    def profile(t):
        """Radius multiplier and height fraction along the sack (t = 0 base, 1 top)."""
        if tied:
            if t < .08:
                m = .74 + .26 * smooth(t / .08)
            elif t < .6:
                m = 1 + .05 * math.sin(math.pi * (t - .08) / .52)
            elif t < .84:
                m = 1 - .8 * smooth((t - .6) / .24)
            elif t < .88:
                m = .2
            else:
                m = .2 + .26 * smooth((t - .88) / .12)
            zf = t if t < .88 else .88 + (t - .88) * .75
        else:
            m = (.76 + .24 * smooth(t / .08)) if t < .08 else 1 + .05 * math.sin(math.pi * t)
            zf = t
        return m, zf

    def point(a, t, extra=0.0):
        m, zf = profile(t)
        ca, sa = math.cos(a), math.sin(a)
        r = m
        # Side seams at a = 0 and pi stand proud a little; bottom corners make ears.
        seam = math.exp(-((math.sin(a)) / .09) ** 2)
        r += .05 * seam * (1 - smooth((t - .7) / .15))
        ear = (1 - smooth(t / .14)) * .12 * abs(ca) ** 10
        x, y = ax * r * ca * (1 + ear), ay * r * sa
        z = height * zf + (.03 * radius * abs(ca) ** 10 * (1 - smooth(t / .1)) if t < .1 else 0)
        p = Vector((x, y, z))
        crease = .028 * radius / .2 * K.fbm((p.x * 1.3, p.y * 1.3, p.z), 6, seed)
        crease += .01 * K.vnoise((p.x, p.y, p.z), 18, seed + 1)
        gather = smooth((t - .45) / .38) if tied else smooth((t - .75) / .2)
        if tied and t > .88:
            gather = 1.0 - smooth((t - .92) / .08) * .3
        crease += .03 * radius / .2 * gather * math.sin(8 * a + ph + 2.5 * K.vnoise((p.x, p.y, p.z), 5, seed + 2)) * (1 if t < .88 else 1.6)
        if tied and t >= .999:  # a ragged, flared rim of cloth above the tie
            p.z += .018 * math.sin(5 * a + ph)
        radial = Vector((ca, sa * flat, 0))
        spread = 1 + slump * (1 - min(t, 1.0)) ** 2 * 1.3
        q = Vector((p.x * spread, p.y * spread * flat, p.z * (1 - .3 * slump)))
        q += radial * (crease * min(1.0, t * 8) + extra)
        q += lean * min(zf, 1.0) * height / .5
        return q

    sides, rows = 20, 14
    ts = [j / rows for j in range(rows + 1)]
    grid = []
    perim = math.pi * (ax + ay)
    arcs = [0.0]
    for j, t in enumerate(ts):
        grid.append([point(math.tau * k / sides, t) for k in range(sides + 1)])
        if j:
            arcs.append(arcs[-1] + (grid[j][0] - grid[j - 1][0]).length * .5 + (grid[j][sides // 4] - grid[j - 1][sides // 4]).length * .5)
    tile = .35
    ids = [[b.vert(p, .66 + .34 * min(1.0, p.z / .3)) for p in row] for row in grid]
    for j in range(rows):
        for k in range(sides):
            u0, u1 = k / sides * perim * profile(ts[j])[0] / tile, (k + 1) / sides * perim * profile(ts[j])[0] / tile
            b.face([ids[j][k], ids[j][k + 1], ids[j + 1][k + 1], ids[j + 1][k]],
                   [(u0, arcs[j] / tile), (u1, arcs[j] / tile), (u1, arcs[j + 1] / tile), (u0, arcs[j + 1] / tile)], mat)
    centre = b.vert(Vector((0, 0, 0)) + lean * 0, .6)
    for k in range(sides):
        b.face([centre, ids[0][k + 1], ids[0][k]], [(.5, .5), (.5 + .5 * math.cos(math.tau * (k + 1) / sides), .5), (.5, .5 + .5 * math.sin(math.tau * k / sides))], mat)
    top_z = height * profile(1.0)[1] * (1 - .3 * slump)
    if tied:
        neck = point(0, .86)
        tie_c = Vector((0, 0, neck.z)) + lean * (neck.z / max(height, 1e-6)) * height / .5
        K.wraps(b, tie_c, (0, 0, 1), .2 * radius * .95, kit.rope, turns=3, width=.024, thickness=.005, sides=4, seg=8)
        # A loose cord end.
        K.tube(b, [tie_c + Vector((.2 * radius, 0, 0)), tie_c + Vector((.2 * radius + .03, -.01, -.05)), tie_c + Vector((.2 * radius + .035, -.02, -.1))], .004, kit.rope, sides=3, tile=.05)
    elif content is not None:
        # Rolled-down mouth and the contents heaped inside it.
        lip = []
        for k in range(sides + 1):
            a = math.tau * k / sides
            p = point(a, 1.0)
            out = Vector((math.cos(a), math.sin(a) * flat, 0))
            lip.append([p, p + out * .02 + Vector((0, 0, .018)), p + out * .035, p + out * .03 + Vector((0, 0, -.025)), p + out * .012 + Vector((0, 0, -.03))])
        lid = [[b.vert(q, .9) for q in col] for col in lip]
        for k in range(sides):
            for s in range(4):
                b.face([lid[k][s], lid[k + 1][s], lid[k + 1][s + 1], lid[k][s + 1]], [(k * .05, s * .02), ((k + 1) * .05, s * .02), ((k + 1) * .05, (s + 1) * .02), (k * .05, (s + 1) * .02)], mat)
        hz = top_z * (.5 + .42 * fill)
        c = lean * (hz / max(top_z, 1e-6)) * height / .5
        K.lathe(b, [(ax * .98, hz - .02), (ax * .75, hz + .012), (ax * .4, hz + .028), (0, hz + .034)], content, sides=16, tile=.25,
                center=(c.x, c.y, 0), squash=(1.0, ay / ax * flat))
    if mark is not None:
        # Painted mark on the front panel (Blender -Y faces the customer), lifted 2 mm.
        n_a, n_t = 6, 3
        a0, a1 = -math.pi / 2 - .62, -math.pi / 2 + .62
        t0, t1 = (.2, .52) if tied else (.2, .62)
        patch = [[b.vert(point(a0 + (a1 - a0) * i / n_a, t0 + (t1 - t0) * j / n_t, .003)) for i in range(n_a + 1)] for j in range(n_t + 1)]
        for j in range(n_t):
            for i in range(n_a):
                b.face([patch[j][i], patch[j][i + 1], patch[j + 1][i + 1], patch[j + 1][i]],
                       [stencil_uv(mark, i / n_a, j / n_t), stencil_uv(mark, (i + 1) / n_a, j / n_t),
                        stencil_uv(mark, (i + 1) / n_a, (j + 1) / n_t), stencil_uv(mark, i / n_a, (j + 1) / n_t)], kit.stencil)


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
    kit = Kit(["kit_burlap", "kit_osnaburg", "kit_rope", "kit_beans", "kit_coffee", "kit_flour", "kit_salt", "kit_pork",
               "kit_paper", "kit_iron", "kit_wood", "kit_split", "kit_bark", "kit_endgrain", "kit_leather", "kit_canvas",
               "kit_glass", "kit_stencil", "kit_labels", "kit_tin", "kit_crock"])
    objs = []
    spec = {  # item: (material, height at full, radius, tied, content)
        "flour": (kit.osnaburg, .62, .2, True, None),
        "beans": (kit.burlap, .5, .19, False, kit.beans),
        "coffee": (kit.burlap, .42, .16, False, kit.coffee),
        "salt": (kit.osnaburg, .36, .15, True, None),
    }
    for item, (mat, h, r, tied, content) in spec.items():
        for fill in range(4):
            b = K.MeshBuilder()
            f = (fill + 1) / 4
            sack_body(b, kit, h * (.55 + .45 * f), r * (.9 + .1 * f), f, mat, 900 + fill * 7 + len(item), tied, content,
                      slump=.45 * (1 - f), mark=STENCIL[item])
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
    # Powder: a small keg with iron hoops and its painted mark.
    b = K.MeshBuilder()
    keg(b, kit, (0, 0, 0), .12, .25, cell=STENCIL["powder"])
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
    # Yard and camp freight (Wave C): a marked crate, a nail keg, a stoneware jug.
    b = K.MeshBuilder()
    crate(b, kit, (0, 0, 0), (.62, .42, .4), 0, 1100, cell=STENCIL["mark"])
    objs.append(obj(b, "crate_mark", kit))
    b = K.MeshBuilder()
    keg(b, kit, (0, 0, 0), .16, .4, cell=STENCIL["nails"])
    objs.append(obj(b, "keg_nails", kit))
    b = K.MeshBuilder()
    crock(b, kit, (0, 0, 0), .1, .34, jug=True)
    objs.append(obj(b, "jug", kit))
    K.export_glb(objs, OUT / "goods.glb")


def bench():
    """A puncheon bench for the yard: a split half-log, flat face up, on four splayed
    round legs driven through auger holes (assets/props/bench.glb)."""
    kit = Kit(["kit_split", "kit_bark", "kit_endgrain"])
    b = K.MeshBuilder()
    length, r, seat = 1.6, .17, .46
    n = 10
    rng = random.Random(1201)
    rings = []
    for j in range(n + 1):
        x = -length / 2 + length * j / n
        ring = []
        wob = .006 * K.vnoise((x, 0, 0), 4, 1202)
        # Section: the flat split face on top, the rounded bark underside below it.
        for k in range(9):
            a = math.pi + math.pi * k / 8
            ring.append(Vector((x, math.cos(a) * r * (1 + wob), seat + math.sin(a) * r * .55)))
        rings.append(ring)
    ids = [[b.vert(p, .7 + .3 * min(1.0, p.z / seat)) for p in ring] for ring in rings]
    for j in range(n):
        for k in range(8):
            b.face([ids[j][k], ids[j][k + 1], ids[j + 1][k + 1], ids[j + 1][k]],
                   [(k * .06, j * length / n), ((k + 1) * .06, j * length / n), ((k + 1) * .06, (j + 1) * length / n), (k * .06, (j + 1) * length / n)], kit.bark)
        b.face([ids[j][8], ids[j][0], ids[j + 1][0], ids[j + 1][8]],
               [(.0, j * length / n), (2 * r, j * length / n), (2 * r, (j + 1) * length / n), (.0, (j + 1) * length / n)], kit.split, True)
    for e, ring in ((0, ids[0]), (1, ids[n])):
        uv = [(.5 + .5 * math.cos(math.pi + math.pi * k / 8), .5 + .5 * math.sin(math.pi + math.pi * k / 8)) for k in range(9)]
        face, fuv = list(ring), uv
        if e == 0:
            face, fuv = face[::-1], fuv[::-1]
        b.face(face, fuv, kit.endgrain, True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            top = Vector((sx * (length / 2 - .2), sy * .07, seat + .02))
            foot = Vector((sx * (length / 2 - .07), sy * .2, 0))
            K.tube(b, [foot + Vector((0, 0, -.03)), top], [.032, .028], kit.split, sides=6, tile=.4, cap_mat=kit.endgrain,
                   wobble=.06, seed=1210 + sx * 2 + sy)
    o = b.build("bench", kit.mats)
    K.export_glb([o], K.ASSETS / "props" / "bench.glb")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not argv or "bench" in argv:
        bench()
        bpy.ops.wm.read_factory_settings(use_empty=True)
    if not argv or "stall" in argv:
        stall()
    if not argv or "goods" in argv:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        goods()
    print("BUILT store")
