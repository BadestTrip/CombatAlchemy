# Researcher 01 — hooded field alchemist

> Delivered 2026-11-17. Native sprite asset based on the user's hood/gas-mask reference.
> [Production standard](../../../docs/ASSET_PRODUCTION_TEMPLATE.md).

## Contents

- `researcher_01_v001.png`: transparent **384 x 320** sheet, 24 cells of **64 x 80**.
- `frames/`: each of the 24 frames as a standalone transparent PNG.
- `Researcher01Frames.tres`: Godot SpriteFrames, 8 looping animations.
- `Researcher01Data.tres`: exportable PlayerSpriteData with pivot and hand markers.
- `researcher_01_v001.json`: cell rectangles, frame durations, ground pivot,
  anatomical hand positions and recommended held-item draw order per facing.
- [Review folder](../../../docs/asset_reviews/researcher_01/): light/dark 4x sheets,
  GIF/APNG animation previews, generated source, character reference and exact prompt.
- [Godot preview scene](../../../docs/asset_reviews/researcher_01/Researcher01Preview.tscn):
  open and run this scene to view all four idle and walking directions.

Rows: `front`, `back`, `side_left`, `side_right`.
Columns: idle 0, idle 1, walk 0 contact, walk 1 passing, walk 2 opposite contact,
walk 3 opposite passing. Idle: 0.8 s/frame (1.6 s loop). Walk: 0.18 s/frame
(0.72 s loop). Godot names are `idle_front`, `walk_front`, etc.

## Visual identity

Compact stitched hood/leather cap, white headlamp, two-lens gas mask, practical
ragged coat, gloves, boots, backpack and rolled bedroll. This supplied reference
replaces the broad-brimmed-hat design for this new asset. Neutral eight-value ramp;
no sepia, colored costume, bloom, floor shadow, text or held bottle. Both hands
remain empty. Left/right facings use independently generated artwork and lighting.

The ImageGen sheet is retained as source only. Native cleanup fixes identity by
using one neutral head/coat/pack per facing. Pixel-authored arm movement and boot
contact/passing poses preserve source texture; alpha is binary and all opaque
pixels belong to the canonical ramp. Integer movement replaces smooth rotation.
This is a compact four-frame walk cycle, not a full set of action animations.

## Godot use

Assign `Researcher01Frames.tres` to an AnimatedSprite2D, choose one named animation,
set nearest filtering, `centered = false`, and `offset = Vector2(-32, -74)`.
The feet anchor is the sprite node origin. Use integer scale; **2x** is the active character display scale; gameplay camera and collision
coordinates retain their existing settings.

Socket positions are native-cell coordinates. With centered=false and the offset
above, a sibling marker's local position is `(hand - Vector2(32,74)) * sprite_scale`.
Read the corresponding frame's `hand_draw_order` (-1 behind, +1 in front) when
placing an independent held item. The right-hand socket stays anatomically right
on turns. Do not mirror facings or interpolate frames.

**Integration status:** active in CombatScene and the canonical player workshop.
`characters/player/PlayerModel.tscn` uses `Researcher01Frames.tres` plus the typed
`Researcher01Data.tres` socket resource. The model keeps its existing gameplay API,
plays at 2x, and offsets FacingRoot to the previous y=38 ground line. The held
bottle follows a stable right-hand Marker2D updated on every sprite frame.
Legacy rig and old hero experiments are archived under `deprecated/`.

## Reproduction and checks

`python docs/asset_reviews/researcher_01/build_assets.py` rebuilds this exact version
from the retained source, using Pillow (installed locally under `.godot/asset_tools`).
This reproducibility script writes v001 files; use a new version for new designs.
Validation covers dimensions, eight-color palette, 0/255 alpha, padding, stable feet,
unique animation frames, hand markers inside the silhouette, exact timings and
successful Godot SpriteFrames load. Review GIF/APNG loops for artistic acceptance.
