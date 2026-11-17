# CombatAlchemy Asset Production Standard

> Approved in conversation; saved 2026-11-17. Source of truth for new sprite requests.
> Creative companion: [Style and Vision](./STYLE_AND_VISION.md).
> First delivered asset: [Tube 01](../sprites/potions/tube_01/README.md).
> Hero sprite reference: [Researcher 01](../sprites/characters/researcher_01/README.md) — hood, gas mask, white headlamp, backpack; replaces broad-brimmed-hat guidance for new hero art.

## Reusable request

```text
Asset:
Purpose: character / world prop / UI / environment / VFX
Description:
Required details:
Size relative to the player:
Facings and states:
Animations:
Reference or related existing asset:
Special requirements:
```

Only asset, purpose and description are required. Infer the rest from this standard
and existing assets; ask only about material ambiguity. Default to one static
variant, transparent background, canonical palette and versioned filenames.

## Visual rules

Pure 2D pixel art; melancholic dark fantasy; practical worn apparatus; deliberate
clusters, crisp edges and readable silhouettes. Gameplay uses elevated three-quarter
view; UI apparatus uses front view for readable contents. Upper-left light.
No painted texture, antialiasing, soft gradients, baked text, watermarks or stands
beneath portable vessels. Separate glass from liquid; do not tint ordinary materials.

Grayscale: `#101010 #282828 #404040 #606060 #888888 #B0B0B0 #D8D8D8 #F0F0F0`.
Alchemy accents come from `shared/alchemy/ChargedNeonPalette.tres`: red `#FF2E50`,
green `#9CFF38`, blue `#29D9FF`, health `#FF3BD4`, damage `#20F5D0`.

## Dimensions and animation

Project canvas: **1920 x 1080**, nearest filtering. Character cell: **64 x 80**;
full character sheet: **384 x 320**. Four rows: front, back, side_left, side_right;
six columns: two idle then four walk frames. Idle loop 1.6 s, walk loop 0.72 s.
Stable feet and per-frame left/right hand markers. No mirroring, baked held bottle,
frame interpolation or changes to gameplay timing. The active character displays at 2x with the previous ground alignment.
Physics and camera coordinates are unchanged.

Small world props default to 32 x 32; medium props 64 x 64; UI icons 32 x 32.
Large props and VFX use explicit player-relative dimensions. Fullscreen menu
backgrounds are 1920 x 1080. Preserve transparent padding and proportions.

The user-provided vessel reference overrides generic bottle dimensions:

| Vessel | Form | World PNG | UI PNG |
| --- | --- | --- | --- |
| 1 | Short straight test tube | 8 x 20 | 16 x 32 |
| 2 | Longer straight test tube | 8 x 28 | 16 x 40 |
| 3 | Small round flask | 16 x 24 | 24 x 32 |
| 4 | Large round flask | 20 x 28 | 32 x 40 |
| 5 | Rare bulky portable flask | 24 x 36 | 40 x 56 |

These are native canvases, not screen dimensions. Draw UI variants separately;
use integer enlargement and nearest sampling. Tube 01 currently displays at 2x
in the world and 5x in the existing mixer footprint. Other vessels are not implemented.

## Production and deliverables

Use built-in ImageGen for raster source art with the accepted reference. The user
has authorized scripted image processing: native-grid reconstruction/cleanup,
cropping, exact sizing, palette mapping, alpha cleanup, masks and sheet assembly.
A resized generation alone is not a finished sprite. Inspect and repair clusters.

Deliver versioned PNG RGBA files inside the project, integer-enlarged review PNGs,
and JSON with dimensions, pivot, display hint and, when applicable, frame order,
timing and hand markers. Record the prompt, reference and processing. Keep reference
and preview files in `docs/asset_reviews/`; runtime files belong under `sprites/`.
Use real alpha (0 or 255 for ordinary sprite edges). Glass highlights, inner masks
and colored contents may be separate runtime layers. Do not promise layered PSD
or Aseprite files. Scene integration is performed when requested, preserving APIs.

Before shipping: verify exact dimensions/palette/alpha, inspect native and enlarged
views on light/dark backgrounds, check composition and lighting, stable animation
contacts and sockets, and relevant runtime states. Mark failed candidates honestly.
Never overwrite accepted assets unless replacement is requested. New requests use
this standard without repeating the full style discussion.
