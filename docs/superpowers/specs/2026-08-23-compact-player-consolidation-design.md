# Compact Player Consolidation Design

## Status

Approved design for consolidating the project around one compact directional
player model and switching active combat to it.

## Objective

Replace the active researcher cutout and all superseded character-animation
experiments with one canonical compact 15-bone player model. The same model
must serve as the editable character workshop and as the visual rig instanced
by combat. Potion drinking and throwing remain playable, but execute
immediately until action animations are designed for the compact rig.

## Constraints

- Target Godot version remains 4.7.1.
- Preserve the existing combat scene path and main project flow.
- Preserve camera behavior, player collision, health, movement speed, potion
  recipes, targeting, pause behavior, music, menu, and settings.
- Preserve all user-authored edits currently present in the compact model,
  compact animation library, compact rig scene, and comparison lab while
  consolidating their useful content.
- Do not keep duplicate production and workshop skeletons.
- Do not horizontally mirror the compact rig. Left and right remain separate
  authored directional families so anatomical hands stay stable.
- Do not add drink, throw, hit, IK, root motion, or combat animation in this
  change.
- Keep unrelated sprites, UI art, menu art, and music assets.

## Target Architecture

### Canonical Player Model

`characters/player/PlayerModel.tscn` is the sole editable player-model
workshop and visual rig. It owns:

- The compact 15-bone `Skeleton2D` hierarchy.
- Scene-authored placeholder geometry and future sprite parts.
- Stable `HandSocket_L` and `HandSocket_R` markers.
- Debug bone indicators, hidden by default.
- `AnimationPlayer` and `AnimationTree` nodes.
- The compact directional locomotion controller.
- References to the canonical locomotion animation library.

Opening this scene in the Godot editor is the primary workflow for adjusting
bone positions, sprite pivots, part overlap, and animation tracks. It is a
production scene, not an experiment dependency.

The exact hierarchy remains:

```text
Root
|- Torso
|  |- Head
|  |- UpperArm_L -> Forearm_L -> Hand_L
|  `- UpperArm_R -> Forearm_R -> Hand_R
|- Thigh_L -> Shin_L -> Foot_L
`- Thigh_R -> Shin_R -> Foot_R
```

### Locomotion Resources

`characters/player/PlayerModel.gd` owns the public locomotion API and
direction selection. `characters/player/PlayerLocomotionLibrary.tres` is the
only retained player locomotion library.

The public interface remains:

```gdscript
func set_motion(velocity: Vector2) -> void
func set_facing_direction(direction: Vector2) -> bool
func reset_to_idle() -> void
func set_playback_speed(multiplier: float) -> void
func set_debug_bones_visible(is_visible: bool) -> void
func get_facing() -> StringName
func get_locomotion_state() -> StringName
func get_socket(socket_id: StringName) -> Marker2D
```

Signals remain `facing_changed(facing)` and
`locomotion_changed(state)`. `get_socket()` supports at least `hand_left` and
`hand_right` so gameplay does not depend on internal bone paths.

Retained animation families are:

- `idle_front`, `idle_back`, `idle_side_left`, `idle_side_right`.
- `walk_front`, `walk_back`, `walk_side_left`, `walk_side_right`.
- `RESET` for authored neutral transforms.

Current user-authored animation changes are treated as source material during
the consolidation and must not be overwritten by an older scene copy.

### Gameplay Wrapper

`combat/actors/PlayerActor.tscn` remains the stable gameplay scene path. It is
a thin `CharacterBody2D` wrapper containing:

- `PlayerCombatController`.
- One instance of `characters/player/PlayerModel.tscn`.
- Existing camera behavior.
- Existing gameplay collision.
- `HealthComponent` and `PotionTarget`.
- The existing world-space player health bar.

`combat/CombatScene.tscn` continues to instance `PlayerActor.tscn`. The
temporary `combat/actors/PlayerModel.tscn` wrapper is merged into
`PlayerActor.tscn` and then removed, avoiding two gameplay wrappers.

## Movement Data Flow

`PlayerCombatController` remains responsible for input and world movement. On
each physics frame it:

1. Reads the existing movement actions.
2. Applies normalized velocity at the existing movement speed.
3. Calls `move_and_slide()`.
4. Passes actual post-move velocity to `PlayerModel.set_motion()`.

The player model selects front, back, side-left, or side-right animation from
that velocity. Zero velocity returns to the matching idle state while
retaining the last facing. Direction transitions preserve locomotion phase.
The gameplay controller does not manipulate bones or animation-tree paths.

## Immediate Potion Use

The retired researcher rig supplied `drink_commit` and `throw_release`
animation events. Those events and their adapter are removed.

### Drink

When Right Mouse is pressed with a prepared recipe:

1. Take the prepared recipe from `PotionMixer`.
2. Close and reset the mixer interface using the existing mixer flow.
3. Immediately call `Player`'s `PotionTarget.receive_potion(recipe)`.
4. Report a warning if the target rejects the recipe; do not restore a recipe
   that has already been consumed.

### Throw

When Left Mouse is pressed with a prepared recipe:

1. Validate the projectile scene and projectile parent before consuming the
   recipe.
