# Art Gauntlet — project specification

**Status:** Living project design, September 10, 2026. A first implementation is available; some capabilities below remain planned.

**Implementation update:** A first usable implementation now lives in [`art_gauntlet/`](art_gauntlet/README.md). See [the implementation report](ART_GAUNTLET_IMPLEMENTATION.md) for tested behavior, real asset trials, and the remaining scope. The concept-only bear, automatic parameter search, and full surface-transfer pipeline remain design targets. The assistant session drives the file-based loop; the Python CLI does not independently launch model sessions.

**Recommendation:** Build a small Python module that runs a hands-off, resumable loop from approved concept art to a reviewed, budgeted game asset. The owner approves the concept art and reads the final report. A model plans each edit, a separate blind model call judges the result, and a measured silhouette metric decides when that judgment is worth paying for. Start with deer and trout, then prove the abstraction on a new animal built from concept art alone.

**Revision, September 10, 2026:** revised after a review of the deer and trout runs. The game export is now the reviewed deliverable, a measured likeness metric gates model reviews, the reviewer is blind and scores discrepancy-first, the loop runs without a person in it, and token cost is a recorded budget. The miner is no longer the third asset.

## 1. Purpose and intended outcome

Given an editable asset and a reference set, the module should repeatedly:

1. Establish the target and capture the starting asset.
2. Rank the largest remaining discrepancies.
3. Apply a focused change to an isolated candidate.
4. Run geometric checks and capture the required visual evidence.
5. Review the candidate against the reference and the best retained result.
6. Retain, reject, or revise the candidate with a recorded reason.
7. Move from form work into polish only when the configured gate passes.
8. Export the game derivative, reimport it, and review both the export under the same protocol and its actual material behavior in an isolated Godot inspection scene.
9. Package the reviewed source and export together and verify that packaging preserves both.

The result is a game-ready asset inside its budget, with an inspectable source and a defensible review history. A completed script, an attractive beauty render, or a high-resolution source that cannot ship is insufficient evidence of improvement. The miner reached the game after source-art review only and was, in the owner's judgment, not half finished. That is the failure this module exists to prevent.

The module should reduce repeated setup, accidental regressions, wasted renders, wasted model calls, and reconstruction of context between sessions. It should make another animal or prop a configuration task plus, at most, a short adapter, because many more assets are planned than the three in this repo. Cost is counted in passes and model calls as well as minutes; the owner pays for every image the model looks at.

## 2. Lessons from the existing runs

The [miner review](MINER_CONVERGENCE_REVIEW.md), [animal review](ANIMAL_CONVERGENCE_REVIEW.md), and current Blender scripts provide the first requirements and migration fixtures.

| Existing behavior or incident | Requirement for the module |
| --- | --- |
| Four-view rendering, silhouettes, comparison boards and reports repeat across assets. | Share those mechanics; configure asset differences. |
| `animal_convergence.py` saves the working scene before rendering or visual review finishes. | A candidate cannot replace the retained working asset until its review succeeds. |
| Numeric stages and default final-pass numbers are hard-coded. | Select explicit run/candidate IDs and recorded parents; obtain the retained result from run state. |
| Reference images and crops are selected using filename patterns and code constants. | Record exact reference paths, hashes, crops, view meanings and authority. |
| The deer side orientation changed; the trout's labelled back illustration was actually a dorsal view. | Calibrate and version the comparison protocol before scoring. Record reference contradictions. |
| Mouth edits changed trout vertex indices; a later index-based edit damaged the tail. | Use stable semantic selectors and correspondence data, with preconditions. |
| A face normal pointed inward and hid the trout pupil. | Test the visible result and surface orientation, not merely object existence. |
| Tiny antler fragments survived until the final geometry check. | Run relevant structural checks before costly rendering. |
| Late close-ups exposed eye, nostril, gill and mouth problems. | Require detail views as soon as those regions change. |
| The deer reached 852,016 evaluated triangles; individual trout rays multiplied objects. | Track source complexity and change cost throughout the loop. |
| A silhouette/proportion score of 8/10 coexists with substantial likeness gaps. | Name the gate precisely; never report it as overall acceptance. |
| The assistant that wrote each edit also scored it. Both animals reached 8/10 on form while the spec review saw legs too long and thin, a shallow body and a small head on the deer, and a small pointed head on the trout. | Blind reviewer, discrepancy-first scoring, and a measured metric that does not negotiate. |
| The miner was exported to the game after source-art review only. | The reviewed object is the exported game asset, not the source. |
| The deer's coat is 852,016 triangles of authored mesh fur that can never ship. | Detail belongs in baked textures. The game budget is a gate from pass 0, not a footnote. |
| Each pass was 30 to 100 lines of hand-placed coordinates written blind, then rendered to see what happened. | Parametric recipes so most passes are a short parameter file; bespoke edits are recorded and counted. |

