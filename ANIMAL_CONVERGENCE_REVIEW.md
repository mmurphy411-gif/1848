# Deer and rainbow trout — reference gauntlet

September 10, 2026. **Both assets have reached the subjective 8/10 silhouette and proportion gate and received initial polish.** The retained sources are deer Pass 12 and trout Pass 13. This is the same large-form gate used for the miner; it is **not an overall likeness score, photorealism claim, animation approval, or game-export acceptance**.

| Asset | Editable source | Latest comparison | Gate checkpoint |
| --- | --- | --- | --- |
| Black-tailed buck | [deer_convergence_working.blend](blender/deer_convergence_working.blend) | [Four views](artifacts/deer-convergence/comparison_pass_12.jpg) · [Silhouettes](artifacts/deer-convergence/silhouette_pass_12.jpg) | [Pass 7, before polish](artifacts/deer-convergence/pass_07.blend) |
| Rainbow trout | [trout_convergence_working.blend](blender/trout_convergence_working.blend) | [Four views](artifacts/trout-convergence/comparison_pass_13.jpg) · [Silhouettes](artifacts/trout-convergence/silhouette_pass_13.jpg) | [Pass 8, before polish](artifacts/trout-convergence/pass_08.blend) |

![Deer progression](artifacts/deer-convergence/before_current_target.jpg)

![Trout progression](artifacts/trout-convergence/before_current_target.jpg)

## Authority and method

All six supplied images were opened before modeling. Each species' `(2).png` turnaround is the primary authority for proportions and silhouettes. The `(1).png` hero and `(3).png` design sheet supply identity, palette and surface cues. Original reference images are unchanged.

The deer references consistently depict an antlered buck. The existing game source was a doe. The convergence source follows the supplied buck design; the current game population and doe export are unchanged.

The trout illustration labelled **BACK** is a dorsal illustration with an artistically presented tail, rather than an orthographic rear view. The review keeps a true rear diagnostic and adds a dorsal camera from Pass 5, rendered from Pass 6 onward. The comparison board uses this dorsal supplement. A real vertical tail fin is edge-on from directly above; the reference's broad tail presentation is not used to twist the model into an anatomically contradictory shape.

The loop was: inspect the baseline, rank the largest differences, repair the next three, save a numbered scene, render the neutral views and black silhouettes, inspect the results, and repeat. Fine fur, scale, spotting and horn texture began only after the large-form gate. Failed attempts are described below rather than silently treated as successful improvements.

Standard renders are 800 × 800 orthographic, Cycles 20 samples, AgX Medium High Contrast, fixed neutral lights and exposure, with transparent backgrounds. Deer camera scale is 2.5 m; trout camera scale is 0.46 m. Black silhouettes use an actual black material override. Comparison panels fit reference crops and rendered subjects independently, preserving aspect ratios; raw renders preserve camera scale. The deer side camera was corrected to the reference-facing side after Pass 2. The early side frames are retained as historical evidence, not claimed to share the corrected orientation.

The deer reuses and recontours the original body, head and limb surfaces, joins them into continuous anatomy, and adds buck features. The trout's 390-triangle original was insufficient for the target; its body was retopologized at the original length and orientation, with new head and fin geometry. Originals remain recoverable in the baseline checkpoints and archived source collections. These are real Blender meshes and procedural materials, not generated replacement pictures.

## Baseline discrepancy ranking

| Rank | Deer | Trout |
| --- | --- | --- |
| 1 | Doe lacks the target's branched buck rack | Lens-shaped body and pointed snout lack a trout head and peduncle |
| 2 | Narrow upright oval ears lack the alert splayed outline | Tiny triangular fins; missing adipose and pelvic pair |
| 3 | Disconnected-looking head/neck, shoulder and haunch masses | No open mouth or shaped lower jaw |
| 4 | Rigid stance, rounded feet, simplified hocks | No opercular anatomy; small bead eyes |
| 5 | Short neck and excessive barrel/chest forms | Body depth, tail root and fin areas disagree with reference |
| 6 | Flat black cone tail and floating rump/throat inserts | Broad red underside and uniform generic atlas coloration |
| 7 | Featureless face with a protruding nose and bead eyes | No credible scale relief, fin rays or distinct fin spotting |
| 8 | Smooth pale coat and regular horn surfaces | Metallic/plastic shading and simplified mouth boundaries |

