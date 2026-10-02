# Component retention contract — proposed amendment

Status: design only. These gates are not implemented or validated yet.
This amendment supersedes the earlier informal retention proposal, not the
existing implementation. Next development targets a selected anatomical base
mesh; the primitive deer remains a diagnostic fixture, not a rescue project.

## 1. Improvement is not quality approval

Before a run starts, record each region's reference views, required close-ups,
stage-specific criteria, measurable landmark tolerances, and acceptance rules.
Do not invent numerical anatomical tolerances without examining the chosen
mesh and references. An incomplete protocol blocks a quality claim.

A working checkpoint may improve while remaining below the quality bar.
Quality approval requires every declared criterion in every required view to
score at least 8/10, no unresolved moderate/major or critical discrepancy,
all mechanical and landmark checks passing, and agreement from two fresh
reviewers against the same evidence. Missing evidence or conflicting reviews
blocks approval. An average cannot hide a failing criterion or view.

Stage scope must be explicit: form approval does not approve unfinished coat
materials, rig behavior, or game export. A candidate cannot buy forgiveness
for one region's regression with another region's improvement.

## 2. Hard scope locks and explicit quality freezes

Everything outside the declared edit region and permitted dependency set is
locked from the start. A scope lock is a preservation rule, not a quality claim.
Passing the higher regional quality bar creates a quality-approved checkpoint.
Both kinds of locks are enforced; neither is a suggestion to the planner.

Every unfreeze requires a recorded reason, named fields/regions, boundary and
rig dependencies, acceptance criteria, and affected approvals to invalidate.
It must precede the edit. Never silently expand scope or overwrite the previous
baseline. Retain the last approved component and the last working checkpoint
separately, with hashes and provenance.

## 3. Preservation checks are mechanical and unlit

Do not use beauty-render pixel equality as a preservation gate. Beauty views
remain reviewer evidence. Their cross-region shadows and reflections are
legitimate coupling and are not repeat-render noise.

For protected regions, use fixed-camera isolated renders that exclude editable
neighbors: unlit object/region IDs and silhouette, plus depth or object-space
position passes. A flat ID image alone cannot detect interior deformation that
leaves the silhouette unchanged. Disable lighting, AO, shadows, reflections,
denoising and exposure effects in these comparison passes.

Use canonical data comparisons as well: topology and stable element ownership,
protected vertex positions, materials and color attributes, UVs, transforms,
modifiers, and renderer/camera configuration. Set data tolerances and image
thresholds before editing; verify render repeatability. Never enlarge a
threshold to admit a failed candidate. Scope-map or protocol changes require
explicit invalidation and revalidation.

Full-scene unlit views check declared attachment and occlusion constraints
separately. Do not reject every full-scene pixel changed by an editable neighbor.
Explicitly record which boundary changes are allowed and which are failures.

## 4. Protect rig dependencies from the first pass

Record and protect bone names, hierarchy, rest transforms, mesh/bone parenting,
bind relationships, vertex-group names and per-vertex weights, armature
modifiers, constraints, drivers, actions, and shape-key topology/data/relations.
Topology-changing operations are out of scope unless an explicit migration
plan preserves correspondence and revalidates all affected dependencies.

Unchanged rig data alone does not prove good deformation after a shape edit.
Use a fixed pose/shape-key test suite, chosen with the base mesh, with joint
landmarks, attachment checks and scoped visual evidence. Repeat relevant checks
after export/reimport. The current static-export implementation does not provide
this rig-preserving workflow yet; that limitation must be resolved first.

## 5. Stop after two unsuccessful candidates in a region

A mechanical failure or a rejected regional improvement counts as an
unsuccessful candidate. Two consecutive unsuccessful candidates stop that
regional loop before a third candidate or paid critique is dispatched.
An accepted regional improvement resets the streak. Rewording a hypothesis or
renaming the same region does not reset it. Restart requires a recorded change
of approach, scope or starting geometry and a new bounded attempt budget.
Overall candidate/call/time ceilings still apply, including to tiny improvements.

## 6. Prove rejection and permission to proceed

The harness must pass these fixtures before another art run:

| Fixture | Required outcome |
| --- | --- |
| Identical scene repeated with fixed protocol | Pass |
| Protected vertex moves without changing its flat-ID silhouette | Fail via data/depth checks |
| Protected material, transform, weight, bone parent or shape key changes | Fail |
| Valid edit inside an unfrozen region; protected data unchanged | Pass preservation |
| Editable ear casts a new shadow on the protected neck in the beauty render | Pass preservation |
| Editable neighbor legitimately occludes a protected region within declared allowances | Pass preservation |
| Attachment crosses a prohibited boundary or violates a declared constraint | Fail |
| Region improves from poor to mediocre, below 8/10 | May retain working checkpoint; no quality approval |
| Region meets all preregistered criteria with two confirming reviews | Quality approval and freeze |
| Two consecutive unsuccessful regional candidates | Stop; no third dispatch |
| Source passes but export damages weights or shape keys | Fail delivery |

Passing preservation means only that protected content survived. It does not
approve the quality of the editable region. Report false positives and false
negatives against these fixtures; an always-reject gate fails validation.

## 7. License provenance is part of delivery

Record the source URL, author, original file hash, exact license/version, supplied
notices, modification history, and licenses for mesh, rig, textures and animations.
Do not equate an asset being downloadable with permission to ship it.

CC BY 4.0 requires appropriate credit, a license link, and an indication of
changes, alongside its other terms. CC0 1.0 is a public-domain dedication and
does not impose the same attribution condition. Preserve provenance for both.
For an attribution-bearing asset, verify that required credit/notices travel
into the shipped product and redistributed asset bundle; a development-only
note is insufficient as the project's delivery policy.

Official sources: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
and [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

No base mesh has been selected or downloaded as part of this amendment.