These are observations from the local workflow, not measured claims about expected speedups.

## 3. Scope

### First version

- Local CLI and Python library; Windows-first because that is this repo's current environment.
- Blender process execution, manifests, isolated candidates and resumable state.
- Asset adapters for the deer and trout.
- Standard views, configurable detail views, geometric diagnostics and comparison boards.
- Structured visual reviews supplied by the working assistant, an independent reviewer, or a person.
- Explicit form/polish gates, rejection, rollback, packaging and generated Markdown reports.
- Timing, cache statistics, geometry counts and storage measurements.
- A measured silhouette metric per view, calibrated on the existing deer and trout passes before any new edit.
- Game export gate: glTF export, reimport, budget checks and render comparison, following the existing export scripts.
- A hands-off `run --until game-ready` mode in which the working assistant plans and a blind subagent reviews.
- Token accounting: model calls, images shown and their pixel sizes, recorded per candidate and per run.
- Initialization from concept art alone, with a parametric block-out as pass 0, for assets that have no existing source.

### Excluded from the first version

- A general-purpose automatic sculptor or a promise that every asset will converge.
- A Blender UI add-on, web application, database, distributed render service or plugin marketplace integration.
- Embedded model credentials or a required paid vision service. The planner and reviewer are the assistant session already working in the repo.
- Runtime replacement of live game assets, rigging, LOD chains and animation approval. Static game-ready export is in scope; these follow as separate gates with their own acceptance criteria. Rig, action and weight preservation still applies when the source is rigged.
- Automatic deletion of checkpoints or alteration of original reference artwork.

The design should accommodate characters, wildlife and props. It should not require a universal anatomy model to do so.

## 4. Proposed module boundary

Use a root-level package, keeping it separate from the ignored `.tools/` directory:

```text
art_gauntlet/
  __init__.py
  __main__.py             # CLI
  manifest.py             # Configuration and record validation
  runner.py               # State transitions, processes, locks, cache
  blender_worker.py       # Scene loading, adapter execution, rendering, audits
  metric.py               # Reference masks, alignment, silhouette IoU, outline distance
  review.py               # Evidence requirements, blind review requests, gate evaluation
  export.py               # glTF export, reimport, budget audit, render comparison
  report.py               # Boards, progress summaries, Markdown, cost accounting
  tests/                  # Small fixtures and failure-recovery tests

characters/
  deer/gauntlet.json
  rainbow trout/gauntlet.json
  bear/gauntlet.json      # Third asset: built from concept art alone, no existing source reused

blender/gauntlet_recipes/   # Parametric edits shared by every adapter
  forms.py                # Tubes, lofted ellipsoids, tapered limbs, fins, plates
  deform.py               # Landmark-driven proportional and lattice deforms
  surface.py              # Projection, seating, mirroring, attachment
  bake.py                 # Texture baking from source detail to the game mesh

blender/gauntlet_adapters/
  deer.py
  trout.py
  bear.py

artifacts/gauntlet/<asset-id>/<run-id>/
  run.json
  events.jsonl
  candidates/<candidate-id>/
    candidate.json
    edit.py               # Exact edit implementation, or immutable copy/reference
    candidate.blend
    audit.json
    metric.json
    review.json
    cost.json             # Model calls, images and pixels shown, seconds per step
    renders/
    export/               # GLB, reimport renders, budget audit
    logs/
  report.md
```

Start with the standard library and Pillow outside Blender. Use Blender's bundled Python for scene operations. Add another dependency only for a demonstrated requirement. Executable and font paths must be configurable rather than tied to one person's installation.

The runner owns workflow and files. The Blender worker owns scene operations. An adapter owns the meaning of the asset. A reviewer owns the artistic assessment.

### Adapter responsibilities

Each adapter provides a small, explicit contract:

- **Inspect:** identify the subject, collections, required features, units, axes, rig and variants.
- **Apply:** execute a named recipe with parameters, or a bespoke edit file, against a declared parent candidate. Bespoke edits are recorded as such and counted; the target is that most passes are parameters.
- **Audit:** run asset-specific constraints and return structured results.
- **Package:** construct the editable delivery without changing its reviewed appearance.

