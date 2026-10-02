// Game-ready trees, shrubs, saplings and ground-cover clumps (VISUAL_UPGRADE_PLAN Stage 4).
//
//   node tools/art/build_trees.mjs            # every asset
//   node tools/art/build_trees.mjs black_oak  # names or name prefixes
//   node tools/art/build_trees.mjs --stats    # print, write nothing
//
// EZ-Tree 1.1.0 (MIT, tools/art/package.json) grows the branch skeletons and leaf cards from
// its presets plus the overrides below, with explicit seeds; this script then does what the
// Blender normalise step would: scale to species height, re-map bark UVs in metres (layer of
// the shared bark array), map every leaf card to a tile of its species atlas
// (tools/art/build_foliage_atlases.py), bend card normals outward from the crown, write wind
// weights, and emit a <= 500-triangle `<name>_distant.glb` built from the same cards.
//
// Mesh contract (Assets.plant / Assets.understory, shaders/bark.gdshader, foliage.gdshader):
//   surface 0 = bark, surface 1 = leaf cards; COLOR_0 r = wind weight (0 at the root, 1 at
//   the outer crown), g = per-card random (season timing, hue), b = 0, a = 1.
// Same inputs give byte-identical GLBs.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Document, NodeIO } from '@gltf-transform/core';

const noop = () => {};
globalThis.document = { createElementNS: () => ({ addEventListener: noop, removeEventListener: noop, style: {} }) };
const { Tree } = await import('@dgreenheck/ez-tree');

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..');
const REGIONS = JSON.parse(fs.readFileSync(path.join(HERE, 'foliage_regions.json'), 'utf8'));
const QUAD = [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]]; // tree atlas tiles

// ------------------------------------------------------------------ recipes
// height: metres (whole mesh AABB); trunk: base radius in metres; bark: tile size in metres
// (u around, v along); tiles: atlas rectangles; billboard 'single' = one quad per leaf.
const OAK = { tiles: QUAD, bark: [1.0, 1.0], crown: 'round', distant: true };
const CONIFER = { tiles: QUAD, crown: 'cone', distant: true };
// Black oak: a short bole splitting into a few ascending limbs, broad rounded crown.
const oak = (height, seed, branch, leaves) => ({ ...OAK, height, trunk: .55, preset: 'Oak Medium', seed, o: {
  branch: { levels: 3, sections: { 0: 7, 1: 4, 2: 3, 3: 1 }, segments: { 0: 8, 1: 4, 2: 3, 3: 3 }, ...branch },
  leaves: { billboard: 'single', sizeVariance: .3, angle: 50, start: .1, ...leaves } } });
// Evergreens: EZ-Tree shortens branches up the stem, so `start` sets the clear bole and
// `length[1]` the crown's base radius; `angle[1]` > 90 droops (fir), < 90 rises (pine).
const conifer = (height, trunk, bark, preset, seed, branch, leaves) => ({ ...CONIFER, height, trunk, bark, preset, seed, o: {
  branch: { sections: { 0: 10, 1: 3 }, segments: { 0: 7, 1: 3 }, ...branch },
  leaves: { billboard: 'double', sizeVariance: .3, ...leaves } } });
