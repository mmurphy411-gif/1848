# Trout mouth and back refinement

Retain `trout_surface_refined.blend` as an intermediate surface study. The mouth
no longer carries an entire second painted lip contour, and the back no longer
stretches a thin strip of side-image pixels across its crown. These artifact
repairs do not establish final concept fidelity: the crown pattern is now
simpler than the illustrated coat, and the existing jaw and eyes remain stylized.

Open `comparison.png` for first projection versus retained refinement. The raw
`refined_*.png` files cover the same side, three-quarter, opposite, dorsal and
head cameras used in the first test. The back panels in the board are rotated
90 degrees for display; both use the same crop, orientation and scale.

## What changed

- Mouth: spatial masks replace duplicate painted lip contours with subdued
  silver/sage color. Existing lip and lower-jaw meshes receive a coherent tissue
  material. The cheek's red region and surrounding reference details remain.
- Throat: a separate sampled-color layer replaces most of the stretched UV
  workaround. This also makes the lower head smoother and less detailed.
- Back: a small three-dimensional Voronoi spot pattern blends into the projected
  flanks, avoiding the projection's centerline stretching. This is a deliberate
  procedural fallback, not direct reproduction of the concept's dorsal marks.
- Fins, eyes, anatomy, object transforms, original UV coordinates and camera/light
  settings remain unchanged. Live game assets and the first candidate survive.

## Rejected approaches and observed cost

1. A literal exposed strip from the turnaround's dorsal illustration made the
   back blurred, pale and partly pink. Preserved in `rejected_dorsal/`.
2. A sharper upper-flank strip projected transversely across the crown still
   stretched the texture and introduced light streaks. Preserved in
   `rejected_upper_flank/`.
3. The retained fallback uses spatial crown spots plus the mouth/throat cleanup.

Three candidates and fifteen renders were produced in this refinement, with no
image generation or worker-agent dispatches. Actual billed token/credit cost is
unavailable. The two unsuccessful projections remain visible rather than being
counted as progress. Archived scripts document their exact implementations;
their original working directory was this refinement directory.

## Verification

`audit.json` records unchanged source/reference hashes and preservation checks.
The saved candidate was reopened. Base and evaluated geometry, transforms,
visibility, earlier UV coordinates and color attributes, and original cameras
and lights match the first candidate. All five before/after render pairs have
zero changed alpha pixels, recorded in `pixel_check.json`.

The first test's screen-size limitation remains: these are neutral Blender
renders, not gameplay/water captures. There is no new export or game integration.

## Remaining gaps

The jaw is angular and the eye protrudes. The upper snout retains some stretched
reference marks. Crown spots are too fine and uniform in treatment relative to
the richer side texture; the blend and overall pale values need art judgment.
Painted lighting remains in the projected image. The cheek is more legible, but
surface cleanup has reduced some lower-head detail. Do not treat this as an
overall likeness approval or an anatomical repair.

## Reproduce the retained candidate

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/trout_surface_test/refinement/run.py
python experiments/trout_surface_test/refinement/compare.py
```

The audit's candidate/render counts describe this completed session; a single
replay builds only the retained candidate and its five views. The script reads
the first candidate and writes only the named outputs in this directory.