Adapters must not overwrite source files, run their own workflow, or declare their own edits artistically successful. The runner invokes them with an input scene, output directory, plan and recorded seed.

A new modeling technique need not be generalized immediately. A one-off edit can be retained as a candidate's Python file, provided it obeys the same input/output and audit contract. When the same bespoke shape appears in a second asset, it moves into `gauntlet_recipes` before a third asset uses it.

The recipe library is the main efficiency lever for many assets. The existing step files hand-place coordinates and rerender to see the result; a recipe takes landmarks and ranges from the manifest, so the planner writes a short parameter file and the metric can tune the parameters without a model call.

**Construction rule for game assets:** the reviewed mesh is the game mesh. Form work happens on a mesh inside the triangle budget. Fine detail (fur, scales, grain, spotting) is authored as source detail or procedural material and baked to the atlas, never as shipped geometry. A high-resolution sculpt is allowed as a baking source; it is not the deliverable and it is not what the reviewer scores at the game-ready gate.

## 5. Asset manifest

Use JSON for the first version to keep configuration easy to inspect and dependencies small. Paths are repository-relative; the loader resolves and validates them. The stable ID is independent of the folder name, so `rainbow_trout` can live in `characters/rainbow trout/`.

Required fields:

| Field | Contents |
| --- | --- |
| Identity | Schema version, stable asset ID, display name, adapter |
| Source | Exact `.blend` path, subject selector, intended working-output path |
| Target | Short design brief, primary and secondary references, explicit exclusions |
| Reference views | Exact file and crop per view, orientation/projection, confidence and contradictions |
| Scene | Units, forward/up axes, standard pose, variant/loadout definitions |
| Render protocol | Versioned cameras, projection, scale, lighting, background, color management, seed and quality profiles |
| Semantic regions | Stable selectors for eyes, antlers, fins, hooves, equipment or other critical parts |
| Checks | Common checks plus configured asset-specific constraints and severities |
| Gates | Required dimensions, per-view floors, critical issues that block advancement |
| Budget | Maximum attempts, elapsed time, model calls and images shown, source complexity limits |
| Game budget | Triangle ceiling for the export, atlas size, material and object counts, import scale, export profile |
| Metric | Reference mask per view, alignment rule, per-view floors, regression tolerance, calibration anchors |
| Delivery | Package profile, export profile, and which evidence must accompany the source and the GLB |

Example gate configuration, illustrating proposed fields rather than an implemented schema:

```json
{
  "schema_version": 1,
  "asset_id": "deer",
  "adapter": "blender.gauntlet_adapters.deer",
  "source": "blender/build_deer.blend",
  "working_output": "blender/deer_convergence_working.blend",
  "gates": {
    "form": {
      "required_dimensions": {"silhouette": 8, "proportions": 8},
      "required_view_floor": 7,
      "unresolved_critical_issues": 0,
      "require_all_variants": true
    },
    "polish": {
      "required_dimensions": {"identity": 8, "materials": 8, "detail_integration": 8},
      "require_form_gate_still_passes": true,
      "unresolved_critical_issues": 0
    },
    "game_ready": {
      "reviewed_object": "export",
      "require_polish_gate_still_passes": true,
      "budget_violations": 0,
      "export_render_tolerance": 0.02
    }
  },
  "metric": {
    "views": ["front", "side", "back", "three_quarter"],
    "alignment": "uniform_height",
    "retention_tolerance": 0.01,
    "form_floor_per_view": null,
    "calibration_anchors": ["pass_00", "pass_12"]
  },
  "game_budget": {
    "max_triangles": 12000,
    "max_materials": 2,
    "atlas_size": 2048,
    "max_objects": 4,
    "export_profile": "glb_static"
  },
  "budget": {
    "maximum_candidates": 12,
    "maximum_elapsed_minutes": 90,
    "maximum_model_calls": 30,
    "maximum_review_images": 40,
    "stop_after_non_improving_reviews": 3
  }
}
```

The numbers above are proposed starting defaults. The metric floors are `null` on purpose: calibration fills them in. The triangle ceilings are placeholders until the game's actual per-asset budgets are written down; the deer at 852,016 evaluated triangles fails any of them. Existing assets do **not** automatically satisfy the proposed polish or game-ready gates. Budget exhaustion, in minutes or in model calls, reports an incomplete run with the exact state reached; it does not relax the rubric, skip the metric, or manufacture a passing score.

## 6. Establish the comparison before editing