const TREES = {
  black_oak: oak(15.0, 1101, { children: { 0: 6, 1: 4, 2: 2 }, length: { 0: 26, 1: 17, 2: 12.4, 3: 7.2 }, start: { 1: .35, 2: .06, 3: .12 },
    gnarliness: { 0: .05, 1: -.12, 2: -.15, 3: .09 }, angle: { 1: 42, 2: 52, 3: 34 } }, { count: 12, size: 5.0 }),
  black_oak_2: oak(13.6, 1207, { children: { 0: 5, 1: 4, 2: 2 }, length: { 0: 24, 1: 18, 2: 12.4, 3: 7.2 }, start: { 1: .32, 2: .06, 3: .12 },
    gnarliness: { 0: .12, 1: -.1, 2: -.15, 3: .09 }, angle: { 1: 50, 2: 55, 3: 34 } }, { count: 14, size: 5.0 }),
  black_oak_3: oak(16.4, 1313, { children: { 0: 6, 1: 3, 2: 2 }, length: { 0: 30, 1: 16, 2: 11, 3: 7.2 }, start: { 1: .4, 2: .06, 3: .12 },
    gnarliness: { 0: .03, 1: -.12, 2: -.15, 3: .09 }, angle: { 1: 38, 2: 52, 3: 34 } }, { count: 14, size: 5.2 }),
  // Ponderosa: tall clear bole, open crown in the upper half, upturned branch ends.
  ponderosa: conifer(30, .45, [1.4, 1.4], 'Pine Medium', 2101, { children: { 0: 34 }, length: { 0: 50, 1: 12 }, radius: { 0: 1.05, 1: .3 },
    start: { 1: .45 }, angle: { 1: 75 }, gnarliness: { 1: .12 } }, { count: 18, size: 2.6, angle: 25, start: .35 }),
  ponderosa_2: conifer(27, .42, [1.4, 1.4], 'Pine Medium', 2207, { children: { 0: 30 }, length: { 0: 50, 1: 13 }, radius: { 0: 1.0, 1: .3 },
    start: { 1: .5 }, angle: { 1: 80 }, gnarliness: { 0: .07, 1: .12 } }, { count: 18, size: 2.8, angle: 25, start: .35 }),
  ponderosa_3: conifer(33, .5, [1.4, 1.4], 'Pine Large', 2311, { children: { 0: 36 }, length: { 0: 65, 1: 15 }, radius: { 0: 1.2, 1: .32 },
    start: { 1: .5 }, angle: { 1: 70 }, gnarliness: { 1: .12 } }, { count: 17, size: 3.2, angle: 25, start: .35 }),
  // Douglas fir: dense spire with drooping branches.
  douglas_fir: conifer(33, .5, [1.0, 1.0], 'Pine Medium', 3101, { children: { 0: 56 }, length: { 0: 50, 1: 11 }, radius: { 0: 1.05, 1: .28 },
    start: { 1: .22 }, angle: { 1: 105 }, force: { strength: -.004 } }, { count: 13, size: 2.3, angle: 35, start: .1 }),
  douglas_fir_2: conifer(29, .46, [1.0, 1.0], 'Pine Medium', 3209, { children: { 0: 52 }, length: { 0: 48, 1: 12 }, radius: { 0: 1.0, 1: .28 },
    start: { 1: .28 }, angle: { 1: 110 }, force: { strength: -.006 } }, { count: 13, size: 2.4, angle: 35, start: .1 }),
  douglas_fir_3: conifer(37, .55, [1.0, 1.0], 'Pine Large', 3307, { children: { 0: 58 }, length: { 0: 62, 1: 13 }, radius: { 0: 1.2, 1: .28 },
    start: { 1: .25 }, angle: { 1: 108 }, force: { strength: -.004 } }, { count: 12, size: 2.8, angle: 35, start: .1 }),
  // Incense cedar: narrow, dense cone of flat sprays.
  incense_cedar: conifer(25, .5, [1.0, 2.0], 'Pine Medium', 4101, { children: { 0: 56 }, length: { 0: 50, 1: 8 }, radius: { 0: 1.2, 1: .28 },
    start: { 1: .12 }, angle: { 1: 85 }, force: { strength: .004 } }, { count: 13, size: 2.4, angle: 45, start: .05 }),
  incense_cedar_2: conifer(22, .45, [1.0, 2.0], 'Pine Medium', 4203, { children: { 0: 52 }, length: { 0: 48, 1: 8.5 }, radius: { 0: 1.1, 1: .28 },
    start: { 1: .15 }, angle: { 1: 80 }, force: { strength: .004 } }, { count: 13, size: 2.5, angle: 45, start: .05 }),
  incense_cedar_3: conifer(27.5, .55, [1.0, 2.0], 'Pine Large', 4307, { children: { 0: 58 }, length: { 0: 62, 1: 10 }, radius: { 0: 1.3, 1: .28 },
    start: { 1: .12 }, angle: { 1: 88 }, force: { strength: .004 } }, { count: 12, size: 2.9, angle: 45, start: .05 }),
};