2. Capture the current mouse aim direction.
3. Resolve `hand_right` through `PlayerModel.get_socket()`.
4. Use the socket global position as the projectile origin. If the socket is
   unavailable, use the existing stable player throw-origin fallback.
5. Take the prepared recipe, close the mixer, instantiate the projectile, and
   launch it immediately.
6. Warn and fail safely if launch validation fails.

Potion input is not movement-locking. Damage does not interrupt locomotion or
own animation state. The old reserved-recipe, pending-action, duplicate-event,
and missing-event handling is deleted because no delayed action remains.

## Workshop

Keep one isolated `PlayerModelWorkshop.tscn` under `characters/player/`. It
instances the canonical model in a neutral room and provides movement input,
a following camera, small facing/locomotion readouts, and a debug-bone toggle.
It exists only for visual adjustment and Play Current Scene verification.

The workshop must not be registered in `project.godot`, referenced by
autoloads, or used by combat. It may contain a thin workshop controller, but
must not duplicate skeleton or animation data.

## Deletion Scope

Delete the following retired pipelines after all consumers are switched:

- `characters/animation/` generic humanoid and researcher scenes, scripts,
  animation libraries, and action-rig resources.
- `experiments/character_animation/` and its lab.
- `experiments/directional_character_animation/` original 26-bone rig and
  lab.
- Superseded compact comparison files and duplicate compact rig scene after
  their approved user changes have been consolidated into the canonical
  player model and workshop.
- `combat/actors/PlayerAnimationController.gd`.
- The held-flask scene used only by delayed action animation.
- The temporary `combat/actors/PlayerModel.tscn` wrapper.
- Tests dedicated only to deleted rigs, mirroring behavior, delayed action
  timing, or the deleted comparison lab.
- Researcher cutout PNG atlases and their `.import` sidecars.
- Generated development reference images that are not referenced by retained
  Markdown documentation.

Preserve reference images embedded or linked by retained project, style, or
art-reference Markdown. Historical source images and generated plates that
remain documented must stay at their documented paths. Do not broadly delete
unrelated gameplay sprites or menu assets merely because they are currently
unused.

## Documentation

Update `docs/PROJECT_ARCHITECTURE.md` to describe only the canonical compact
player pipeline, active combat integration, immediate potion flow, and single
workshop.

Update the player workshop README with:

- Exact bone names and hierarchy.
- Scene ownership and stable public API.
- How to replace placeholders with sprite parts.
- Pivot and overlap guidance.
- Directional animation-family rules.
- Play Current Scene verification steps.

Update `docs/STYLE_AND_VISION.md`, `docs/ART_REFERENCE_INDEX.md`, and retained
asset READMEs only where they reference deleted researcher atlases, scenes, or
images. Old systems may be mentioned as explicit historical exclusions, but
must not be described as active architecture.

## Testing

### Automated Tests

Replace obsolete animation tests with focused coverage for:

- Exact compact 15-bone hierarchy and stored rest poses.
- Required idle/walk clips and four authored facings.
- No negative `FacingRoot.scale.x` mirroring.
- Movement-to-facing mapping, diagonal hysteresis, and idle retention.
- Playback-speed clamping and debug-bone visibility.
- Stable `hand_left` and `hand_right` socket lookup.
- Active `PlayerActor.tscn` instancing the canonical model.
- `PlayerCombatController` forwarding actual movement to the model.
- Immediate drink applying exactly once.
- Immediate throw launching exactly once from the right-hand socket or
  documented fallback.
- Prepared recipe and mixer state clearing after use.
- Existing potion-domain and projectile-collision behavior.

### Static Validation

- Run `git diff --check`.
- Validate every `res://` path in retained scenes and resources.
- Confirm no `.gd`, `.tscn`, `.tres`, or retained Markdown references point to
  deleted rig scenes, animation classes, atlas files, labs, or tests.
- Confirm `project.godot` does not reference the workshop or retired
  experiments.
- Confirm documentation-referenced image paths exist.

### Manual Godot Verification

1. Open `PlayerModel.tscn`; adjustability of bones, visuals, sockets, and
   animation nodes is visible in the editor.
2. Run `PlayerModelWorkshop.tscn`; verify eight movement directions, separate
   left/right anatomy, idle recovery, and debug-bone toggle.
3. Start New Game; verify active combat uses the compact model.
4. Verify movement, camera following, collisions, and health bar.
5. Prepare and drink both recipe types; verify immediate self-application.
6. Prepare and throw both recipe types at Friend and Foe; verify immediate
   projectile spawn from the right-hand socket and correct effects.
7. Throw into empty space; verify projectile expiry.
8. Open pause and settings; verify both still work.
9. Resize to a smaller 16:9 window and verify gameplay remains usable.

## Acceptance Criteria

- There is one canonical compact player model and one locomotion library.
- Active combat uses that model through `PlayerActor.tscn`.
- No active code depends on the retired researcher or 26-bone rigs.
- Left and right directional animation preserve anatomical hands without
  mirroring the root.
- Potion drinking and throwing remain fully playable through immediate use.
- The right-hand socket is the preferred projectile origin with a safe
  fallback.
- Researcher atlases and unreferenced development images are removed.
- Documentation accurately describes the retained architecture and references
  only files that exist.
- Automated, static, and manual verification complete without new Godot
  errors.