An initial calibration step is mandatory and reusable across passes:

1. Load the actual asset, resolve units/axes and verify the subject selector.
2. Map reference crops to meaningful views. Record illustrations that are perspective, inconsistent or ambiguous.
3. Set the cameras and framing with room for planned silhouette additions such as antlers or equipment.
4. Identify a few useful landmarks and their approximate target ranges.
5. Build the reference silhouette mask for each view from the crop, save it as an inspectable image, and record it in the protocol version.
6. Render the baseline in each required configuration and compute the metric for pass 0 and for the current retained pass if one exists. Record both as calibration anchors.
7. Review the setup, the masks and the anchor scores before using them to score modeling changes.

Maintain two distinct presentations: a fixed-scale diagnostic board and a fitted editorial board. The latter is convenient for reading, but must not hide scale errors or supply measurement results. Never stretch one axis or independently warp a candidate to improve its apparent match.

Camera, pose, crop or reference changes create a new protocol version. Comparisons and cache entries from incompatible versions cannot be used as evidence of improvement. Recapture the relevant retained baseline under the new protocol rather than comparing unlike frames.

For inconsistent generated illustrations, record which traits take precedence. Impossible multi-view agreement is a reference problem, not a reason to distort the asset.

## 7. Candidate lifecycle and recovery

Use an immutable run ID and candidate ID. A candidate records its parent explicitly; it does not assume that the previous numeric pass is the best starting point.

```text
planned → building → audited → rendered → awaiting_review
                                            ↓
                                  retained / rejected / revise

Any execution step can fail without changing the retained candidate.
```

The run separately records `latest_attempt`, `best_candidate`, `phase` and `status`. A failed or rejected attempt remains visible in history but cannot silently become the working asset.

Metric-selected search candidates are separate from reviewed checkpoints. A numerical improvement may justify further search, but only visual review can update `best_candidate`. The first implementation always starts new edits from that reviewed best, or the immutable original baseline when none has been accepted.

### One iteration

- Read the best candidate's review and the open discrepancy list.
- Select one primary repair; allow up to two closely related repairs. Three unrelated edits make attribution and rollback harder.
- Record the hypothesis, affected regions, intended visible improvement and required checks **before** running the edit.
- Build in a candidate-specific directory from the declared parent.
- Audit before rendering. A hard failure stops the candidate immediately.
- Capture affected-region evidence, then the full required view/variant set before retention or a gate decision.
- Obtain a structured review. Compare candidate and best against the same target.
- Retain only when the named goal improves and required dimensions do not materially regress. If the reviewer describes a tradeoff, record it explicitly.
- Update the best pointer and working source atomically after successful review. If the working source changed outside the runner, report a conflict instead of overwriting it.

Use a per-run lock and an append-only event log. Write result files to temporary siblings and rename only after they are complete. Resume from the first incomplete step whose inputs still match their recorded hashes. Interrupted builds must not be mistaken for valid checkpoints merely because a `.blend` exists.

Launch Blender through an argument list, with a nonzero Python-exception exit code, timeout and captured log. Validate expected output files as well as the process exit code. Record the actual device; a GPU setup failure must not silently change a benchmark into a CPU run.

## 8. Review and scoring

### Measured likeness

The turnaround crops are close to orthographic, so a silhouette comparison is cheap and honest. For each required view:

1. Threshold the reference crop into a mask. Save the mask next to the crop so a person can see what is being measured. Record it in the protocol version.
2. Render the candidate as a geometry-only silhouette under the fixed camera.
3. Align by bounding-box center and one uniform scale on height. Never scale axes independently and never warp either image.
4. Compute intersection over union, an outline distance such as mean symmetric Chamfer distance, and the same IoU inside a few declared landmark bands (head, torso, legs or fins, tail) so the report says where the silhouette is wrong, not just how wrong.

Illustrated references are not perfectly orthographic and disagree between views, so the ceiling is below 1.0. Calibration measures pass 0 and the current retained pass and records both. The per-view form floor is set from those anchors and from what the blind reviewer says about the anchors, then frozen for the protocol version.

The metric is used three ways:

- **Regression guard.** A candidate whose IoU drops by more than the retention tolerance in a calibrated, high-confidence view may be rejected before a model call. Uncertain alignment or conflicting illustrated projections route the tradeoff to review instead of automatically vetoing anatomical improvements.
- **Review trigger.** A model review is requested only when the metric improves, when the edit touched a region the metric cannot see (color, eyes, mouth interior), or at a gate. Non-improving metric results are logged and the planner tries a different repair.
- **Form floor.** The form gate requires every view at or above its floor in addition to the reviewer's scores. The metric cannot pass the gate by itself; it can only block it.