// Understory. Shrub and sapling budgets: 800 triangles (tools/art/budgets.json).
const R = (names) => names.map((n) => REGIONS[n]);
const SHRUB = { crown: 'round', distant: false };
// Shrubs: a tuft of stems from the ground (EZ-Tree Bush presets), few bark rings, double
// leaf cards carrying whole sprays from the understory atlas.
const shrub = (height, trunk, tiles, preset, seed, branch, leaves) => ({ ...SHRUB, height, trunk, bark: [.3, .3], tiles: R(tiles), preset, seed, o: {
  branch: { levels: 2, sections: { 0: 1, 1: 2, 2: 1, 3: 1 }, segments: { 0: 3, 1: 3, 2: 3, 3: 3 }, ...branch },
  leaves: { billboard: 'double', sizeVariance: .3, ...leaves } } });
const PLANTS = {
  manzanita: shrub(1.6, .05, ['manzanita_0', 'manzanita_1'], 'Bush 2', 5101, { children: { 0: 7, 1: 2 }, gnarliness: { 1: .25 } }, { count: 4, size: 7.0, angle: 50 }),
  toyon: shrub(2.6, .07, ['toyon_0', 'toyon_1'], 'Bush 1', 5307, { children: { 0: 6, 1: 2 } }, { count: 4, size: 8.0, angle: 50 }),
  deerbrush: shrub(1.8, .05, ['deerbrush_0'], 'Bush 2', 5401, { children: { 0: 8, 1: 2 }, angle: { 1: 28 } }, { count: 3, size: 8.0, angle: 45 }),
  willow: shrub(4.2, .09, ['willow_0', 'willow_1'], 'Bush 2', 5503, { children: { 0: 7, 1: 2 }, sections: { 0: 1, 1: 3, 2: 1, 3: 1 }, angle: { 1: 16, 2: 22 }, length: { 1: 24 } }, { count: 3, size: 8.5, angle: 30 }),
  alder: shrub(6.5, .14, ['alder_0'], 'Aspen Small', 5701, { children: { 0: 6, 1: 3 }, sections: { 0: 3, 1: 2, 2: 1 }, segments: { 0: 4, 1: 3, 2: 3 } }, { count: 3, size: 7.0, angle: 35 }),
  fir_sapling: { crown: 'cone', distant: false, height: 2.2, trunk: .04, bark: [.3, .3], tiles: QUAD, preset: 'Pine Small', seed: 5801, o: {
    branch: { children: { 0: 22 }, sections: { 0: 4, 1: 1 }, segments: { 0: 4, 1: 3 }, start: { 1: .1 }, length: { 1: 11 } },
    leaves: { billboard: 'double', count: 6, size: 3.4, sizeVariance: .3, angle: 35 } } },
};


// ------------------------------------------------------------------ helpers
function rng(seed) { // mulberry32
  let a = seed >>> 0;
  return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
function merge(target, source) {
  for (const [k, v] of Object.entries(source)) {
    if (v && typeof v === 'object' && !Array.isArray(v)) merge(target[k] ??= {}, v); else target[k] = v;
  }
}
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const len = (a) => Math.hypot(a[0], a[1], a[2]);
const norm = (a) => { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
const lerp3 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));

function grow(recipe) {
  const tree = new Tree();
  tree.loadPreset(recipe.preset);
  merge(tree.options, recipe.o);
  tree.options.seed = recipe.seed;
  tree.options.bark.textured = false;
  const branches = [];
  const original = tree.generateBranch.bind(tree);
  tree.generateBranch = (b) => {
    branches.push({ start: tree.branches.verts.length / 3, sections: b.sectionCount, segments: b.segmentCount, level: b.level });
    original(b);
  };
  tree.generate();
  return { tree, branches };
}

