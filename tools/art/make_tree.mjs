// Headless EZ-Tree generator. Writes a GLB with one mesh: surface 0 = bark,
// surface 1 = leaf cards (UV 0..1 per card), matching asset_library.plant().
// Geometry only: Godot's bark/foliage shaders supply the textures.
//
//   node make_tree.mjs <preset> <seed> <out.glb> [overrides.json]
//   node make_tree.mjs --list
//
// Units are EZ-Tree's own (a large oak is ~100 tall), not metres; the Blender
// normalise step sets final height. Same preset + seed + overrides = same tree.
import fs from 'node:fs';
import { Document, NodeIO } from '@gltf-transform/core';

// EZ-Tree loads its preview textures at import time; give the loader a dummy image.
const noop = () => {};
globalThis.document = { createElementNS: () => ({ addEventListener: noop, removeEventListener: noop, style: {} }) };
const { Tree, TreePreset } = await import('@dgreenheck/ez-tree');

const [preset, seed, out, overridesPath] = process.argv.slice(2);
if (preset === '--list' || !out) {
  console.log(Object.keys(TreePreset).join('\n'));
  process.exit(preset === '--list' ? 0 : 2);
}

function merge(target, source) {
  for (const [key, value] of Object.entries(source)) {
    if (value && typeof value === 'object' && !Array.isArray(value)) merge(target[key] ??= {}, value);
    else target[key] = value;
  }
}

const tree = new Tree();
tree.loadPreset(preset);
tree.options.seed = Number(seed);
if (overridesPath) merge(tree.options, JSON.parse(fs.readFileSync(overridesPath, 'utf8')));
tree.generate();

const doc = new Document();
const buffer = doc.createBuffer();
const mesh = doc.createMesh(preset);
const report = {};
for (const [name, source] of [['bark', tree.branchesMesh], ['leaves', tree.leavesMesh]]) {
  const g = source.geometry;
  const prim = doc.createPrimitive().setMaterial(doc.createMaterial(name).setDoubleSided(name === 'leaves'));
  for (const [semantic, attribute, type] of [['POSITION', 'position', 'VEC3'], ['NORMAL', 'normal', 'VEC3'], ['TEXCOORD_0', 'uv', 'VEC2']]) {
    prim.setAttribute(semantic, doc.createAccessor().setType(type).setArray(new Float32Array(g.getAttribute(attribute).array)).setBuffer(buffer));
  }
  prim.setIndices(doc.createAccessor().setType('SCALAR').setArray(new Uint32Array(g.index.array)).setBuffer(buffer));
  mesh.addPrimitive(prim);
  report[name] = g.index.count / 3;
}
doc.createScene('tree').addChild(doc.createNode(preset).setMesh(mesh));
await new NodeIO().write(out, doc);
tree.branchesMesh.geometry.computeBoundingBox();
const height = +tree.branchesMesh.geometry.boundingBox.max.y.toFixed(2);
console.log(JSON.stringify({ preset, seed: Number(seed), out, triangles: report, height }));
