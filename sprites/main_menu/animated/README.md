# Animated Main Menu Art

These files form the scene-backed `1920 x 1080` Field Notes main-menu backdrop.

## Base

- `main_menu_lab_base.png`: exact `1920 x 1080`, opaque, and reduced to the
  canonical eight-value grayscale ramp in `docs/STYLE_AND_VISION.md`.
- The approved AI concept was generated as a clean static laboratory at
  `1672 x 941`, then converted once with nearest-neighbor sampling. Godot does
  not scale this runtime texture.
- Composition: dark UI space at left, shelves and worktable through the middle,
  and the researcher facing the mountain observatory through the right window.

## Animated Layers

| File | Layout | Timing / use |
| --- | --- | --- |
| `clouds_far.png` | `2048 x 180` seamless strip | Moves right at 4 px/s |
| `clouds_near.png` | `2048 x 220` seamless strip | Moves right at 8 px/s |
| `foliage_frames.png` | Four `128 x 160` cells | 3.2 s loop; pivot at bottom center |
| `note_frames.png` | Four `96 x 128` cells | 3.6 s loop; pivot near top center |

The transparent foliage and note sheets use integer regions in
`MainMenuBackdrop.tscn`. Keep their dimensions and pivots stable when repainting
them. Clouds must retain matching transparent first and last columns so
`LoopingPixelLayer.gd` can wrap without a seam.

The former RGB vessel overlays were replaced by six instances of
`vfx/reactive_crystal/ReactiveCrystalPile.tscn`: three full-size table piles and
three `0.55`-scale shelf deposits. Their geometry, glow, and low-simmer motes
are edited in that reusable scene rather than in this raster-art folder.

## Art Direction

The approved base was generated from this prompt:

```text
Create a clean static 16:9 pixel-art laboratory background for CombatAlchemy,
using the approved Field Notes composition as reference. Reserve the left 35%
as deep, uncluttered grayscale negative space for scene-authored title and menu
commands. Across the middle, show a practical forbidden researcher's worktable,
shelves, glassware, books, mortar, drying plants, and pinned apparatus. On the
right, open a large stone window toward a pale mountain road and a distant
ruined observatory; a solitary broad-hatted researcher stands at the window.
Use pure 2D raster pixel art, deliberate clusters, crisp stepped edges, exactly
the project's neutral grayscale hierarchy, strong silhouettes, upper-left
light, and no baked text or UI. Keep the scene static and omit clouds, animated
foliage, loose moving notes, reagent neon, colored lighting, runes, chants,
spellcasting, gradients, blur, bloom, glossy 3D, anime rendering, signatures,
logos, and watermarks. The image will be separated into scene-authored layers.
```

The generator returned `1672 x 941`. After approval, the base was converted
once to exact `1920 x 1080` with nearest-neighbor sampling and mapped to the
canonical eight grayscale values. That source-size workaround is not a runtime
scaling rule.

Crystal deposits use the shared Charged Neon palette: red `#FF2E50`, green
`#9CFF38`, and blue `#29D9FF`. Each pile keeps a nearly white core, saturated
body, dark hard halo, restrained additive aura, and small surface reflection.
`MainMenuBackdrop.reagent_glow_strength` tunes all six instances together.