// ------------------------------------------------------------------ mesh building
function buildPlant(name, recipe) {
  const { tree, branches } = grow(recipe);
  const bg = tree.branchesMesh.geometry, lg = tree.leavesMesh.geometry;
  const bp = Array.from(bg.getAttribute('position').array);
  const bn = Array.from(bg.getAttribute('normal').array);
  const bi = Array.from(bg.index.array);
  const lp = Array.from(lg.getAttribute('position').array);
  const li = Array.from(lg.index.array);
  let minY = Infinity, maxY = -Infinity;
  for (const arr of [bp, lp]) for (let i = 1; i < arr.length; i += 3) { minY = Math.min(minY, arr[i]); maxY = Math.max(maxY, arr[i]); }
  const s = recipe.height / (maxY - minY);
  const scale = (arr) => { for (let i = 0; i < arr.length; i += 3) { arr[i] *= s; arr[i + 1] = (arr[i + 1] - minY) * s; arr[i + 2] *= s; } };
  scale(bp); scale(lp);
  const H = recipe.height;
  // Trunk base radius: widen or thin the trunk's first ring to the recipe (keeps colliders honest).
  const trunk = branches[0];
  const ring0 = [];
  for (let j = 0; j < trunk.segments; j++) ring0.push(trunk.start + j);
  let c0 = [0, 0, 0];
  for (const v of ring0) c0 = [c0[0] + bp[v * 3] / ring0.length, c0[1] + bp[v * 3 + 1] / ring0.length, c0[2] + bp[v * 3 + 2] / ring0.length];
  const r0 = ring0.reduce((m, v) => m + Math.hypot(bp[v * 3] - c0[0], bp[v * 3 + 2] - c0[2]), 0) / ring0.length;
  const widen = recipe.trunk / r0;
  // Radial correction fades out up the trunk, so branches keep their joints.
  for (let r = 0; r <= trunk.sections; r++) {
    const f = 1 + (widen - 1) * clamp(1 - r / Math.max(2, trunk.sections * 0.5));
    const base = trunk.start + r * (trunk.segments + 1);
    let c = [0, 0, 0];
    for (let j = 0; j < trunk.segments; j++) c = [c[0] + bp[(base + j) * 3] / trunk.segments, c[1], c[2] + bp[(base + j) * 3 + 2] / trunk.segments];
    for (let j = 0; j <= trunk.segments; j++) {
      const v = base + j;
      bp[v * 3] = c[0] + (bp[v * 3] - c[0]) * f; bp[v * 3 + 2] = c[2] + (bp[v * 3 + 2] - c[2]) * f;
    }
  }
  // Bark UVs in metres (cylindrical, continuous along each branch) and wind weights.
  const bv = bp.length / 3;
  const buv = new Float32Array(bv * 2), bcol = new Uint8Array(bv * 4);
  const [tw, th] = recipe.bark || [1, 1];
  for (const b of branches) {
    const ringCenter = (r) => {
      const base = b.start + r * (b.segments + 1); let c = [0, 0, 0];
      for (let j = 0; j < b.segments; j++) c = [c[0] + bp[(base + j) * 3], c[1] + bp[(base + j) * 3 + 1], c[2] + bp[(base + j) * 3 + 2]];
      return [c[0] / b.segments, c[1] / b.segments, c[2] / b.segments];
    };
    const c0b = ringCenter(0);
    const radius = Math.hypot(bp[b.start * 3] - c0b[0], bp[b.start * 3 + 1] - c0b[1], bp[b.start * 3 + 2] - c0b[2]);
    const around = Math.max(1, Math.round(2 * Math.PI * radius / tw));
    let along = 0, prev = c0b;
    for (let r = 0; r <= b.sections; r++) {
      const c = ringCenter(r);
      along += len(sub(c, prev)); prev = c;
      for (let j = 0; j <= b.segments; j++) {
        const v = b.start + r * (b.segments + 1) + j;
        buv[v * 2] = (j / b.segments) * around;
        buv[v * 2 + 1] = along / th;
        const y = bp[v * 3 + 1] / H;
        const reach = Math.hypot(bp[v * 3], bp[v * 3 + 2]) / (H * .5);
        const w = b.level === 0 ? 0.3 * y * y : clamp(0.25 + 0.2 * b.level + 0.4 * reach + 0.2 * y);
        bcol[v * 4] = Math.round(clamp(w) * 255); bcol[v * 4 + 3] = 255;
      }
    }
  }
  // Leaf cards: quads of 4 vertices in EZ-Tree order (0,1)(0,0)(1,0)(1,1).
  const random = rng(recipe.seed * 7 + 3);
  const lv = lp.length / 3;
  const quads = lv / 4;
  const perLeaf = (recipe.o.leaves?.billboard ?? 'double') === 'double' ? 2 : 1;
  let cc = [0, 0, 0];
  for (let v = 0; v < lv; v++) cc = [cc[0] + lp[v * 3] / lv, cc[1] + lp[v * 3 + 1] / lv, cc[2] + lp[v * 3 + 2] / lv];
  let crownR = 0;
  for (let v = 0; v < lv; v++) crownR = Math.max(crownR, Math.hypot(lp[v * 3] - cc[0], lp[v * 3 + 2] - cc[2]));
  const luv = new Float32Array(lv * 2), lcol = new Uint8Array(lv * 4), lnrm = new Float32Array(lv * 3);
  const cardTile = [], cardRand = [];
  for (let q = 0; q < quads; q++) {
    if (q % perLeaf === 0) { cardTile.push(Math.floor(random() * recipe.tiles.length)); cardRand.push(random()); }
    const tile = recipe.tiles[cardTile[cardTile.length - 1]];
    const g = cardRand[cardRand.length - 1];
    const ids = [q * 4, q * 4 + 1, q * 4 + 2, q * 4 + 3];
    const P = ids.map((v) => [lp[v * 3], lp[v * 3 + 1], lp[v * 3 + 2]]);
    const n = norm(cross(sub(P[1], P[0]), sub(P[2], P[1])));
    const inset = 0.0015;
    const UV = [[0, 1], [0, 0], [1, 0], [1, 1]]; // EZ-Tree: v = 0 at the leaf base
    ids.forEach((v, k) => {
      const [u, w] = UV[k];
      luv[v * 2] = tile[0] + inset + u * (tile[2] - 2 * inset);
      luv[v * 2 + 1] = tile[1] + inset + (1 - w) * (tile[3] - 2 * inset); // base at the tile's bottom
      const p = P[k];
      const out = recipe.crown === 'cone'
        ? norm([p[0], (p[1] - cc[1]) * 0.35 + H * 0.08, p[2]])
        : norm(sub(p, [cc[0], cc[1] - (maxY - minY) * s * 0.1, cc[2]]));
      const nn = norm(lerp3(n[1] * out[1] + n[0] * out[0] + n[2] * out[2] >= 0 ? n : [-n[0], -n[1], -n[2]], out, 0.8));
      lnrm.set(nn, v * 3);
      const reach = Math.hypot(p[0] - cc[0], p[2] - cc[2]) / Math.max(crownR, .01);
      const wind = clamp(0.35 + 0.35 * reach + 0.3 * p[1] / H + (w > 0.5 ? 0.1 : 0));
      lcol[v * 4] = Math.round(wind * 255); lcol[v * 4 + 1] = Math.round(g * 255); lcol[v * 4 + 3] = 255;
    });
  }
  const result = {
    bark: { pos: bp, nrm: bn, uv: Array.from(buv), col: Array.from(bcol), idx: bi },
    leaves: { pos: lp, nrm: Array.from(lnrm), uv: Array.from(luv), col: Array.from(lcol), idx: li },
    H, trunkRadius: recipe.trunk, cards: quads,
  };
  if (recipe.distant) result.distant = buildDistant(result, recipe);
  return result;
}