The metric says nothing about identity, materials or detail. Those still need eyes.

### Keep machine checks and artistic judgment separate

Machine checks produce measured values and pass/fail/warning results. Visual reviews produce subjective scores, observations and confidence. A topology pass does not imply good anatomy; a clean render does not imply likeness.

Score these dimensions separately:

| Dimension | Question |
| --- | --- |
| Silhouette | Do the outline, pose and defining features match the intended design across views? |
| Proportions | Are the major lengths, masses and relationships consistent with the reference ranges? |
| Identity | Does the subject read as this character/species/design, rather than a generic instance? |
| Materials | Are color, roughness, translucency and surface response appropriate to the target? |
| Detail integration | Are eyes, mouths, fur, seams and attachments built into the form convincingly? |
| Production readiness | Does the separate export satisfy its rig, performance and integration requirements? |

Use anchored examples: **4** means recognizable but dominated by large discrepancies; **6** means coherent yet obviously mismatched in important regions; **8** means strong agreement for that named dimension across required views, with localized remaining differences; **10** means no meaningful discrepancy found at the agreed review scale. Avoid decimal precision finer than half a point.

**Scores are derived, not chosen.** The reviewer first lists every discrepancy it can see, each with a region, a view and a severity of major, moderate or minor. The runner then caps the score: any major discrepancy caps that dimension at 6, any moderate discrepancy caps it at 7.5, and 8 or above is possible only when every listed discrepancy is minor. A reviewer that wants to award 8 has to be able to say that nothing large is wrong, in writing, against the reference. This is the mechanism for a harsher reviewer; exhortation is not.

**The reviewer is blind.** It receives the reference crops, the candidate board, the best retained board labelled only as A and B in random order, and the rubric. It does not receive the plan, the hypothesis, the edit file, the pass number or any description of what changed. It compares to the reference, never to the previous pass. In the first version the reviewer is a subagent spawned with that packet and nothing else; the planner never scores its own work.

**Recalibration comes first.** Before trusting the gates, inspect the masks and cameras and blindly score the existing anchors. Validate whether reviewers detect concrete proportion and feature defects, using improved, degraded and withheld examples. Do not tighten the rubric merely until it returns a demanded score. A disagreement should expose evidence or calibration problems, not trigger score manipulation.

Every review must contain:

- Candidate, reference-set, protocol and evidence hashes.
- Reviewer identity/type and rubric version.
- Evidence inspected, scores by dimension and view, and confidence.
- Ranked remaining discrepancies with image/region references.
- Critical defects and regressions, including unchanged parts that deteriorated.
- Retain/reject/revise decision and the next repair recommendation.

Missing evidence means **not reviewed**, not passed. Invalid JSON, stale hashes or omitted critical views leave the candidate awaiting review.

### Gate policy

Preserve the existing 8/10 silhouette-and-proportions gate as **form-ready**. Require all configured variants, an explicit per-view floor and no unresolved critical defects. An average must not conceal a missing eye or a detached antler.

At a gate, require a second blind review of the same candidate from a fresh subagent with a fresh random A/B order. Two reviews at a gate is the one place the loop deliberately spends extra model calls. Both are recorded.

If judgments disagree enough to change the gate decision, request a specific additional view or mark the disputed dimension unresolved. Do not average conflicting judgments into a pass.

Polish-ready, polish-complete and game-ready are distinct states. A later change can invalidate a previous form gate. Reports must lead with the exact state reached and list unmet dimensions. Never reduce the whole result to an unlabeled “8/10.”

**Game-ready** is the only state that counts as done. It requires: the polish gate still passes; the export is inside every game-budget field; the exported GLB reimports into a fresh Blender scene and renders within the declared tolerance of the source renders under the same protocol; and the blind reviewer scored the reimported export, not the source. Nothing reaches `assets/` without this state.

Game-ready also requires visual inspection in Godot with the applicable runtime material bindings at close-up and declared gameplay distance. A Blender round trip cannot certify those bindings. Static inspection does not certify animation, underwater composition or full gameplay integration, and this module does not install its outputs into live assets.

## 9. Execution with a modeling assistant

The owner's involvement is two moments: approving the concept art, and reading the final report. Everything between them runs without a person. The module should support that complete loop without pretending a deterministic Python script can make every artistic decision.