## Deer passes

| Pass | Three priorities and review outcome |
| --- | --- |
| 0 | Captured original articulated doe: silhouette about 3.5/10, proportions about 4.5/10 against the supplied buck. |
| 1 | Recontoured original torso/neck; added splayed ears and antlers; lengthened limbs and changed hind stance. Buck identity appeared, but seams and rounded feet remained. |
| 2 | Joined original anatomical surfaces; established split hooves; seated ears and added a full black tail. Review exposed overly round shoulder/haunch caps and hoof gaps. |
| 3 | Lengthened neck and revised body scale; staggered hind stance and bridged pasterns; separated antler depth and enlarged eye structures. Side review exposed detached branch roots. |
| 4 | Reworked horn junctions; reshaped torso/muzzle and eye placement; applied broad anatomical coat fields. Horn connections and the neck-root ridge still needed attention. |
| 5 | Rebuilt densely sampled curved branches; smoothed neck and seated ear interiors; refined hoof slopes and dewclaw scale. Silhouette around 7.5/10, proportions around 7.5/10. |
| 6 | Fitted eight hoof halves to measured limb endpoints; tapered brisket/haunch; flattened the nose and attempted lip definition. The local taper introduced visible boundaries and the lip sweep protruded. |
| 7 | Removed those taper boundaries; seated lip treatment; softened pastern transitions. **Subjective silhouette 8/10 and proportions 8/10:** branched buck rack, alert ears, upright neck, long supporting legs, staggered hocks, cloven feet and black tail are established in all four views. Surface anatomy and facial likeness remain below that score. |
| 8 | First polish: directional short coat geometry, deeper tawny fields, horn/hoof grain. Review showed an abrupt face/neck hair-length transition and pale values. |
| 9 | Added localized facial fibers, adjusted mirrored ear grooming and introduced nose detail. Nostril inserts were too prominent in close-up. |
| 10 | Deepened coat, fiber and horn values; reduced nostril projection; retained pale ear interiors. |
| 11 | Geometry audit found and removed one eight-vertex remesh speck from each antler. Each antler is now a single connected component. |
| 12 | Close-up correction: oriented the eyes to the actual skull surface and replaced raised nostril inserts with recessed geometry. |

## Trout passes

| Pass | Three priorities and review outcome |
| --- | --- |
| 0 | Captured original 390-triangle trout: silhouette about 2.5/10, proportions about 3/10. |
| 1 | Rebuilt fusiform body/peduncle; authored all eight fins; established head, gill-cover masses and eyes. Review showed pinching and longitudinal bumps. |
| 2 | Smoothed longitudinal profile; opened and lined the mouth; softened fin margins. Sparse fin subdivision reduced their area too far. |
| 3 | Recovered full fan areas; broadened the head; established olive/silver/pink color zones. |
| 4 | Cleaned gape boundaries; tapered caudal attachment; broadened paired fins. Tail attachment still read as a cut-off stump. |
| 5 | Refined snout/jaw; widened tail base; increased pectoral area and added a dorsal camera. Tail widening introduced a shoulder notch. |
| 6 | Rebuilt caudal perimeter; ended body inside the membrane; corrected membrane normals. Tail-ring angle recovery still introduced a ridge. |
| 7 | Attempted ring correction using vertex indices. Review rejected the resulting seam: prior mouth cleanup had reindexed vertices. No polish gate was accepted here. |
| 8 | Recovered ring angles from preserved anatomical UVs and repaired the tail. **Subjective silhouette 8/10 and proportions 8/10:** rounded head, long tapered body, narrow peduncle, shallow fork, dorsal/adipose/anal fins and both paired fins read coherently. True rear and dorsal views remain distinct diagnostics. |
| 9 | First polish: body/fin spots, scale relief and fin rays. Spots were too small; scale relief looked too regular at close range. |
| 10 | Enlarged spots; strengthened olive/pink/silver hierarchy; increased ray contrast. |
| 11 | Brought gill rim toward the surface; reduced scale relief and lip contrast; attempted to seat eyes. Close-up revealed partial eye occlusion. |
| 12 | Placed eye layers using the actual head surface normal. Close-up rejected the result because the open body's normal pointed inward and hid the pupil. |
| 13 | Explicitly selected the outward normal hemisphere. The final close-up confirms visible, complete iris and pupil layers. |