function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }

// <= 500 triangles: a 6-sided trunk and a seeded, stratified subset of the crown's cards,
// enlarged so the silhouette keeps its coverage.
function buildDistant(full, recipe) {
  const pos = [], nrm = [], uv = [], col = [], idx = [];
  const sides = 6, rings = 3, H = full.H;
  const top = recipe.crown === 'cone' ? 0.92 : 0.45;
  for (let r = 0; r <= rings; r++) {
    const y = H * top * r / rings, rad = full.trunkRadius * (1 - 0.75 * r / rings);
    for (let j = 0; j <= sides; j++) {
      const a = 2 * Math.PI * j / sides;
      pos.push(Math.cos(a) * rad, y, Math.sin(a) * rad); nrm.push(Math.cos(a), 0, Math.sin(a));
      uv.push(j / sides * 2, y / (recipe.bark?.[1] ?? 1)); col.push(Math.round(0.3 * (y / H) ** 2 * 255), 0, 0, 255);
    }
  }
  for (let r = 0; r < rings; r++) for (let j = 0; j < sides; j++) {
    const a = r * (sides + 1) + j, b = a + 1, c = a + sides + 1, d = c + 1;
    idx.push(a, c, b, b, c, d);
  }
  const bark = { pos, nrm, uv, col, idx };
  const L = full.leaves, cards = L.pos.length / 12;
  // 180 cards: enough silhouette at 60 m+, without the overdraw of filling the budget.
  const want = Math.min(180, Math.floor((500 - idx.length / 3) / 2));
  const random = rng(recipe.seed * 13 + 5);
  const order = Array.from({ length: cards }, (_, i) => i).sort((a, b) => (L.pos[a * 12 + 1] - L.pos[b * 12 + 1]));
  const pick = [];
  for (let k = 0; k < want; k++) pick.push(order[Math.min(cards - 1, Math.floor((k + random()) * cards / want))]);
  const grow = Math.sqrt(cards / want) * 0.72;
  const lp = [], ln = [], lu = [], lc = [], li = [];
  for (const q of pick) {
    let c = [0, 0, 0];
    for (let k = 0; k < 4; k++) c = [c[0] + L.pos[q * 12 + k * 3] / 4, c[1] + L.pos[q * 12 + k * 3 + 1] / 4, c[2] + L.pos[q * 12 + k * 3 + 2] / 4];
    const base = lp.length / 3;
    for (let k = 0; k < 4; k++) {
      const v = q * 4 + k;
      const p = [L.pos[v * 3], L.pos[v * 3 + 1], L.pos[v * 3 + 2]];
      lp.push(...lerp3(c, p, grow));
      ln.push(L.nrm[v * 3], L.nrm[v * 3 + 1], L.nrm[v * 3 + 2]);
      lu.push(L.uv[v * 2], L.uv[v * 2 + 1]);
      lc.push(L.col[v * 4], L.col[v * 4 + 1], 0, 255);
    }
    li.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }
  return { bark, leaves: { pos: lp, nrm: ln, uv: lu, col: lc, idx: li }, H };
}

