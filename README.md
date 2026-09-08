# 1848

Milestone 1: a playable greybox of one gravel bar on the North Yuba River.
Built with **Godot 4.7.2 standard**, GDScript, and the Forward+ renderer.

## Play

On this machine, double-click **Play.cmd**. It launches directly into the claim
using the local engine in `.tools/`. Alternatively, import `project.godot` into
Godot 4.7.2 and press **F5**. There are no plugins or third-party dependencies.

For a fresh clone, install the standard Godot build and open `project.godot`.
The Windows launcher also accepts a `GODOT_BIN` environment variable containing
the executable's full path, or `godot.exe` on PATH. The engine is not committed.

| Input | Action |
| --- | --- |
| WASD / arrow keys / left stick | Walk relative to the camera |
| Mouse / right stick | Slowly orbit the third-person camera |
| Escape | Release the mouse; press again to quit |
| Left click | Capture the mouse again |

Walk into the shallows to wade. Near knee depth the current slows movement and
returns you toward the bar. The narrowing ends and rear slope redirect outward
movement smoothly. Rocks and canyon terrain have physical collision. There is
no running, jumping, swimming, HUD, or panning in this milestone.

## Blockout

- Approximately 84 by 38 meters of tapered gravel bar on the inside of a bend.
- Continuous canyon slopes on both banks, riverbed, and a curved water volume.
- Seven collidable boulder placeholders, including four near the water.
- A 1.8-meter capsule walking at 2.4 m/s; shallow-water speed drops toward 1.05 m/s.
- Smoothed shoulder camera with a collision-tested 4.6-meter spring arm.
- Neutral daylight and plain materials for judging scale and traversal.

`scenes/claim.tscn` is the main scene. The procedural greybox appears in the editor
when this scene opens; its generated meshes are not hand-authored scene children.
Edit `scripts/claim_layout.gd` for the bend, height profile, and bar proportions;
`scripts/greybox.gd` owns mesh construction and boulder placement. The river and
boundary sample that same layout. Movement, camera, and boundary have separate scripts.
Collision layers are terrain/rocks = 1, walker = 2, river = 3 (bit values 1, 2, 4).

The remaining milestones in `ASTRA_BRIEF.md` are untouched. Water is a transparent
standard material placeholder; detailed lighting, atmosphere, assets, and animation
belong to later milestones. Blender sources and glTF assets will go in `blender/`
and `assets/` when those milestones begin.

## Verification

From the repository in PowerShell (substitute your Godot executable if needed):

```powershell
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import --quit
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_1.gd
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1080 --script tests/capture_greybox.gd
```

The integration test drives the actual scene through physical keyboard bindings,
camera input, dry walking, diagonal movement, wading, prolonged escape attempts,
idle current return, boulder collision, and camera obstruction. A failure exits
with code 1. The render harness saves player and overview PNGs in ignored
`artifacts/` and prints a short 1080p frame-time sample, then closes.

The local render review uses an RTX 5080. This is a baseline check, not validation
of the final game's 60 FPS target on a mid-range GPU. A physical gamepad still needs
a human feel check; automated stick input verifies the bindings and orbit behavior.
