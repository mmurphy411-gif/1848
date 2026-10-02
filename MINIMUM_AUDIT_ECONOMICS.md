# Minimum audit economics experiment

Adopt `python -m art_gauntlet.minimum_audit` for the existing mechanical evidence
audit. Three paired replays produced exactly the same per-sample gate, observed
vertex changes, verdicts and reasons as the legacy scripts. Median process wall
time fell from **5.632 s to 2.888 s** (about 49% on this fixture). This is a script
runtime reduction, not a measured token, credit or agent-turnaround saving.

## Intervention and acceptance criteria

Inspection of `minimum_gate.attempt` and the routing trial found that the minimum
gate itself already uses no models. The avoidable model dispatch was the later
Luna audit: it ran a Python comparison and reopened the baseline separately for
each sample in three Blender processes. Its decisions were fully mechanical.

The small reusable replacement has one CLI and one Blender worker. It retains
`minimum_gate.compare` unchanged, including every configured protected ID/matte
comparison and all four data comparisons. One Blender process reads the baseline
coordinates once and then each saved sample. The declared-coordinate tolerance
remains 1e-6. No check is skipped for already-rejected samples. Packet scope must
match the fixed config, required files must exist, and evidence hashes must remain
unchanged during execution. Worker errors and partial output cannot accept.

[Acceptance criteria](artifacts/audit_economics_01/protocol.json) were written
before implementation testing: exact legacy result equality on all three samples,
correct classifications, three-to-one process reduction, lower median runtime
across three paired runs, failure handling, and unchanged protected files. All met.
This adds no retention requirement and does not activate the older full workflow.

## Baseline versus experiment

The unchanged legacy `luna_audit.py` and `verify_scene.py` ran on fresh copied
packets. The experimental CLI read those same copied scenes, snapshots and images
into separate fresh output directories. No model was dispatched for either replay.
Run order alternated baseline/experiment, experiment/baseline, baseline/experiment.

| Measure, per three-sample batch | Baseline replay | Experimental |
| --- | ---: | ---: |
| Process wall time, pair 1 | 5.632 s | 2.888 s |
| Process wall time, pair 2 | 5.615 s | 2.929 s |
| Process wall time, pair 3 | 5.708 s | 2.843 s |
| Median process wall time | 5.632 s | 2.888 s |
| Blender invocations | 3 | 1 |
| Saved scene opens | 6 | 4 |
| Correct sample classifications | 3/3 | 3/3 |
| New renders / candidates | 0 / 0 | 0 / 0 |
| Actual model dispatches in this replay | 0 | 0 |
| Historical audit workflow model dispatches | 1 (Luna) | 0 required |

`sample_a` rejected the protected-vertex violation; `sample_b` accepted the allowed
adjacent edit despite its shadow change; `sample_c` accepted the prescribed ear-tip
move. Exact nested result equality held in all three pairs, beyond agreement of
booleans. These are **three unique samples replayed three times**, not nine
independent controls. The new CLI exits 1 on this packet because a sample is
correctly rejected; `completed: true` records a successful audit execution.

Evidence: [comparison and timings](artifacts/audit_economics_01/comparison.json),
[individual pairs](artifacts/audit_economics_01/trials.json),
[experimental audit](artifacts/audit_economics_01/experimental_1/audit.json),
[legacy audit](artifacts/audit_economics_01/legacy_1/luna_audit.json).

## Total observed overhead and validation

This was one coordinator session, with zero worker dispatches, reviewer model
calls, retries, new candidates, failed new candidates, renders, or model image
pixels submitted. The prior negative control is reused evidence, not a new failed
attempt. No stop state was reset or bypassed. Actual coordinator tokens, cached
tokens, worker tokens and billed credits are unavailable; they are not inferred
from these proxies. The implementation, inspection and reporting cost is real
setup overhead, not included in the per-batch speedup.

The entire comparison harness took **26.814 s**, including **0.141 s** copying
inputs, six Python script processes, **12 Blender invocations** and **30 scene
opens**, plus hashes and result checks. Replays had no execution failures or
repairs. Tests ran once for the 10 new focused cases (0.122 s unittest time), then
once for all 47 module cases (2.328 s); both passed, totaling 57 test executions.
The full suite overlapped part of the benchmark, so wall times are descriptive
single-machine observations, not isolated performance measurements. Process and
scene-open counts are deterministic; no statistical generalization is claimed.

The [session ledger](artifacts/audit_economics_01/session_ledger.json) records the
coordinator's observed elapsed window and tool calls, including setup and report
preparation. Initial request/workspace/document reads preceded the first clock
sample, so full turn time is unavailable; the measured window is a lower bound.

Tests cover permitted movement, protected movement, wrong/no/missing edit,
topology mismatch, nonfinite coordinates, pixel rejection, absent evidence,
scope mismatch, worker failure, partial output, evidence changing during the
worker, and refusing an existing output directory. Existing persisted stopping
and edit-ordering tests also passed. Hashes matched for **182 files** across the
source horse, prior minimum-gate/routing evidence, gate implementation/config,
and retention contract: [before](artifacts/audit_economics_01/protected_before.json),
[after](artifacts/audit_economics_01/protected_after.json).

## Limits and recommendation

The evidence supports eliminating the model dispatch for this mechanical task
and batching its saved-scene reads at preserved observed correctness. The CLI is
independent of candidate generation and does not update any approval or best
pointer. Use its per-sample acceptance result as mechanical audit evidence.

Fidelity gain remains **unproven**. These ear moves lack a meaningful target
reference demonstrating a smaller discrepancy; no reference/before/after artistic
claim is made. The audit still relies on captured snapshots and images for
protected material/rig/data comparisons, while independently reopening actual
vertex coordinates. It does not newly certify stale or misbound captures,
arbitrary rigs, anatomy, deformation, or visual appeal. Stronger reasoning is
still needed to choose a worthwhile edit and interpret ambiguous visual evidence.

The saved coordinator/model cost per future audit is unmeasured, as is the number
of audits needed to recover this implementation's setup cost. Adopt this narrow
command; do not extrapolate the runtime ratio into credit savings or use it as an
art reviewer replacement.

Implementation: [CLI](art_gauntlet/minimum_audit.py),
[Blender worker](art_gauntlet/minimum_audit_worker.py),
[tests](art_gauntlet/tests/test_minimum_audit.py).
The [comparison driver](artifacts/audit_economics_01/run_comparison.py) and logs
are local ignored artifacts; preserve that directory when transferring evidence.