// ------------------------------------------------------------------ ground cover (no EZ-Tree)
// Crossed cards rooted at the origin. Grass: 3 quads, fern: 7 arching fronds of 2 segments.
function cardPlant(name, kind, tiles, seed, size) {
  const random = rng(seed);
  const pos = [], nrm = [], uv = [], col = [], idx = [];
  const quad = (p0, p1, p2, p3, tile, w0, w1, g, n) => {
    const b = pos.length / 3;
    for (const [p, u, v, w] of [[p0, 0, 1, w0], [p1, 1, 1, w0], [p2, 1, 0, w1], [p3, 0, 0, w1]]) {
      pos.push(...p); nrm.push(...n);
      uv.push(tile[0] + 0.002 + u * (tile[2] - 0.004), tile[1] + 0.002 + v * (tile[3] - 0.004));
      col.push(Math.round(w * 255), Math.round(g * 255), 0, 255);
    }
    idx.push(b, b + 1, b + 2, b, b + 2, b + 3);
  };
  if (kind === 'grass') {
    const [w, h] = size;
    for (let k = 0; k < 3; k++) {
      const a = k * Math.PI / 3 + random() * 0.3, ca = Math.cos(a), sa = Math.sin(a);
      const lean = 0.08 * h;
      const tile = tiles[Math.floor(random() * tiles.length)];
      const g = random();
      quad([-ca * w / 2, 0, -sa * w / 2], [ca * w / 2, 0, sa * w / 2], [ca * w / 2 - sa * lean, h, sa * w / 2 + ca * lean], [-ca * w / 2 - sa * lean, h, -sa * w / 2 + ca * lean],
        tile, 0, 1, g, [0, 1, 0]);
    }
  } else { // fern
    const fronds = 7;
    for (let k = 0; k < fronds; k++) {
      const a = (k + random() * 0.6) * 2 * Math.PI / fronds;
      const dir = [Math.cos(a), 0, Math.sin(a)], side = [-Math.sin(a), 0, Math.cos(a)];
      const L = size[1] * (0.75 + 0.35 * random()), W = size[0] * (0.8 + 0.3 * random());
      const rise = 0.75 + 0.2 * random();
      const p = (t, sgn) => {
        const out = L * t, up = L * (rise * t - 0.9 * t * t * 0.8);
        return [dir[0] * out * 0.85 + side[0] * W / 2 * sgn * (1 - 0.3 * t), Math.max(0.02, up), dir[2] * out * 0.85 + side[2] * W / 2 * sgn * (1 - 0.3 * t)];
      };
      const tile = tiles[Math.floor(random() * tiles.length)];
      const half = [tile[0], tile[1] + tile[3] / 2, tile[2], tile[3] / 2];
      const low = [tile[0], tile[1] + tile[3] / 2, tile[2], tile[3] / 2];
      const g = random();
      // Bottom half of the frond tile: t 0..0.5; top half: t 0.5..1.
      quad(p(0, -1), p(0, 1), p(0.5, 1), p(0.5, -1), low, 0, 0.5, g, [0, 1, 0]);
      quad(p(0.5, -1), p(0.5, 1), p(1, 1), p(1, -1), [tile[0], tile[1], tile[2], tile[3] / 2], 0.5, 1, g, [0, 1, 0]);
    }
  }
  return { leaves: { pos, nrm, uv, col, idx }, bark: null, H: size[1] };
}

