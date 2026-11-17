# Tube 01 — portable test tube

Delivered 2026-11-17 from the user's vessel 1 references and built-in ImageGen.
Native pixel clusters were deliberately reconstructed from the generated rim,
left highlight and rounded base, with binary alpha and the eight-value ramp.
The final native files are not unprocessed downscaled generation outputs.

- World: 8 x 20, centered pivot (4, 10), displayed at 2x; same sprite held/flying/placed.
- UI: 16 x 32, top-left pivot, displayed at 5x at (32, 20) in the 144 x 190 FlaskView.
- `*_glass_v001.png`: neutral glass foreground; never tint with potion color.
- `*_mask_v001.png`: white internal region; runtime supplies liquid color.
- `tube_01_v001.json`: dimensions, pivots, filenames and display hints.
- [Review images and source](../../../docs/asset_reviews/tube_01/).
- [Production standard](../../../docs/ASSET_PRODUCTION_TEMPLATE.md).

The UI retains geometric feedback markers and foam. A band shader clips all
reagent layers to the native mask; fixed-grid surface steps replace rotated liquid
geometry. No potion behavior, collisions, recipe timing or player API changed.

## ImageGen prompt

Single isolated EMPTY tiny straight alchemical glass test tube for CombatAlchemy,
vessel 1: narrow straight cylindrical body, short flared elliptical open rim,
rounded closed bottom, no foot, stand, cork or decoration. Source for an 8x20 world
sprite and separately drawn 16x32 UI sprite. Upright front view, upper-left highlight,
dark right edge, transparent background, strict eight-value neutral grayscale.
Few deliberate pixel clusters; no liquid, text, shadows outside the tube,
antialiasing, gradients, watermark or surrounding objects.

References: user attachments `photo_2026-09-15_16-59-49.jpg` (vessel specification)
and `photo_2026-09-15_16-42-24.jpg` (leftmost tube silhouette).
