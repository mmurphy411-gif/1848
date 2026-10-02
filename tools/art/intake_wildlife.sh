#!/bin/bash
# Rebuilds the CC0 intake wildlife (VISUAL_UPGRADE_NOTES.md, Stage 5) from the shared
# download cache: fetch (provenance rows in assets/CC0_MANIFEST.json), then normalise
# with blender/normalize_animal.py. Deterministic; run from any checkout or worktree.
#
#   bash tools/art/intake_wildlife.sh            # everything
#   bash tools/art/intake_wildlife.sh deer       # one species
#
# Blender is $BLENDER, else the default Windows install.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
want() { [ -z "$ONLY" ] || [[ " $ONLY " == *" $1 "* ]]; }
ONLY="$*"
fetch() { python tools/art/fetch_cc0.py "$@" | tail -1 | sed 's/^main: //'; }
normalize() { "$BLENDER" --background --python blender/normalize_animal.py -- "$@" 2>&1 | sed -n '/^NORMALIZED/,$p'; }

# Columbian black-tailed deer: Quaternius "Deer" (doe) and "Stag" (buck), Ultimate Animated
# Animal Pack, via Poly Pizza. Recoloured from rust red to grey-brown, cream belly and rump,
# dark hooves and eyes; the tail's top and the crown painted dark by bone weight; flat
# facets welded and smoothed below 60 degrees; the stag's red-deer rack scaled to 62 %.
if want deer; then
  CLIPS=idle=Idle,walk=Walk,run=Gallop,graze=Eating,alert=Idle_2,headlow=Idle_Headlow,death=Death
  PAINT="Tail1,Tail2,Tail3@back=0.10,0.085,0.075;Tail2,Tail3@up=0.10,0.085,0.075;Head@up=0.30,0.24,0.19"
  doe=$(fetch polypizza T6Cs7tmMHJ glb)
  normalize "$doe" --out assets/wildlife/deer.glb --clips "$CLIPS" --height 1.45 --drop Icosphere \
    --colors "Main=0.46,0.38,0.30;Main_Dark=0.36,0.29,0.23;Main_Light=0.80,0.76,0.68;Hooves=0.10,0.09,0.08;Eye_Lighter=0.10,0.07,0.05;Eye_White=0.50,0.45,0.40;Eye_Black=0.02,0.02,0.02" \
    --smooth-angle 60 --paint "$PAINT" --rest-uv --manifest-id polypizza:T6Cs7tmMHJ:glb
  buck=$(fetch polypizza tQdzbZ1Cmw glb)
  normalize "$buck" --out assets/wildlife/deer_buck.glb --clips "$CLIPS" --height 1.55 --height-exclude Stag_Horns \
    --drop Icosphere --object-scale Stag_Horns=0.62 \
    --colors "Material=0.45,0.38,0.31;Material.003=0.58,0.52,0.44;Material.010=0.40,0.33,0.27;Material.001=0.10,0.09,0.08;Material.011=0.03,0.03,0.03;Stag_Horns:Material.001=0.47,0.41,0.33" \
    --smooth-angle 60 --paint "$PAINT" --rest-uv --manifest-id polypizza:tQdzbZ1Cmw:glb
fi

# Western gray squirrel: Kelgar "Undead Squirrel (ANIMATED)" (CDmir, OpenGameArt, CC0) made
# healthy without sculpting: the Teeth mesh and the red-squirrel ear tufts deleted, the
# snarling jaw closed by rotating its Mouth bone in every clip, and the coat repainted by
# tools/art/repaint_squirrel.py (blood and rot filled from the fur, orange to silver grey
# with white underparts, eyes painted into the empty sockets).
if want squirrel; then
  src=$(fetch opengameart undead-squirrel-animated undeadsquirrell.zip)
  dir=$(dirname "$src")
  paint="$dir/_repaint"   # derived textures stay in the ignored download cache
  python tools/art/repaint_squirrel.py "$dir" "$paint"
  normalize "$dir/squirrel-anim.blend" --out assets/wildlife/squirrel.glb \
    --clips idle=Idle.001,alert=Idle.004,graze=Idle.002,run=Run --scale 0.15 --drop Plane,Teeth,Ears \
    --material-image "Body=Body;Head=Head" --image "Body=$paint/body.png" --image "Head=$paint/head.png" \
    --image-format JPEG --pose "Mouth=rx:-30" --manifest-id opengameart:undead-squirrel-animated:undeadsquirrell.zip
fi