const GROUND = {
  grass_clump: () => cardPlant('grass_clump', 'grass', R(['grass_0', 'grass_1', 'grass_2', 'grass_3', 'grass_4']), 6101, [0.75, 0.42]),
  sedge_clump: () => cardPlant('sedge_clump', 'grass', R(['sedge_0', 'sedge_1', 'sedge_2']), 6307, [0.6, 0.6]),
  fern: () => cardPlant('fern', 'fern', R(['fern_0', 'fern_1', 'fern_2', 'fern_3']), 6401, [0.32, 0.85]),
};

// ------------------------------------------------------------------ GLB output
async function writeGlb(file, parts) {
  const doc = new Document();
  const buffer = doc.createBuffer();
  const mesh = doc.createMesh(path.basename(file, '.glb'));
  for (const [label, g] of parts) {
    if (!g) continue;
    const prim = doc.createPrimitive().setMaterial(doc.createMaterial(label).setDoubleSided(label === 'leaves'));
    const vcount = g.pos.length / 3;
    prim.setAttribute('POSITION', doc.createAccessor().setType('VEC3').setArray(new Float32Array(g.pos)).setBuffer(buffer));
    prim.setAttribute('NORMAL', doc.createAccessor().setType('VEC3').setArray(new Float32Array(g.nrm.map((v, i) => v))).setBuffer(buffer));
    prim.setAttribute('TEXCOORD_0', doc.createAccessor().setType('VEC2').setArray(new Float32Array(g.uv)).setBuffer(buffer));
    prim.setAttribute('COLOR_0', doc.createAccessor().setType('VEC4').setArray(new Uint8Array(g.col)).setNormalized(true).setBuffer(buffer));
    prim.setIndices(doc.createAccessor().setType('SCALAR').setArray(vcount < 65536 ? new Uint16Array(g.idx) : new Uint32Array(g.idx)).setBuffer(buffer));
    mesh.addPrimitive(prim);
  }
  doc.createScene('plant').addChild(doc.createNode(path.basename(file, '.glb')).setMesh(mesh));
  await new NodeIO().write(file, doc);
}

