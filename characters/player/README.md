# PlayerModel

> Updated: 2026-11-17. Current runtime: Researcher 01 pixel sprite model.
> [Asset package](../../sprites/characters/researcher_01/README.md) |
> [Production standard](../../docs/ASSET_PRODUCTION_TEMPLATE.md) |
> [Archived model](../../deprecated/README.md)

`PlayerModel.tscn` is the shared presentation scene used by CombatScene's PlayerActor
and the model workshop. AnimatedSprite2D plays the eight animations in
`Researcher01Frames.tres`; the exportable `Researcher01Data.tres` supplies the pivot
and per-frame anatomical hand positions. Runtime loading does not depend on JSON.

## Stable public interface

- `set_motion(velocity: Vector2)`: idle/walk and velocity-derived facing.
- `set_facing_direction(direction: Vector2) -> bool`: explicit facing, rejects zero.
- `reset_to_idle()`: front idle at frame zero, preserving playback speed.
- `set_playback_speed(multiplier: float)`: clamp 0.25 through 2.0.
- `get_facing()`, `get_locomotion_state()`: current facing and idle/walk state.
- `get_socket(socket_id: StringName) -> Marker2D`: `hand_left` / `hand_right` or null.
- `set_debug_guides_visible(bool)`: frame bounds, ground pivot and hand crosshairs.
- `set_debug_bones_visible(bool)`: compatibility alias for the guides method.
- Signals `facing_changed` and `locomotion_changed` fire only on actual changes.

## Animation and alignment

Four separately drawn facings: front, back, side_left, side_right. No negative scale,
flipping, blending, bone animation or action delays. Direction selection uses the
previous dominant-axis family with 0.10 hysteresis; stopping retains facing.
Turns preserve the current frame and fractional frame progress. Changing between
idle and walk resets to the first frame of the new cycle. Idle is two frames over
1.6 seconds; walk is four frames over 0.72 seconds.

Source cells are 64 x 80, displayed at 2x. Sprite offset is (-32,-74), centered=false.
`FacingRoot.position.y = 38` preserves the old rig's ground level and alignment with
the existing collision capsule. The camera, movement, collisions, health and aim
coordinates are unchanged.

`HandSocket_L` and `HandSocket_R` are stable siblings of the sprite under FacingRoot,
not children of the scaled sprite. Their positions are `(native_hand - pivot) * 2`.
This prevents held bottles from inheriting the character's 2x display scaling.
Metadata controls hand z-order: rear/occluded hands behind the sprite, visible
hands in front. Frame and animation changes synchronously update both markers.
Consumers use `get_socket()`; no internal node paths are part of the gameplay API.

## Workshop and verification

Run `PlayerModelWorkshop.tscn` with Play Current Scene. It uses this same model,
one movement owner, unchanged room/walls/collision and a following camera. The
`GUIDES` checkbox toggles bounds and hand markers; no production-only rig exists.

`PlayerModelTests` checks sprite resources, every frame/socket, held-bottle scale,
depth, phase preservation, hysteresis, speed clamps and signal/debug compatibility.
Workshop, player actor, potion use and collection tests preserve gameplay coverage.

## Retired files

The old 15-bone scene/script, locomotion AnimationLibrary, two 32x48 prototype
images with their previews/import metadata, old unused mage placeholder and former
bone-specific test script are under `deprecated/`. `.gdignore` excludes that archive
from Godot imports and exports. See its manifest for original and archived paths.
The shared overworld image used by Friend and Pursuer remains an active asset.