## What remains below the references

These are initial polish checkpoints, not finished realistic animals. The **overall likeness is not being scored 8/10**.

For the deer, the remaining priorities are the adult skull and orbital anatomy, more natural shoulder/haunch planes, and varied fur lengths with softer facial and ear transitions. The pose, antler symmetry, regular hooves and clean coat remain more stylized than the supplied art. The fur is authored mesh geometry suitable for source inspection, not a game hair solution.

For the trout, the remaining priorities are lip/jaw and opercular construction, more natural scale overlap, and less regular spotting with finer translucent fin detail. The head and mouth are still simplified; the material is more uniform and metallic than the supplied illustration. The reference's contradictory dorsal-tail presentation remains explicitly unresolved rather than reproduced through distorted anatomy.

Inspect [deer head detail](artifacts/deer-convergence/pass_12_head_detail.png) and [trout head detail](artifacts/trout-convergence/pass_13_head_detail.png), as well as the full silhouettes. The head close-ups intentionally expose these limits.

## Verification and delivery

The final editable scenes organize anatomy, surface details, review cameras/lights and archived sources separately. Referenced images are packed. Trout fin rays are consolidated per fin in the delivered scene; numbered checkpoints retain the individually editable ray objects.

- All inspected visible mesh coordinates are finite.
- Deer skin is one connected mesh component. Each antler is one connected component. All eight hoof halves have a minimum world Z of zero in the standing review pose.
- Trout body is one connected component, with all eight fins present. The repaired tail-ring formula has zero measured coordinate error in the retained source.
- Sources were reopened and their side views rerendered. Both packaged side views match their retained checkpoint renders exactly: zero pixel difference. [Comparison measurements](artifacts/animal_packaging_comparison.json).
- Detailed measurements: [deer verification](artifacts/deer-convergence/final_verification.json), [trout verification](artifacts/trout-convergence/final_verification.json), and per-pass audits alongside each checkpoint.
- This work adds independent art sources and review tools. Existing game GLBs, gameplay scripts, reference files, miner art and original builders are unchanged. No Godot integration, animation deformation, LOD, bake or runtime performance acceptance is implied.

The deer source has **852,016 evaluated triangles / 34 visible meshes** with mesh fur, far above a game-ready budget. The trout has **36,686 evaluated triangles / 32 visible meshes** after consolidating rays per fin. Source-art convergence deliberately precedes an optimized, rigged game derivative.

## Reproduce or continue

Run from the repo using Blender 5.2.1 and Python with Pillow:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python blender/animal_convergence.py -- deer 0
# Then deer stages 1 through 12, in order. For trout, run stages 0 through 13.
python blender/animal_convergence_review.py deer 12
python blender/animal_convergence_review.py trout 13
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python blender/animal_convergence_verify.py -- deer 12
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python blender/animal_convergence_verify.py -- trout 13
```

Each stage loads the previous numbered checkpoint; rerunning a stage replaces that stage and the working scene. Use the delivered working scene for further art work and keep new numbered checkpoints. The local `artifacts/` directory is ignored by Git, following the miner convention; review images and historical scenes therefore remain local unless explicitly added to a delivery bundle. The working `.blend` files and scripts are outside that ignored directory.