The planner is the working assistant session in the repo. The reviewer is a blind subagent spawned by that session with only the review packet. No API keys, no separate service. The runner still speaks files, so the same state machine can be driven by a person or by a future service adapter:

- The runner emits a compact request containing the target, best candidate, discrepancy ranking, artifact paths and constraints.
- The assistant or artist supplies a plan plus an edit implementation/recipe.
- The runner executes, audits and renders it, then emits an evidence request.
- The reviewer supplies `review.json`; the runner validates it, applies the gate policy and continues or reports the next required action.

This makes the loop usable immediately by the assistant already working in the repo. A future model-service adapter can automate those exchanges without changing the state machine. Provider-specific APIs, credentials and model choices stay outside the core module.

### Token economy

Every image the model reads and every line the runner prints costs the owner money. Rules:

- One composite board per review, about 1600 pixels wide, plus critical-feature crops at gates and budgeted additional evidence when needed. Details must not be restricted solely to regions the planner declared changed: collateral regressions matter.
- The metric prioritizes review calls (section 8). Search attempts may be rejected or marked promising numerically, but only visually reviewed candidates become retained checkpoints.
- The planner reads `status` output, the ranked discrepancy list and the metric bands. It does not reread step files, audits or event logs unless a failure points at them. Runner output is compact and stable.
- Prefer a recipe parameter file over a bespoke edit. A bespoke edit costs the tokens to write it and the tokens to debug it.
- Record per candidate: planner calls, reviewer calls, images shown and their pixel counts, and seconds per step. Report totals per run and per gate reached. Token counts are not observable from inside the session; call and pixel counts are the proxy.
- Stop on the model-call budget exactly as on the elapsed-time budget: report the state reached and the ranked remaining discrepancies.

Suggested CLI, all proposed:

```text
python -m art_gauntlet doctor
python -m art_gauntlet init characters/deer/gauntlet.json
python -m art_gauntlet iterate <run-id> --plan plan.json
python -m art_gauntlet review <candidate-id> --from review.json
python -m art_gauntlet status <run-id>
python -m art_gauntlet resume <run-id>
python -m art_gauntlet export <run-id> --candidate best
python -m art_gauntlet package <run-id> --candidate best
python -m art_gauntlet report <run-id>
python -m art_gauntlet run characters/deer/gauntlet.json --until game-ready
```

`iterate` performs the executable part of one cycle and returns a structured state when artistic input is missing. `run --until game-ready` initializes a run and returns the first request to the assistant driver, which repeats those exchanges up to the budget and spawns blind reviewers. Python persists the state and executes deterministic steps; it does not independently launch the assistant. Session interruption leaves the run resumable from its directory. Reviewers see actual rendered artifacts, not the builder's description of its changes.

## 10. Checks that would have caught our regressions earlier

Common checks should include finite **evaluated world-space** geometry, subject presence, required materials/assets, unexpected visibility changes, clipping, and configured bounds. Capture both base and evaluated triangle counts, visible objects, textures and file sizes.

Asset-specific checks should be scoped rather than imposed universally:

- Connected components for parts intended to be continuous; allow intentional separate eyes, teeth and accessories.
- Required feature inventory, plus pixel visibility in views where a feature should be visible. Object existence alone is insufficient.
- Foot contact and floating attachments with declared tolerances appropriate to asset scale.
- Surface-normal orientation for projected details and penetration/attachment checks.
- Rig, action, weight and named-pivot preservation when editing a rigged source.
- Key proportion ratios, with tolerance ranges reflecting uncertainty in illustrated references.
- Game budget on the export: triangle count after modifiers, material and object counts, atlas size, UV presence and overlap, image packing, import scale.
- Export fidelity: the reimported GLB renders within tolerance of the source under the same protocol, per view.

Use stable semantic object properties and selectors, such as `gauntlet_id`, rather than display-name suffixes. Edits declare expected selector cardinality, topology assumptions and affected regions. Topology-changing edits invalidate vertex-index correspondence; subsequent edits must use updated UVs, landmarks or spatial projection.

Tests must use independent evidence. Checking a generated coordinate against the same formula that generated it will not catch a wrong formula or bad correspondence. Tail continuity needs geometric continuity checks and rendered inspection, not only a zero-error report from shared arithmetic.

## 11. Performance and quality improvements

These are recommendations to benchmark, not promised speedups.

