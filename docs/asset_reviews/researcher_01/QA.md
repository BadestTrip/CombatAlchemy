# Researcher 01 verification — 2026-11-17

- 24 individual RGBA PNG frames, each exactly 64 x 80.
- Atlas exactly 384 x 320; every atlas cell equals its individual PNG.
- All opaque pixels use the canonical eight neutral grayscale values; alpha 0/255.
- All frames have transparent padding and a stable ground boundary at y=74.
- Both per-frame hand markers lie inside the silhouette.
- Every idle pair and every four-frame walk cycle contains distinct images.
- GIF loop timings: idle 1600 ms, walk 720 ms.
- Godot 4.7.2 imported textures and loaded all eight SpriteFrames animations.
- Godot checked frame sizes/counts, loop durations and active preview playback.
- Light/dark native-grid sheets and a rendered Godot preview were inspected.

Source: built-in ImageGen, then scripted native-grid cleanup and animation posing.
The source sheet is not the final runtime atlas. See source_prompt.txt and build_assets.py.
Runtime integration now uses the same model in combat and workshop. Model tests
verify all 24 frame sockets and held-item depth/scale, phase-preserving turns,
hysteresis, debug compatibility and timing. PlayerActor, Workshop, PotionUse and
ReagentCollection suites pass after the migration.

## Runtime migration verification

All 21 test scenes passed after the migration, including 212 model checks.
`integrated_hands.png` records the shared model with a held potion in all four
facings; `combat_integrated.png` records the active CombatScene. Rear/occluded
hands correctly place the bottle behind the body. A separate read-only code
review found no actionable correctness issues.
