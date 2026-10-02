# Trout reference-projection test

One material candidate produces a visibly closer flank, cheek, stripe and fin
treatment. It is worth retaining as a surface experiment, but it is not ready
for game integration. The head and dorsal views expose important projection
failures that the flattering three-quarter view does not resolve.

Open **comparison.png** first, then **diagnostics.png** and **screen_size.png**.
The editable source is **trout_surface_candidate.blend**, with the original
reference image packed into the file. The existing art master and live game
assets were not replaced.

## Intervention

The unmodified hero concept supplies the sampled image. New UV coordinates
register its head, flank and fin regions to the existing meshes. The opposite
side uses mirrored artwork. A small UV redirection samples clean belly scales
where the illustrated pectoral fin overlaps the body. Separate membrane mappings
sample the corresponding fins. Existing ray meshes remain, with quieter color.
Body roughness increases and metallic response decreases. Thus the test evaluates
the combined projected color/material treatment, not texture versus roughness
as independent causes.

There was no generated replacement image, texture inpainting, geometry repair,
or iterative artistic candidate search. The concept's painted highlights and
shadows remain in the sampled color; this is not recovered physical albedo.

## Observed result

- Side and both oblique views: substantial improvement in the reference-specific
  cheek coloration, dense scale pattern, pink stripe and patterned fins.
- Head close-up: the existing jaw and painted mouth do not register. Doubled
  contours, a pale lower cheek patch, stretched throat detail and the simplified
  projecting eye remain visible. The lower belly workaround also stretches.
- Dorsal: side projection stretches marks across the back and creates mirrored
  symmetry. This is a significant failure for a fish commonly seen from above.
- Small-screen proxies: color regions and spotting remain more legible, while
  individual scales disappear. At roughly 74 pixels long, the gain is much
  smaller than in the large reference comparison.
- Overall values are paler than the source illustration. Painted lighting and
  Blender lighting combine, so this material needs an albedo cleanup before a
  production physically lit workflow.

## Verification and bounds

`audit.json` records the protected scene comparison and source/reference hashes.
Base and evaluated geometry, transforms, visibility, existing UV coordinates,
original cameras and lights compare identically before/after. The saved candidate
was reopened and rechecked. Five identical camera pairs were rendered: side,
three-quarter, dorsal, opposite oblique and head. Both variants use Cycles at
32 samples, fixed seed, original AgX view settings, and 1000 x 1000 output.
`pixel_check.json` records alpha and subject RGB differences for all five pairs.

The screen-size board uses the game's 65 degree orbit FOV and 4.6 m spring-length
setting as context, with **assumed** 4.6 m and 2.3 m camera-to-fish distances at
1080p. These are resampled Blender proxies, not Godot or underwater captures.
The live fish script replaces imported materials with its shader and atlas, so
production integration needs a separate material/export change.

Observed work: one new material candidate, ten renders, no image-generation
calls or worker agents. Actual billed token/credit cost is unavailable; this
does not establish a numerical saving against the earlier passes.

## Suggested next bounded step

Keep this candidate. If continuing, repair projection coverage only: use the
turnaround's dorsal reference for the back, and separate painted mouth/eye
details from cheek color so the existing 3D features do not receive duplicate
contours. Then review the same five cameras. Do not spend another broad modeling
pass before judging that focused correction.

## Reproduce

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/trout_surface_test/run.py
python experiments/trout_surface_test/compare.py
```

Reproduction overwrites only this experiment's named outputs. Original asset
and reference paths are read-only inputs to the script.