| Priority | Improvement | Expected benefit and constraint |
| --- | --- | --- |
| 1 | Audit first; render the edited region before a complete set. | Reject obvious failures cheaply. Full evidence remains mandatory before retention and gate decisions. |
| 1 | Review close-ups early for face, eyes, mouths and attachments. | Prevent several passes of work on visibly broken details. Usually more valuable than saving a few render seconds. |
| 1 | Start every candidate from the best retained result. | Avoid chains of compensating fixes built on a regression. |
| 1 | Prefer one main hypothesis per pass. | Easier diagnosis, smaller rollbacks and more trustworthy improvement records. |
| 1 | Cache by scene, dependencies, protocol, renderer/device and quality-profile hashes. | Reuse unchanged evidence safely. A changed caption should not trigger rendering. |
| 1 | Reuse silhouette coverage for proven geometry-invariant edits. | Avoid another four diagnostic renders after a color-only change. Alpha, displacement, visibility and silhouette-affecting shading invalidate that shortcut. |
| 1 | One GPU render worker by default; overlap lightweight CPU work. | Avoid GPU-memory contention. Tune concurrency from measured throughput rather than assuming two simultaneous renders are faster. |
| 2 | Draft and gate profiles. | Draft at lower resolution/sample count; gate at the established review profile, with high-resolution detail views. Never score a gate from draft evidence alone. |
| 2 | Geometry-only masks for silhouette diagnostics. | Potentially cheaper than fully shaded rendering. Validate against the canonical silhouette; do not assume a beauty render's alpha is equivalent for transparent materials or shadow/holdout setups. |
| 2 | Region-aware edit and artifact dependencies. | Reuse untouched close-ups or variants when equivalence is provable. Begin with conservative invalidation, not fragile heuristics. |
| 2 | Stream audits and use bulk mesh access. | Avoid repeatedly allocating world-coordinate lists and walking the same high-density geometry. Profile before specializing code. |
| 2 | Complexity budgets tied to phase and visible benefit. | Flag expensive fur, remeshes and object proliferation early. Favor shader detail when it gives the needed appearance without changing silhouette. |
| 1 | Metric-gated model review. | Spend a model call only when the silhouette metric improved, the change is invisible to the metric, or a gate is reached. This is the largest token saving available. |
| 1 | Parameterized recipes for recurrent operations. | The planner writes parameters, not coordinates; the metric can tune parameters without a model call. Keep species-specific anatomy in adapters. |
| 3 | Small candidate branches for difficult repairs. | Compare two materially different approaches from the same parent. Keep GPU work queued and count both against the budget. |
| 3 | Persistent Blender workers. | Consider only if startup/load cost is significant. Fresh processes remain the default because hidden scene state makes debugging harder. |

Record elapsed time for loading, editing, auditing, rendering each view, board assembly, review and packaging. Also record failed attempts, accepted improvements, peak memory when available, and storage growth.

The main performance measures are **model calls and passes to the game-ready gate per asset**, then wall-clock time to that gate. Faster renders accompanied by more regressions are not a success, and neither is a cheap run that stalls at form-ready.

The baseline is the existing history: deer took 12 passes and trout 13 to a self-graded form gate, with an unrecorded number of model calls and no game export at all. The first honest target is a **bear built from concept art alone, reaching game-ready inside the manifest's call budget**, with every call and image counted. Mechanical render savings are measured as a secondary table. Do not trade away review quality or skip the metric to hit any number.

## 12. Storage, provenance and packaging

- Preserve the original source and references; record their hashes at run creation and verify them at completion.
- Keep complete checkpoints for baseline, gate candidates and best retained results. Rejected attempts remain available by default.
- Store manifests, adapters and compact accepted review records in version control. Keep bulk run artifacts under the existing ignored `artifacts/` convention.
- Provide an explicit delivery-bundle command so another machine can obtain the working source, manifests, accepted evidence and report. A tracked Markdown file with only ignored local image links is not a portable delivery.
- Offer a storage estimate and an explicit pruning command later. Do not introduce automatic destructive cleanup in the first version.
- Avoid embedding every historical rejected scene inside the final `.blend`; retain relevant editable parts and store history in checkpoints.
- Package from the best reviewed candidate, reopen the delivery, and compare the required renders. Compare exactly on the same environment when deterministic; otherwise use declared tolerances and disclose the environment difference. No automatic threshold relaxation.
- The GLB is packaged with the source. It records the candidate it was exported from, the protocol version, the budget audit and the reimport comparison. Rigging, animation and runtime performance remain later gates with their own criteria.

## 13. Acceptance tests

The module is ready for use when these observable scenarios pass:

