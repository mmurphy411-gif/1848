# Art Gauntlet

A local Blender runner for repeated reference comparisons, isolated edits,
blind reviews and export checks. Python handles execution and persistent state.
The assistant session handles planning and dispatches fresh visual reviewers.
The CLI does not call a model API or launch another assistant by itself.

## Minimum preservation gate

The separately runnable minimum gate is validated on an acquired CC0 rigged
horse. It implements isolated unlit region IDs, silhouette mattes, protected
data comparison, and a persisted two-failure stop. It does not run art scoring
or deformation tests. See [results and provenance](../MINIMUM_GATE_VALIDATION.md).

```powershell
python -m art_gauntlet.minimum_gate validate art_gauntlet/plans/minimum_horse_gate.json artifacts/gate_minimum/new_validation
python -m art_gauntlet.minimum_gate edit artifacts/gate_minimum/new_validation
```

Use a fresh output path. `edit` requires passing validation and permits one
narrow proof edit. The older full-art workflow below remains separate.

For an existing minimum-gate evidence packet, use the deterministic audit command
instead of dispatching a model to perform mechanical checks:

```powershell
python -m art_gauntlet.minimum_audit artifacts/routing_trial_01/audit_packet/packet.json artifacts/gate_minimum/new_audit
```

The packet supplies `config`, `baseline`, `mesh`, `allowed_vertices`, and named
`samples` with `folder` and `declared_delta` fields; paths resolve relative to the
packet. Allowed vertices and mesh must match the fixed config. Each evidence
folder must contain its saved scene, snapshot and all configured ID/matte images.
The command reruns the existing preservation comparison and opens the saved
baseline once plus each sample in one Blender process to verify declared vertex
deltas at the routing trial's fixed 1e-6 tolerance. It never saves scenes, renders,
edits loop state, or assigns art scores. Input hashes and results are recorded in
the fresh output directory's `audit.json`.

Exit codes: **0** means all samples accepted; **1** means a completed audit rejected
at least one sample; **2** means an incomplete/error audit. The supplied trial
packet intentionally exits 1 because it includes a protected-region violation.
An existing output directory is refused. `completed` is separate from `passed`;
completion alone must never promote a candidate. This audits captured evidence
and actual vertex deltas, not artistic judgment or independently recaptured
material/rig data. See [the bounded comparison](../MINIMUM_AUDIT_ECONOMICS.md).

## Quick start

Requires Python 3.11+, Pillow, Blender and Godot. No model credentials are needed.
Executable discovery uses PATH, then this repo's existing Windows installations.
Override with `GAUNTLET_BLENDER` and `GAUNTLET_GODOT` when necessary.

```powershell
python -m art_gauntlet doctor
python -m art_gauntlet run "characters/rainbow trout/gauntlet.json"
# Use the returned absolute run directory as <run> below.
python -m art_gauntlet iterate <run> --plan art_gauntlet/plans/baseline.json
python -m art_gauntlet packet <run>
python -m art_gauntlet review <run> --from <response.json>
python -m art_gauntlet status <run>
python -m art_gauntlet export <run>
python -m art_gauntlet engine <run>
python -m art_gauntlet packet <run> --kind export
python -m art_gauntlet report <run>
```

`run` initializes a persistent run and emits the first request for its assistant
driver. It returns rather than holding a process open waiting for model input.
Continue that same directory in another session; `resume` retries a failed build
without creating or charging another candidate. `status` is read-only.

Do not launch two commands against the same run simultaneously. An OS file lock
protects mutations and releases automatically if the process crashes. Blender
logs stay in the candidate directory; ordinary command output is compact JSON.

## Assistant driver contract

1. Inspect the reference crops, masks, cameras and baseline. Correct the manifest
   and initialize a new run if the comparison is wrong. Never score unlike views.
2. Write a plan containing a hypothesis and `operations`. Execute `iterate`.
3. On failure, inspect the named log. Retry transient failures with `resume`;
   submit a new plan for an actual modeling correction.
4. On `search_only`, no improvement has been accepted. A new plan starts from the
   best reviewed candidate. `packet` may still be requested for an ambiguous
   tradeoff. High-confidence calibrated metric regressions are rejected.
5. Request `packet`, then give a **fresh reviewer with no inherited history** only
   its `packet.json` and listed images. The private mapping is outside the packet
   directory. Do not send plans, pass numbers, builder commentary or run records.
6. The reviewer views every listed image and returns the supplied JSON schema.
   Submit that response with `review`. Scores are capped by discrepancy severity.
7. Fix the ranked discrepancies. Two distinct fresh reviewer identities are
   required at a gate; contradictory results remain unresolved. A new candidate
   must establish its own gates. No score is inherited from its parent.
8. After form and polish, export, inspect in Godot, and review the export packet.
   Two successful export reviews plus technical checks are required for delivery.
9. `package` creates a hash-indexed ZIP only for a game-ready reviewed candidate.
   It never copies into the live `assets/` directory.

