# CombatAlchemy Pixel-Art Conversion

> Date: 2026-09-12
> Status: Revised during staged implementation. Native animated main menu delivered; gameplay composition and gameplay-art conversion remain pending.
> Revision note: The permanent project canvas is now 1920 x 1080. Earlier fixed 640 x 360, 32 x 40 character, and 48 x 64 flask requirements are historical proposals, not production contracts.
> Creative reference: [Style and Vision](../../STYLE_AND_VISION.md)
> Current implementation: [Project Architecture](../../PROJECT_ARCHITECTURE.md)

## Summary

Keep the existing real-time alchemy concept: movement, mixing, physical potions,
and the intended expedition/discovery loop. Replace its presentation without
adding gameplay systems or adopting the alternative game concepts brainstormed
before this decision.

Confirmed decisions:

- Compact full-body characters, with exact cell dimensions decided from approved gameplay composition.
- Full-body **sprite-sheet animation**, replacing live skeletal presentation.
- An **almost-monochrome** world and characters, with selective alchemical color.
- A permanent **1920 x 1080** project canvas with nearest texture sampling.
- Restyle **every current screen**, including the player-model workshop.
- Use **AI-assisted art**, with explicit sample approval before full production.

Target the installed Godot **4.7.2** editor. Preserve music, gameplay values,
scene routing, and the autoload names `GameManager`, `Settings`, `MusicManager`,
and `SceneTransition`. Existing art and music remain source/reference material.

## Artwork and Approval

1. Create a small approval set containing the researcher in four facing poses
   and one main-menu composition. Treat their original dimensions as evaluation
   samples; gameplay composition remains deferred.
2. Show native-size and nearest-neighbor integer-enlarged previews. Obtain explicit
   visual approval before generating the full asset set or replacing active art.
3. Preserve the broad hat, obscured face, compact coat, and practical equipment.
   Keep both hands empty in character frames: the physical potion entity supplies
   the held bottle.
4. Use eight neutral grayscale values for ordinary artwork. Keep recognizable
   reagent and potion colors; distinguish Friend, Foe, and status through
   silhouette, labels, and shape rather than color alone.
5. Treat AI output as source material requiring native-grid cleanup. Require
   deliberate pixel clusters, clean alpha, consistent scale, and stable pivots.
   Downsampling the existing painted art alone is not a production workflow.
6. Produce one player sheet, static Friend/Foe sprites, a small reusable
   terrain/prop set, bottle/flask assets, a menu background, and shared interface
   textures. Do not add encounters or expedition environments in this conversion.
7. Preserve existing source art and music. Older references remain historical
   mood/composition references, not the pixel-production specification.

A [pixel-art approval pack](../../pixel_art_samples/README.md) was produced after
this plan was saved. The researcher-facing and main-menu samples were explicitly
approved on 2026-09-12. The gameplay composition draft was removed by user
direction and is not part of the pack; gameplay presentation still requires a
separate decision and approval. Historical approval of G06 is separate from the
new pixel-sample approval.

## Rendering and Animation

### Pixel Grid and World Scale

- Keep the project viewport at **1920 x 1080** with nearest sampling. Author
  full-screen menu artwork at that exact resolution and use responsive Control
  anchors for other window shapes.
- Keep gameplay physics coordinates unchanged. Gameplay camera zoom, pixel/world
  ratio, character cell, and terrain grid require a separate composition decision.
- Preserve camera following. Any later render snapping must not quantize physics
  bodies, projectile positions, or continuous mouse aim.

### Player Presentation

- Keep `characters/player/PlayerModel.tscn` as the shared model boundary for
  combat and workshop, but replace skeletal internals with `Sprite2D` and native
  `AnimationPlayer` tracks.
- Use four authored facing rows and a deliberately small idle/walk frame budget.
  Approve exact sheet/cell dimensions against gameplay composition first.
- Idle loops last **1.6 seconds**; walk loops last **0.72 seconds**.
- Use discrete frames, retaining gait phase during direction changes. Never
  interpolate between frames, stretch limbs, or crossfade two sprite drawings.
- Author `front`, `back`, `side_left`, and `side_right` separately. Preserve the
  existing **0.10** dominant-axis hysteresis, idle-facing retention, and positive
  scale. Do not swap anatomical hands through mirroring.
- Preserve public motion, facing, playback-speed, reset, and socket methods and
  facing/locomotion signals. Animate hand markers per frame so the same held
  `PotionEntity` follows the correct hand.
- Replace workshop bone indicators with frame bounds and socket guides. Add
  `set_debug_guides_visible()` and keep `set_debug_bones_visible()` as a
  compatibility wrapper during migration.
- Do not add drink/throw/place delays or new action animations. Potion use stays
  immediate. An action-animation redesign requires a separate scope.

## Screens and Integration

### Sandbox and Potions

- Use pixel tiles and decorative props for the existing arena while preserving
  actor positions and collisions. Friend and Foe remain stationary test targets.
- Use a grayscale bottle with tinted liquid. Discrete visual orientations may
  represent travel, but aim and flight remain continuous.
- Preserve held, flying, placed, consumed, and discarded behavior. The visual
  conversion must not duplicate instances, add pickup, or change effect delivery.
- Keep the bottom-center mixer compact, with three visible liquid bands, one
  uniform prepared color, and labeled R/G/B swatches. Its dimensions remain open.
