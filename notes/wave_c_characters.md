## Wave C — characters (crew, wildlife, fish)

Done October 2, 2026 (C-characters). Tour `c_characters` (31 views, before/after against
`merge8`) in `artifacts/visual-tour/c_characters/`, with close evidence in its `extra/`
(plain-light lineup, deer sheet, sleeves and hands, supper crop, fish crop, perf logs and
the probe scripts). No views added; `wildlife_jay` and `wildlife_squirrel` re-framed as asked.

**1. Crew period dress.** Doyle's sky-blue army trousers (the "stonewash jeans") are now
dark blue kersey with a forage cap, and no hired hand wears the miner's open knee tear any
more (four patched in paler cloth, the rest mended: the knee skin under the tear is drawn
as cloth). The crossed fold ridges on every pair of trousers ("cross-gartering") are
modelled and painted into the miner's atlas: `blender/build_crew_kit.py::flatten_trousers`
relaxes the kit's own shin and boot-top geometry (radius about each leg's axis, 20
umbrella passes on the welded surface, open edges and garment seams held; 3,372 vertices,
mean 3.2 mm; the hero is untouched), and `crew.gdshader` flattens the painted fold lines on
the legs and on pale cloth. Sleeves: the miner's sleeve puffs to 7.4 cm round the upper arm,
and `sleeves_down` billowed it further ("leg-of-mutton"). The key is replaced by
`sleeves_slim`, a plain shirt-sleeve profile (5.0–5.3 cm, never inside the forearm skin + 7
mm), used by every man not in rolled sleeves (`sleeves_rolled` slimmed the same way); sleeves
to the wrist (Soto, Ruiz, Fisk) are a 9 mm cloth layer drawn on the forearm skin in the vertex
shader in the shirt's own weave, with a darker cuff. New instance uniforms `boots` and `belt`
(belt.a carries the wrist sleeves).

**2. Near-duplicates.** Re-cast in `crew_look.gd`: Soto indigo shirt under his black vest;
Freeman brown felt hat, hickory-striped shirt on braces, navy trousers, no vest; Fisk
pinstriped shirt; Price buff shirt on black braces, black trousers, no vest; Roux madder-red
toque, green-grey shirt, grey trousers, no canteen (Pike keeps the navy cap and canteen);
Lacy butternut, Brandt grey-drill trousers; boot and belt leather varied on nine men. A
pairwise check of all 91 pairs against the rule (hat or headwear AND shirt colour or pattern
AND one of vest, trousers, beard; colours apart by > 0.12 sRGB) passes with 0 failures;
the closest pair (Boyle, Price) differs in 8 of 18 cast attributes.