An evidence request from a reviewer leaves the candidate `awaiting_evidence`.
If required camera evidence changes, update the protocol and initialize a new
run; do not edit an existing packet. Gate reviewers always receive critical
close-ups even when those regions were not in the plan.

## Manifests and calibration

The deer and trout JSON files contain exact reference paths/crops, camera
transforms, a mandatory head detail, source paths, constraints and provisional
budgets. Camera `roll_degrees` handles a dorsal illustration whose head points up.
The runner contains no species camera branches. Thin adapters use shared recipes.

Reference masks are **proposals**, extracted using flood fill against the median
paper color and retaining the largest foreground component. Beige paper, shadows,
captions and translucent fins require inspection. `background_tolerance` controls
segmentation; lower values preserve pale fins. Supply an authored crop-sized
grayscale PNG with `mask` when automatic extraction is insufficient.

The manifests intentionally start with `calibrated: false` and `form_floor: null`.
This blocks form readiness, not useful captures or technical export experiments.
Before enabling a gate, inspect masks and alignment, capture known poor and better
anchors, and choose per-view floors grounded in visible defects. Include at least
one withheld proportion regression; do not tune scores to a demanded answer.
Record the calibration rationale and set each reference's `calibrated`,
`confidence`, and `form_floor` in a new protocol/run. A low-confidence view routes
metric tradeoffs to review rather than vetoing a good anatomical correction.

Measurements include uniformly height-aligned IoU, symmetric outline distance
normalized by subject height, and vertical-third IoU. Thirds are geometric bands,
not inferred anatomical landmarks. Absolute world dimensions remain in the audit.
IoU cannot measure material quality or interior anatomical detail.

## Recipes and adapters

- `build_deer`: constructs a black-tailed buck from an empty scene using lofted
  anatomy, branched antlers, seated facial features and cloven hooves. The
  `deer_from_scratch_*.json` plans record the form experiments. Use
  `characters/deer/gauntlet_from_scratch.json` to start a separate run; this does
  not load the earlier convergence deer. This recipe remains a form study,
  not an accepted game asset.
- `affine_region`: continuous world-space scale/translation with a smooth spatial
  blend. Moving the body and its attached feature meshes together avoids stale
  vertex indices. Optional exact object selectors fail when missing.
- `decimate`: budget reduction with a minimum mesh size; refuses armature-driven
  geometry. Inspect thin fins and small features after reduction.
- `bake_atlas`: shared UV packing and procedural base-color baking. Keeps objects
  independently editable but shares one material. It does **not** bake high-to-low
  normals, procedural roughness, translucency, or dense fur into hair cards.

`trout_budget.json` exercises reduction and baking. This is a technical experiment,
not a claim that either operation improves the illustration match.

Adapters expose subject selection, apply and audit. `required_objects` guards
feature inventory; `continuous_objects` checks declared continuous meshes;
`visibility_checks` maps cameras to features that must have an unobstructed sample
ray. Visibility rays are an occlusion diagnostic, not proof of pixel readability.
Rendering and blind detail review remain necessary. Archived/hidden geometry is
excluded. Static export refuses rigs rather than stripping their animation.

## Engine inspection

Godot runs in an isolated project under the candidate directory. It imports the
GLB, captures a close-up and a declared gameplay distance, and verifies nonblank
images. `fish_existing` reproduces the current fish shader and shared atlas;
`wildlife_existing` reproduces coat-material replacement. Both freeze the static
inspection setup. `embedded` displays GLB materials but cannot certify runtime
material compatibility.

The existing fish shader does not automatically use a newly baked atlas. The
wildlife shader likewise replaces most imported materials. Expect those mismatches
to be visible and to fail art review. These checks do not validate swimming,
underwater composition, articulated locomotion, LODs, or installation in gameplay.

## Reliability and cost

Original scene/reference hashes, immutable manifest snapshots and evidence hashes
prevent stale comparisons. Only an ingested review updates the best pointer.
Whole jobs and individual views use hash-verified reuse. Cache keys include input,
protocol, implementation, executable and discovered image dependencies; per-view
keys additionally include the actual render device. Unknown external resources or
non-deterministic custom modifiers should be treated as non-cacheable extensions.

Every submitted plan counts as one planner dispatch, and requesting a packet
reserves one reviewer dispatch and its images/pixels. Abandoned packets remain
charged. These are workflow proxies, not provider token or dollar totals; an
assistant must also account for any extra model work outside this contract.
Candidate, elapsed-time, call and image ceilings stop work without relaxing gates.

## Validation and current scope

```powershell
python -m unittest discover -s art_gauntlet/tests -v
```

The first implementation covers existing-source deer/trout capture, isolated
recipe edits, metrics, blind review ingestion, rollback, export/reimport,
Godot evidence and gated packaging. See [the implementation report](../ART_GAUNTLET_IMPLEMENTATION.md)
for real runs and observed failures.

General concept-only animal construction, a bear trial, high-to-low normal/fur baking,
parameter optimization, arbitrary bespoke edit plugins, multi-loadout rigs and
automatic calibration selection remain future extensions. A successful run of
the module does not imply either existing animal has reached 8/10.
