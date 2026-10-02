# Deer from scratch — gauntlet study

**Outcome: incomplete form study; 8/10 was not reached. No polish or game-ready claim.**
The run used its 12-candidate construction budget. The retained
checkpoint is `ff3c4925c882`. It has 11,806 evaluated triangles and no
structural audit errors. The working copy is byte-identical to the reviewed scene.

## Reviewable files

- [Retained Blender source](blender/deer_from_scratch_working.blend)
- [Four-view reference comparison](characters/deer/deer_from_scratch_comparison.png)
- [Three-quarter preview](characters/deer/deer_from_scratch_preview.png)
- [Complete run report](artifacts/gauntlet/deer_from_scratch/20260910-175537-7ba9a5/report.md)
- [Run manifest](characters/deer/gauntlet_from_scratch.json)
- [Construction recipe](blender/gauntlet_recipes/deer.py)

The model was built from an empty Blender scene. No geometry from the previous
deer was loaded or sampled. The earlier deer source and live wildlife exports
were not replaced. The source is static and unrigged.

## Retained checkpoint scores

These are the retained checkpoint's last ingested blind review scores, after the
gauntlet's discrepancy severity caps, across four reference views. They are not
an aggregate overall acceptance score. Reviewers were fresh sessions shown only
anonymous evidence packets and the reference, with discrepancies recorded before scores.

| Dimension | Mean / 10 | Lowest view / 10 |
| --- | --- | --- |
| silhouette | 5.50 | 5.5 |
| proportions | 5.62 | 5.5 |
| identity | 5.50 | 5.0 |
| materials | 3.50 | 3.5 |
| detail integration | 4.62 | 4.5 |

The last review recommends:

> Retain A as the more viable checkpoint: its broader ear presentation, less flattened eyes and visible nostrils preserve more anatomical information than B. B has slightly cleaner simplified facial surfaces, but its slit eyes, smooth oval nose and blade-like ear are regressions against the reference. Neither approaches 8/10: first establish anatomically shaped eye sockets and globes, ear cups and roots, a defined muzzle/nose, then repair chest, joints, pasterns, hooves and tail integration. Add directional fur and reference color variation after the underlying anatomy is credible. Do not chase inconsistent illustrated antler overlap.

## Construction history

Each plan reconstructs semantic anatomy, so the edits are reproducible without
depending on mutable vertex indices. Candidate scenes, fixed-camera renders,
audits, plans, anonymous review packets and responses are preserved in the run.
Worker jobs after the initial candidate also archive the exact Python source used.

| Pass | Candidate | Recorded decision | Triangles | Hypothesis |
| --- | --- | --- | --- | --- |
| 1 | `2ed2c3d1a490` | retained | 12,516 | Build a new black-tailed buck with a deep torso, anatomically connected neck and four planted legs. No previous deer geometry reused. |
| 2 | `44649ba145e7` | retained | 11,820 | Replace rounded head and beaded neck/body with continuous tapered anatomical sections. Preserve the four planted legs and antler structure. |
| 3 | `e2c1132ddf73` | retained | 11,722 | Correct the reference-measured height relationships: raise the belly and head, keep the antler tips at the same overall height, and seat the eyes beneath narrow lids. |
| 4 | `eaaaceb715a2` | retained | 12,092 | Follow blind proportional feedback: shorten muzzle projection by 12 percent, bring forefeet 10 percent closer, and add modest thigh volume. Cup the ears and round the hoof walls. |
| 5 | `d834275c48d4` | rejected | 11,748 | Replace floating bead eyes with seated almond-shaped corneas and surface lids, preserve extra facial topology, tuck the rear belly and blend the withers and limb roots. |
| 6 | `523d8df9b71f` | rejected | 11,536 | Repair hollow-looking eyes and detached facial accents: broaden cheeks, suppress mirror-like eye reflections, reduce the white muzzle patch and seat the closed mouth crease on the actual cheek surface. |
| 7 | `4c60ca5cd379` | rejected | 11,534 | Match the references natural weight-bearing stance: separate the forefeet in depth, bring the far hind foot forward, and define knee and hock taper instead of four nearly coincident rods. |
| 8 | `47f97b5f8c9f` | retained | 11,534 | Raise and localize hind hocks with straight distal segments; redistribute torso into a deep forechest, rising abdomen and full croup; blend the withers into the neck. |
| 9 | `6fe42205a5a2` | rejected | 11,536 | Give the cupped ears a backward-facing plane visible in profile, and restore a curved visible corneal surface within the seated eyelids. |
| 10 | `9095930fba2f` | retained | 11,536 | Integrate shoulder masses with the upper forelegs, soften the low central chest point, add fetlock taper, shorten the stretched neck, and restrict the belly marking to the underside so it does not paint bands around the knees. |
| 11 | `ff3c4925c882` | retained | 11,806 | Open the eyes vertically for an alert expression, balance ear planes between front and profile, and sculpt recessed nostrils into a tapered nose instead of adding surface beads. |
| 12 | `f37a4ad02b95` | rejected | 11,806 | Orient the curved eye surfaces outward and slightly forward, with distinct corneal curvature and a subdued orbital margin, instead of inheriting the skulls steep upward-facing surface angle. |

## Limits and verification

- Original empty-source and reference hashes, immutable manifest and saved
  reference-evidence hashes verified at closeout.
- The retained candidate has no structural audit errors. The source copy hash
  is `3b763bb752994d9ed54b0c34e37a086b844ef62bd2e59593b03d535db296568b`.
- The reference masks are uncalibrated: paper ground shadows close some leg
  gaps in the original flood-fill masks. Experimental alternatives preserve
  the gaps but still include shadow remnants. Neither has a defensible calibrated
  acceptance floor. The run therefore cannot certify measured form readiness.
- Illustrated head poses and antler projections disagree between views. The
  model keeps shared anatomy instead of distorting one view to maximize overlap.
- Smooth debug coat colors remain. Fur, texture baking, UV completion, export
  round-trip review, runtime material compatibility and rigging remain unfinished.
- No game export or gated delivery package was produced because form acceptance
  was not reached. The existing wildlife shader replaces imported coat materials
  and must be checked when this asset eventually reaches export review.
- The gauntlet's 12 planner and
  12 reviewer reservations cover
  35 review images. These are workflow counts,
  not provider token or monetary totals.

During this run, review wording was clarified to distinguish a useful retained
checkpoint from the 8/10 gate. A stale-comparison check was also corrected to
validate the best checkpoint actually shown in the packet rather than the
candidate's construction parent. Regression coverage verifies that an unseen
new best still invalidates a stale packet. All 33 gauntlet tests passed.

## Reproduction

From the repository root, initialize a separate run:

```powershell
python -m art_gauntlet init characters/deer/gauntlet_from_scratch.json
python -m art_gauntlet iterate <new-run-path> --plan art_gauntlet/plans/deer_from_scratch_11.json
python -m art_gauntlet packet <new-run-path>
```

A new blind review is required for a new run. Existing reviews cannot be reused
to promote changed evidence. Additional development should first address the
remaining anatomy and calibration issues, then repeat the gate before polish.
