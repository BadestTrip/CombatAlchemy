# Alchemical burner flame

Four native 16 x 16 frames, one 64 x 16 RGBA sheet, binary alpha.
Frame pivot: (8, 14); default display scale: 3. Nearest filtering only.
Frames 0, 1, 2, 3 loop at 4-10 FPS according to burner power.
White core, Charged Neon cyan body, dark cyan edge; no global bloom.
The grayscale burner is authored separately in AlchemicalBurner.tscn.

Built-in ImageGen source was produced on 2026-11-17. No API key or CLI generation.
Source and enlarged preview: docs/asset_reviews/alchemical_fire/.
The reproducible build_assets.py extracts cells, uses one common scale,
quantizes to three colors, enforces binary alpha and stabilizes base pixels.
Frame corners are transparent and all frame bases end at row 13.

## Exact generation prompt

Create pixel art game sprite source: four animation frames of a tiny cyan
alchemical burner flame in ONE horizontal strip, four equal square cells,
identical bottom-center anchor. Transparent background. Each frame designed on
a strict 16x16 logical pixel grid enlarged with nearest-neighbor crisp square
pixels, entire sheet logical size 64x16. Flame only, no burner, no glass, no
letters, no labels or watermark. Narrow white #F0F0F0 core, bright cyan #29D9FF
middle, dark cyan outer edge. No blur, gradients, antialiasing, bloom. Four
different subtle flicker silhouettes: upright, lean slightly left, upright split
tip, lean slightly right, seamless loop. Flame base identical in each, 2px
transparent margin all sides. Practical small laboratory flame for grayscale
dark fantasy potion interface. Save generated source for further exact
pixel-grid extraction.
