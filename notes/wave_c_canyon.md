## Wave C — C-canyon (canyon reach, ridge forest, cliff kit, talus)

Second attempt on the Stage 2 gates. Tour `c_canyon` (`artifacts/visual-tour/c_canyon/`,
before/after sheets against `merge8`). Render-only throughout: collision, river volumes,
the 10 back-wall hulls, the claim reach's render surface and S4's wall-plant seating are
unchanged.

### What changed

**Ridge relief** (`scripts/canyon.gd`). The slopes above both rims of the bent reach now
carry structure instead of a smooth sweep: cliff bands (7 m risers of 8-19 m on the far
wall at about 74/128/196/262/335 m above the rim, 4 on the near wall, each wandering
±18 m and dying out along the valley), draws (gullies 7-16 m deep that meander down the
slope) and tors (low rock knobs seeded per 70 × 56 m cell, most on the crests). The crests
are wider and less varied (half-widths 85/150/190 m, ±30 % height) so their faces lie at
35-50 degrees and can hold timber between the bands. On stretches of the bent reach the
three claim-style cliff bands below the rim merge into one face, and their faces stand
out or fall back by up to 5 m (`rib()`), so the walls round the bend are not the claim's
terraces repeated. The same functions return a ground cover per point (forest density,
draw, rock, scree): timber is thick in the draws, open on spurs and crests, absent on
rock and the scree fans below each band. Stage 2's three-octave noise on the bent reach
was replaced by two longer octaves (its finest octave stood up as 60-degree spikes on
the finer grid).

**Render grid** (`greybox.gd::_visual_section/_visual_column/_visual_triangle`). The bent
reach samples the far slopes every 5 m (near slopes 10 m) up to 300 m above the rim and
splits the 20 m columns into 5 m (10 m beyond |x| 330, unchanged beyond 450). Claim-reach
columns repeat their FINE rows to the same count, so their surface is identical (the
repeats are skipped as zero-area). `wall_point()` gained an `eased` flag: more than 15 m
into the bend its ledges and most of its noise fade out above the rim, leaving the forms
to the relief. The vertex colour carries the ground cover and UV.x the height above the
rim to the ridge shader. The ridge material now starts where the slopes do (8 m above
the rim, meandering between |x| 175 and 205 m) and takes the cliff bands too beyond
|x| 205-245 m. CanyonReach: 14.7 k → 48.6 k triangles (no shadow, no GI).

**Ridge shader** (`shaders/ridge_forest.gdshader`, rewritten). Dry Sierra slope in late
summer instead of pale soil: needle duff and red-brown soil under timber, olive chaparral
and cured tan grass on sun-facing (-Z) slopes, pale scree fans, and slate/greenstone rock
in dipping strata broken into jointed blocks that are lit block by block. Steep ground is
rock whatever the cover says; the first 8-22 m above the rim are broken cliff top. Within
~100 m of the bend start the rock continues the terrain shader's strata exactly (same
integer hash and fbm), blocks fade and grass/chaparral give way to duff, so the material
change at |x| ≈ 185 m no longer shows as a line from the high cameras. Canopy texture is
clumped by the cover, with oak-coloured crowns in the lower sunny stands.

**Treeline** (`canyon_dressing.gd::_treeline`). 2,600 trees per end (was 2,000) placed by
the ground cover, not uniformly: spires 9-33 m tall (most young, a few big; draws grow
them 30 % taller; below the rim only small ones on benches) and, on lower south faces,
low six-sided oak domes (24 triangles). The seam trees at |x| 160-240 m are fir and cedar
only: the distant ponderosa LOD is a long bare trunk under a small crown and read as a
pole at 150-250 m.

**Far wall** (`canyon_dressing.gd::_tall_cliffs/_toe`). Every 40-80 m along the claim
reach a slate scan spans two cliff bands and the bench between (stretched up the face,
out of GI), replacing the band pieces it covers, so the wall reads as one high broken face
rather than a quarry ledge. At the waterline, rock fallen from the wall in runs with gaps:
talus 0.9-3.6× scale, some standing in the shallows, and low bedrock bluffs (cliff_face
scans) facing the river — the foot of the wall is no longer one straight line along the
water. Seed 184828/184829; all MultiMesh, no shadow, no collision.