function normalizeNormals(g) {
  for (let i = 0; i < g.nrm.length; i += 3) {
    const n = norm([g.nrm[i], g.nrm[i + 1], g.nrm[i + 2]]);
    g.nrm[i] = n[0]; g.nrm[i + 1] = n[1]; g.nrm[i + 2] = n[2];
  }
}

const args = process.argv.slice(2);
const stats = args.includes('--stats');
const wanted = args.filter((a) => !a.startsWith('--'));
const match = (n) => wanted.length === 0 || wanted.some((w) => n === w || n.startsWith(w));
const report = [];
const tris = (g) => (g ? g.idx.length / 3 : 0);
for (const [name, recipe] of Object.entries(TREES)) {
  if (!match(name)) continue;
  const t = buildPlant(name, recipe);
  normalizeNormals(t.bark);
  report.push({ name, bark: tris(t.bark), leaves: tris(t.leaves), total: tris(t.bark) + tris(t.leaves), cards: t.cards, distant: tris(t.distant.bark) + tris(t.distant.leaves), height: recipe.height });
  if (!stats) {
    await writeGlb(path.join(ROOT, 'assets/trees', name + '.glb'), [['bark', t.bark], ['leaves', t.leaves]]);
    await writeGlb(path.join(ROOT, 'assets/trees', name + '_distant.glb'), [['bark', t.distant.bark], ['leaves', t.distant.leaves]]);
  }
}
for (const [name, recipe] of Object.entries(PLANTS)) {
  if (!match(name)) continue;
  const t = buildPlant(name, recipe);
  normalizeNormals(t.bark);
  report.push({ name, bark: tris(t.bark), leaves: tris(t.leaves), total: tris(t.bark) + tris(t.leaves), cards: t.cards, height: recipe.height });
  // Understory plants are one surface (one draw per chunk and pass): stems ride in the leaf
  // primitive flagged by COLOR_0.b = 1, which the foliage shader draws as opaque bark.
  if (!stats) await writeGlb(path.join(ROOT, 'assets/plants', name + '.glb'), [['leaves', mergeStems(t.bark, t.leaves)]]);
}

function mergeStems(bark, leaves) {
  const base = leaves.pos.length / 3;
  const col = bark.col.slice();
  for (let i = 0; i < col.length; i += 4) col[i + 2] = 255;
  return {
    pos: leaves.pos.concat(bark.pos), nrm: leaves.nrm.concat(bark.nrm),
    uv: leaves.uv.concat(bark.uv.map(() => 0)), col: leaves.col.concat(col),
    idx: leaves.idx.concat(bark.idx.map((i) => i + base)),
  };
}
for (const [name, make] of Object.entries(GROUND)) {
  if (!match(name)) continue;
  const t = make();
  report.push({ name, bark: 0, leaves: tris(t.leaves), total: tris(t.leaves), height: t.H });
  if (!stats) await writeGlb(path.join(ROOT, 'assets/plants', name + '.glb'), [['leaves', t.leaves]]);
}
for (const r of report) console.log(JSON.stringify(r));