1. Deer and trout initialize from manifests without species branches in the runner, render worker or report generator.
2. A failed edit, Blender exception, failed audit or rejected review leaves the best pointer and working file unchanged.
3. An interrupted render resumes correctly; completed matching views are reused and stale views are not.
4. Repeating a cached capture performs no unnecessary Blender render work. A changed external texture or protocol correctly invalidates affected evidence.
5. A material-only edit reuses silhouettes only when its declared invariants and dependency checks justify it.
6. Missing or stale reviews cannot promote a candidate. A form gate cannot pass with missing required views, an under-floor view, or an unresolved critical defect.
7. A deliberately hidden eye fails its visibility evidence check; a detached test part fails the appropriate connectivity check. Intentional separate parts remain allowed.
8. A topology-changing edit cannot run a subsequent index-dependent recipe without renewed correspondence validation.
9. A run can reject an inferior candidate and continue from the earlier best candidate without overwriting history.
10. Packaging reopens successfully and preserves reviewed appearances. Reports link to valid artifacts and name the actual retained stage and unmet gates.
11. Original source, references and live game exports remain unchanged during an art-only run.
12. A bear manifest initializes from concept art with no existing source, produces a pass 0 block-out inside the triangle budget, and runs the same loop with no bear-specific conditions in the core workflow.
13. Calibration reproduces the pass 0 and current-pass metric scores for deer and trout, and the saved masks are inspectable images.
14. A deliberate proportion regression (legs lengthened 15%) is rejected on the metric without a model call.
15. The blind reviewer's packet contains no plan text, pass number or change description; a test greps for them.
16. A reviewer that lists a major discrepancy cannot produce a dimension score above 6; the runner caps it.
17. An export over the triangle ceiling or with a missing atlas cannot reach game-ready; a within-budget export that reimports and renders within tolerance can.
18. A run records planner calls, reviewer calls and images shown per candidate, and the report totals them per gate reached.

Use small synthetic Blender fixtures for failure cases, plus the real assets for migration acceptance. Test workflow correctness heavily; avoid tests that merely assert implementation formulas or call arbitrary artistic scores correct.

## 14. Implementation sequence

| Milestone | Deliverable | Exit condition |
| --- | --- | --- |
| 1 — Capture and calibrate | Manifest validation, doctor, baseline capture, fixed protocol, reference masks, silhouette metric, blind rescoring of existing anchors | Both animals reproduce review sets from configuration; anchors and blind scores are recorded; concrete defects and withheld regressions are detected without requiring a predetermined score. |
| 2 — Safe iteration and export | Isolated candidates, edit plans, audits, event log, resume, best pointer, GLB export, reimport, budget audit | Failure/rejection never replaces the retained asset; an export can be produced and compared for any retained candidate. |
| 3 — Hands-off loop | Blind reviewer subagent, discrepancy-first scoring, metric-gated review, gates, `run --until`, cost accounting, report | One asset goes from its current state to game-ready with no person in the loop, and the report shows every call and image spent. |
| 4 — Recipes and a new asset | Recipe library extracted from deer/trout step files, concept-art block-out, bear manifest | The bear reaches game-ready from concept art alone inside its call budget. |
| 5 — Efficiency and delivery | Timings, conservative cache, draft/detail scheduling, delivery bundle, documentation, legacy wrappers | Benchmark tables show where calls and time go; the bundle reviews on another machine. |

Do not rewrite the successful modeling history first. Wrap the existing deer/trout edits, separate side effects, and migrate shared mechanics in small steps. Preserve legacy commands until replacement renders and source audits have been compared. The deer's mesh fur is the one thing not to migrate: the deer's path to game-ready starts by retiring it in favor of a baked coat, and that is the first real test of the recipe library.

## 15. Recommended first decisions

Proceed with JSON manifests, a root-level Python package, fresh Blender processes, one GPU worker, the assistant as planner, a blind subagent as reviewer, and the silhouette metric as the gatekeeper for when the reviewer is called. Keep 8/10 as the form threshold but derive it from listed discrepancies, and recalibrate on the existing passes before trusting it. Add game-ready as the only terminal state and the export as the reviewed object. Replace the miner with a bear as the third asset.

The strongest improvement is a stricter, cheaper loop, not a larger framework: define the target once, measure what can be measured, fix one thing per attempt with parameters rather than coordinates, show the reviewer nothing but the pictures, spend a model call only when the numbers say it might matter, and never call anything done that has not been exported and looked at.