**3. Supper posing.** New `scripts/crew_pose.gd`, a SkeletonModifier3D on each figure
(before the build modifier), computed from the rig's bone rests: standing men's arms hang
close with palms in and fingers loosely curled (the clip's A-pose and splayed claw go);
seated men have the hips at the seat (two-bone IK for legs and arms), forearms on the knees
or hands clasped, a tin cup in hand, per-man lean and head turn from a seeded RNG. `crew.gd`
gives the ring a `SUPPER` table; `crew_hand.gd` brings a seat (chopping round, crate or
stool, existing props) and tinware (cup, plate). Work clips are untouched. Supper now shows
a harmonica player and a man eating on the ground, two seated with a cup or forearms on
knees on a round and a crate, one leaning forward on a stool, one standing with a cup, one
stretched out. No sit clip exists; the eat and lie_down clips are the miner's.

**4. Wildlife framing.** In `tests/visual_tour.gd::wildlife()` the jay and squirrel are moved
to the nearest open ground in direct sun (sun ray clear of tree crowns and of the physics
world) and seen at 9 m with an 18° lens on a crown-free sightline (`sunlit_spot`,
`open_eye`). Deer, bear and quail views keep their framing. Bear, jay, quail unchanged.

**5. Deer.** `wildlife.gdshader` lays out a black-tailed coat from rest-pose landmarks
(per model in `wildlife_actor.gd::DEER`): grey-brown saddle over a paler flank, cream belly
and inner legs, dark lower legs, white rump patch, tail black on top, grey face with a pale
muzzle band, white chin and throat, darker crown; the doe's dark eye-patch surface is now
coat (eyes small and dark, no ring); the body normal is bent toward an elliptical cross-
section (85 %), which removes the flank blotches. Buck: back grey-brown, rack at 82 % with
dark beams and paler tips. A `HeadShape` modifier lifts the doe's ears 0.42 rad about their
root bones and narrows both skulls (Head bone width 0.90 / 0.84). No sculpting.

**6. Fish.** Darker backs (`fish.gd::LOOKS`), a pale lateral line with a soft flank sheen,
and a matte back (specular and clear coat drop on the dorsal: the sky sheen hid the fish),
no emission. Each school fish casts a soft decal shadow on the bed along the sun (radial
fall-off, occlusion 0 / roughness 1 so the wet stones' glints go too; none at night).

| Gate / finding | Target | Measured | Result |
| --- | --- | --- | --- |
| Crew period dress | no denim, plain sleeves, no garters | Doyle navy kersey; slim sleeves; legs flattened (`crew_lineup`, `extra/lineup_plain_light.png`) | fixed (for blind review) |
| Near-duplicates | rule above, every pair | 91/91 pairs pass | fixed |
| Supper posing | varied, seated, holding things | 7 men: 4 seated (3 on props), 2 with cups, 1 eating, 1 lying (`crew_supper_1936`) | fixed |
| Squirrel / jay readable | in light, 8–12 m, in frame | both sunlit at 9 m, centred | fixed |
| Deer | coat, eye, antlers, ears | as above; buck ears unchanged (rig has no ear bones) | partly |
| Fish readability | visible, no glow | dark spindle with lateral line and bed shadow (`fish_underwater_10h`, `extra/fish_before_after_crop.png`) | fixed (modest) |
| Stage 1 colour gates | 10:00/13:00 pass | pass (golden hour 0.877, S-sky's, unchanged) | pass |
| Suite | 37/37 | 37/37 (161 s); crew_models, v2_flow, wildlife, milestone_9 re-run on the final cast | pass |
| `audit_assets.py` | exit 0 | 134 files, 0 failing | pass |

**GPU-time A/B** (in-process toggles, 16 cycles, 1080p, after the hung processes were
stopped; median Δ, [IQR]): supper (`crew_performance` view) whole crew 0.30 ms [0.19..0.35]
(attribution on `merge8`: 0.44); seats + tinware +0.04 [−0.04..+0.11] (low quantile +0.003);
pose modifiers +0.006 GPU, +0.016 CPU; crew `lod_bias` 0.25 (hands only, Lambert keeps 1.0)
−0.18 [−0.38..+0.09], primitives 4.84 M → 3.33 M, no visible change at 2.5 m. Wildlife view:
deer coat branch +0.006, antler +0.000, head modifiers +0.015 (deer at 3 m: 0.000 / +0.009 /
0.000). Fish: shadows (13 decals) +0.001 low-quantile at the fish view, −0.01 across the river.
Net for my features: about −0.14 ms at supper, ±0.02 ms elsewhere.

**Back-to-back p95/median** (HEAD files vs mine swapped in this worktree, two rounds,
GPU shared with other agents): `crew_performance` supper median 5.14/4.91 → 4.88/4.79 ms,
p95 6.35/5.61 → 5.94/5.64; work 5.60/5.54 → 5.59/5.17; dam 5.78/5.54 → 5.72/5.45.
`wildlife_performance` p95 6.96/6.48 → 6.88/6.49 (median 5.82/5.52 → 6.02/5.56, noise).
`miner_performance` p95 downstream 5.59/5.42 → 5.43/5.50, wade 6.31/6.10 → 6.07/5.89,
overview 5.85/5.47 → 5.70/5.22.

**Shared files.** `tests/visual_tour.gd`: one hunk in `wildlife()` (two views re-framed) and
four helper functions after it (`crowns`, `clear_of_crowns`, `sunlit_spot`, `open_eye`). No
other shared file. **Regression amendments:** none; no assertion changed.

**Assets.** `assets/crew/crew_kit.glb` 7.74 → 7.91 MB (`sleeves_slim` replaces
`sleeves_down`; flattened legs). Nothing else added.

**Still weak.** The buck's ears still jut sideways (no ear bones on the Stag rig; a fix
needs a vertex deformation or new bones) and its head stays blocky; both deer remain low-poly
Quaternius bodies, smooth but simple, and the coat is uniform at close range. The hands at
the sides read as loose fists rather than open relaxed hands in close-ups; seated men are
posed by IK, so knees and hips are plausible but not cloth-accurate, and the seat props
cast shadow. Fish are still tube meshes; from 3 m above the water the trout reads as a dark
spindle with a pale line, not as a trout. Every man still has the miner's face.