- Preserve existing mixer rules and controls. Replace smooth scale feedback
  with pixel-step movement or authored frames; rejected mixes keep their layers.

### Shared Screens

- Apply a coherent pixel theme in stages. The main menu and its inline settings
  are implemented; pause, combat HUD, health bars, and workshop remain separate work.
- Preserve mouse/keyboard focus, buttons, audio sliders, settings storage,
  routing, and pause behavior.
- The active menu now uses scene-authored text commands, stepped inline audio
  controls, and an animated grayscale laboratory with focused RGB reagent light.
  The old shader, painted buttons, and procedural alchemy seal are retired.
- Adapt the ink reveal to the pixel grid while retaining its duration contract,
  input blocking, completion signal, and scene-change behavior.
- Do not implement the separately proposed diegetic journal/candle/settings
  interactions as a side effect of this visual conversion.
- Update technical docs as implementation actually lands. Continue to label
  reactive AI, exploration, inventory, and knowledge progression as future work.

## Stable Contracts

- Mixing remains live, order-independent by reagent count, and limited to three
  layers. The two existing recipes and their effect strengths remain unchanged.
- A recipe is shared definition data; a `PotionInstance` is one produced potion;
  its `PotionEntity` is the physical representation. Keep that ownership split.
- Potion effects remain capability-based and independent of delivery method.
- Keep movement speed, collision shapes, health, projectile behavior, placement
  rules, and current no-AI/no-victory/no-defeat sandbox behavior unchanged.
- Preserve `user://settings.cfg`, audio buses, music crossfades, pause, and scene
  transitions. Do not rename autoloads or registered scene paths.
- Future storage will store potion instances. The single held slot is not a
  permanent one-potion design restriction; storage is not implemented here.

## Delivery Stages

Each stage should be independently reviewable. These boxes track conversion
work, not completion of this documentation update.

### 1. Approve the Visual Sample

- [x] Produce four researcher facings and a main-menu composition.
- [x] Review native-size silhouettes, palette, feet, empty hands, and pixel grid.
- [x] Obtain explicit approval for the retained researcher and main-menu samples.
- [ ] Decide gameplay composition before generating or integrating gameplay art.

### 2. Establish Rendering and Player Animation

- [ ] Configure the base viewport, integer scaling, nearest sampling, and camera.
- [ ] Replace only `PlayerModel` presentation while retaining its gameplay API.
- [ ] Author sprite frames and per-frame hand-marker positions.
- [ ] Adapt the workshop and model-specific tests; verify held-potion alignment.

### 3. Convert the Remaining Screens

- [ ] Restyle the arena, stationary targets, potion entity, flask, and health bars.
- [x] Restyle main menu, inline settings, and version display at native 1920 x 1080.
- [ ] Restyle pause settings and remaining gameplay/workshop screens after their visual targets are approved.
- [ ] Adapt the transition visually without changing its lifecycle behavior.

### 4. Verify and Reconcile Documentation

- [ ] Run the regression and visual checks below.
- [ ] Update current-state docs and reference approvals to match delivered work.
- [ ] Review scope and diff; do not bundle a gameplay rebuild into this change.

## Verification

### Automated and Domain Checks

- Check sheet dimensions, frame tracks, loop durations, phase-preserving turns,
  facing mappings, speed clamping, invalid-input handling, and socket lookup.
- Run all nine existing potion/model test scenes. Replace bone-specific model
  assertions with frame/socket checks, but retain gameplay assertions.
- Verify mixing, drinking, throwing, placing, discarding, zero-HP recovery, and
  aiming with the new displayed camera transform.
- Confirm one physical potion remains one-use across all delivery methods.

### Visual and Interaction Checks

- Inspect gameplay, main menu, settings, pause, and workshop at **1280 x 720**,
  **1920 x 1080**, **2560 x 1440**, and **1366 x 768**.
- Check integer scaling, letterboxing, text/control fit, mouse coordinates, and
  camera motion. No resampled pixels, overlapping UI, or clipped controls.
- Inspect every facing and idle/walk turn with a held potion. Reject hand swaps,
  mirrored anatomy, blended frames, drifting pivots, or scaled collisions.
- Confirm all current buttons, focus navigation, audio settings, music, pause,
  and transition completion behave as before.
- Run the Godot editor import check, workshop/combat/main-scene smoke tests,
  referenced `res://` path validation, and `git diff --check`.

## Documentation Update Validation

Saving this plan and aligning the documentation is separate from executing the
conversion. For this documentation-only change, check Markdown links,
consistency, historical-source labeling, changed-file scope, and
`git diff --check`. Runtime tests and generated pixel samples are not required
and must not be reported as completed by this pass.

## Assumptions and Boundaries

- CombatAlchemy remains a working title and a solo real-time alchemy concept.
- Existing music and documented source art are retained. Superseded menu-only
  shaders, procedural decoration, previews, and painted command textures may be removed.
- Compact full-body frames are the production path, not another skeleton
  experiment, a 3D pipeline, or a live pixelation shader over the old rig.
- Palette discipline and a low frame budget reduce production cost; generated
  art still requires consistency review and cleanup.
- Do not add AI, inventory, pickup, expeditions, multiplayer, progression, or
  action animation during this presentation pass.
- Historical plans remain records. This plan takes precedence over their
  conflicting visual requirements, not over current gameplay contracts.