**Kit colour** (`shaders/cliff_kit.gdshader`). `scan_mean` was the scans' sRGB mean (0.40)
applied to linear texels (0.15), which left the kit at about two thirds of the albedo the
shader intended; in merge8 the pieces' mean luma matched the wall's (0.27 vs 0.27 on the
far wall) only because the scans' crevices ran near black, and they read as flat grey
lumps without the wall's banding. Now 0.147, with the scan's light/dark eased (pow 0.75),
slate/greenstone tints set against the terrain's bedrock set, the walls' strata (same
hash) multiplied in so a piece's bands line up with the wall's, and pieces in the bend
lifted to meet the paler ridge rock. Kit vs wall luma with the dressing shown/hidden:
far wall 0.30 vs 0.28, bend at 300 m 0.22 vs 0.20, high camera 0.34 vs 0.30 — a touch
proud, as sunlit outcrops are. SPECULAR 0.3 (rock is a poor mirror). LOD bias 0.45 → 0.25 for all kit groups.

### Findings

| # | Finding | Result | Evidence |
|---|---|---|---|
| 1 | Distant slopes smooth, rockless, even same-size trees | fixed (own check) | `downstream_10h`, `upstream_10h`, `valley_low_10h` end on banded rock and timber in clumps with open ground; `look_k/high_dn` shows bands, tors, draws, scree |
| 2 | Snowfield in `downstream_06h` | fixed | top centre is now duff/olive/tan with rock bands; no pale ground left |
| 3 | Far wall base straight, wall low | partly | `far_wall_10h`: rocks and bluffs break the toe, tall faces span two bands; the water strip itself (C-sky) is unchanged and short stretches of plain toe remain |
| 4 | Seating; seam at |x| ≈ 185; seam poles | fixed / fixed / fixed | talus sunk 20-40 % of height; seam strata continuous (`look_l/seam_hi_dn`); seam trees fir/cedar |
| 5 | Night streak `downstream_00h` | not mine | it is the terrain material's specular on the far wall (gone with the terrain swapped to a SPECULAR 0 flat material; unchanged with the dressing hidden) — `terrain.gdshader` (C-ground) |
| 6 | Kit vs terrain colour | fixed | see Kit colour |

### Performance

GPU ms of my nodes (CanyonDressing + CanyonReach) shown vs hidden, same probe and
protocol as `perf_probe/attribution.md` (20th-percentile of 12-frame windows, 16 cycles),
before (HEAD files) and after alternated in the same session:

| view | HEAD (merge8 files) | Wave C | Δ | rounds (quiet windows) |
|---|---:|---:|---:|---|
| downstream | 0.20 | 0.18 | −0.02 (rounds: +0.00, −0.02, +0.01, −0.02) | 4 rounds, 2-3 launches each |
| wade | 0.27 | 0.28 | +0.01 (rounds: −0.00, −0.01, +0.03, +0.02) | 4 rounds |
| overview | 0.23 | 0.16 | −0.08 (rounds: −0.06, −0.11, −0.07, −0.08) | 4 rounds |

Logs: `artifacts/c_canyon/ab_r1..r4.log` in the worktree (r1 was taken while the hung
processes were still loading the GPU; r2-r4 after they were stopped). Inside the total:
the kit LOD bias 0.45 → 0.25 saves 0.03 (bar) / 0.07 (overview); the new ridge shader
costs ~0.03 more than Stage 2's at the bar, less in the overview; toe rock and tall faces
0.01-0.02 together. All three views stay at or under +0.3 ms; the wade view is flat
within the noise floor (null-toggle IQR ±0.01-0.02).

Claim build (headless instantiate + ready, alternated): 2.9-3.0 → 3.7-4.0 s (+0.8 s: the
finer bent-reach grid and its ground cover ~0.6 s, the cover-driven treeline ~0.3 s; first
cut from +2.6 s by caching per-column relief and coarser near-slope rows). Not a gate.

### Gates and checks

| Gate | Target | Measured | Result |
|---|---|---|---|
| Stage 1 colour gates (10:00/13:00) | lower-half luma 0.38-0.50, sat ≥ 0.20 | downstream_10h 0.430 / 0.281, downstream_13h 0.456 / 0.276 | pass |
| Golden hour | ≥ 0.90 × baseline | 0.877 (merge8 0.877) — S-sky's | unchanged |
| My GPU cost | ≤ +0.3 ms any view, not risen | see table | pass |
| Collision | unchanged | ground trimesh from unchanged sections; hulls untouched; river volumes untouched | pass |
| Suite | all pass | 37/37 (`LABEL=c_canyon`) | pass |
| Asset audit | exit 0 | 134 files, 0 failing (no assets added) | pass |

No regression amendments. No assets added or changed (0 MB).

### Still weak

- The ridge rock is procedural blocks on a 5 m mesh: right at 200-600 m, flat if a free
  camera flies close. No kit pieces stand on the ridge tors.
- Spires and domes stay low-poly cones and domes; fine at 300 m+, toy-like up close.
- The far waterline is still a clean edge where there is no toe rock; the near-black
  water strip under the far wall is C-sky's.
- The night streak is in `terrain.gdshader` (C-ground): its specular on the moonlit far
  wall.
