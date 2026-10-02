# Qualification-first mechanical routing experiment

This implements the proposed A/B/C experiment without changing the mechanical
audit or its worker. It uses the independently checked three-scene fixture and
stops on the first qualification failure. No model is dispatched automatically.

Run from `C:\Users\mmurp\1848` with Python 3.12 and the existing Pillow/Blender
installation. No new scenes, captures, renders, scoring, or state resets occur.
The frozen independent reference and observer live in the prior ignored artifact
directory; preserve it alongside the source packet when transferring the study.

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python experiments/minimum_audit/experiment.py init artifacts/routing_economics_02 --strong-model gpt-6-astra --cheap-model gpt-5.6-luna
python experiments/minimum_audit/experiment.py qualify artifacts/routing_economics_02
python experiments/minimum_audit/experiment.py summary artifacts/routing_economics_02
```

`init` refuses an existing directory, checks that original fixture bytes still
match the independent audit, saves the protocol, and freezes implementation,
experiment code, inputs, reference and observer hashes. Run it **before tests**.
Subsequent code or input changes require a fresh study; never rewrite the protocol
or earlier evidence to make an existing study proceed.

Qualification order is intentionally economical: incomplete worker observations,
a malformed final worker sample, normal controls, missing required image, scope
mismatch, and a real nonzero worker process. The first two inject faults at the
subprocess boundary; the last supplies Python as the worker executable, which
rejects Blender arguments without invoking the known Windows invalid-binary
dialog. These are tests of captured evidence and error handling, not new scene
candidates. Each case saves copied input, process output, exit code and result.

Exit 1 from `qualify` means the experiment found a disqualifying result. Remaining
cases and every comparison arm are skipped. Exit 2 means a harness/refusal error.
The tested CLI's exit 1 on the ordinary negative control is expected and counts
as successful qualification when its completed results exactly match the oracle.

After qualification passes, these commands enable the comparison:

```powershell
python experiments/minimum_audit/experiment.py prepare artifacts/routing_economics_02
python experiments/minimum_audit/experiment.py start artifacts/routing_economics_02
```

The schedule is A/B/C, B/C/A, C/A/B. A and B use the same unchanged legacy tools
with the frozen strong/cheap model IDs. C executes the deterministic command.
Three batches replay three unique samples; they are not nine independent controls.
Only one slot can be active. No tests or deliberate CPU work should overlap runs.

For A/B, `start` emits a `dispatch.json` with a fresh-context prompt, the assigned
packet and an instrumented legacy command. The coordinator must actually dispatch
that prompt to the specified model, with no prior audit history or answer key,
and retain its transcript. The model runs the supplied `legacy` command. The
harness does **not** substitute a Python replay for a model dispatch. The private
mapping is outside participant packets, with renamed folders and sample names;
this is procedural blinding, not an OS access-control boundary.

The coordinator fills a copy of `receipt_template`, then records the run:

```powershell
python experiments/minimum_audit/experiment.py finish artifacts/routing_economics_02 PATH_TO_ACTUAL_RECEIPT.json
python experiments/minimum_audit/experiment.py start artifacts/routing_economics_02
```

Receipts require exactly one A/B dispatch and an observed intervention count.
Use null for unavailable usage, not zero. Token/cost values require a source;
total billed cost must explicitly include coordinator effort and use one currency
across comparisons. There is no provider authentication inside this local harness:
retain actual provider exports/transcripts as receipt sources. Invalid receipts
leave the active slot pending; they never create successful results.

C runs synchronously and records zero model-worker dispatches, with coordinator
tokens and total cost unavailable. Its start-to-finish duration is measured; A/B
duration includes dispatch, reasoning, tools, coordinator delay and receipt
submission. Report these boundaries and preserve coordination overhead separately.
The observer retains console reads and logs successful Blender starts; its
overhead is included. Model reasoning/tool calls outside the legacy subprocess
must be counted in the receipt/transcript, not inferred from Blender starts.

Every completed slot must match the entire independent nested sample results and
preserve input hashes. A failure stops the comparison, with no repair or retry in
that study. The summary reports medians and interventions only after all nine
slots complete. Adoption requires qualification, exact correctness, no increased
C intervention count, and lower C time or complete comparable operating cost.
Capture provenance remains a limitation. Tokens and runtime are never converted
to credits. Setup amortization remains unavailable without sourced setup cost;
the harness makes no break-even claim.

Run the experiment-controller tests separately from actual comparison runs:

```powershell
python -m unittest discover -s experiments/minimum_audit/tests -v
```

The experiment controller's tests validate stopping, orchestration, accounting
and receipt rules. They do not establish that the production audit qualifies.
