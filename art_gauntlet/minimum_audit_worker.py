"""Read saved vertex coordinates in one Blender process; never save or render."""
import json
import math
import sys
from pathlib import Path


def verify_coordinates(baseline, sample, allowed, declared):
    """Keep the routing trial's fixed 1e-6 coordinate tolerance."""
    if set(baseline) != set(sample):
        raise ValueError('Vertex index sets differ')
    if any(len(co) != 3 or not all(math.isfinite(x) for x in co)
           for co in [*baseline.values(), *sample.values()]):
        raise ValueError('Invalid vertex coordinates')
    changed = []
    for index in sorted(baseline):
        delta = [sample[index][axis] - baseline[index][axis] for axis in range(3)]
        if any(abs(x) > 1e-6 for x in delta):
            changed.append({'id': index, 'delta': delta})
    agreement = ([item['id'] for item in changed] == sorted(allowed)
                 and all(all(abs(x - y) <= 1e-6 for x, y in zip(item['delta'], declared))
                         for item in changed))
    return {'changed': changed, 'allowed_ids': sorted(allowed), 'declared_delta': declared,
            'agreement': agreement, 'passed': agreement and len(changed) == len(allowed)}


def coordinates(path, mesh):
    import bpy
    bpy.ops.wm.open_mainfile(filepath=str(Path(path).resolve()))
    obj = bpy.data.objects.get(mesh)
    if obj is None or obj.type != 'MESH':
        raise ValueError(f'Expected mesh missing: {mesh}')
    return {v.index: list(v.co) for v in obj.data.vertices}


def main():
    job = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text(encoding='utf-8'))
    baseline = coordinates(job['baseline'], job['mesh'])
    results = {}
    for name, sample in job['samples'].items():
        results[name] = verify_coordinates(baseline, coordinates(sample['scene'], job['mesh']),
                                           job['allowed_vertices'], sample['declared_delta'])
    Path(job['output']).write_text(json.dumps(results, indent=2, sort_keys=True), encoding='utf-8')


if __name__ == '__main__':
    main()
