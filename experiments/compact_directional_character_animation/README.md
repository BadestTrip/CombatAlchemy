# Balanced Compact Directional Rig V2

This isolated Godot 4.7 experiment compares a compact arcade character against
the original high-detail directional rig. It is not referenced by combat,
autoloads, `project.godot`, or the active Player.

Run `DirectionalRigComparisonLab.tscn` with **Play Current Scene**. WASD and the
arrow keys move both displayed rigs through the same bounded room at 220 pixels
per second.

## Files

- `CompactDirectionalHumanoidRig.tscn`: editable 15-bone geometric rig,
  sockets, hidden bone overlay, `AnimationPlayer`, and `AnimationTree`.
- `CompactDirectionalHumanoidAnimationLibrary.tres`: four authored idle clips
  and four authored nine-key walk clips.
- `CompactDirectionalHumanoidRig.gd`: public locomotion API, dominant-axis
  direction selection, hysteresis, locomotion blending, and validation.
- `CompactDirectionalComparisonMover.gd`: owns world movement and sends the
  same velocity to both rigs.
- `DirectionalRigComparisonLab.tscn`: side-by-side room, two collision shapes,
  fixed camera, labels, and a minimal shared-state HUD.

The original experiment remains under
`experiments/directional_character_animation/` for direct comparison.

## Bone Contract

Animation tracks depend on this exact 15-bone hierarchy:

```text
Root
|- Torso
|  |- Head
|  |- UpperArm_L
|  |  `- Forearm_L
|  |     `- Hand_L
|  `- UpperArm_R
|     `- Forearm_R
|        `- Hand_R
|- Thigh_L
|  `- Shin_L
|     `- Foot_L
`- Thigh_R
   `- Shin_R
      `- Foot_R
```

`HandSocket_L` and `HandSocket_R` are `Marker2D` children of their matching
hand bones. Every `Bone2D` stores its neutral local transform in `rest`.
Renaming or reparenting a bone requires migrating every animation track.

## Compact Proportions

The neutral body geometry is exactly 100 by 116 pixels, excluding hidden debug
lines. `Root` sits on the pelvis line; visible geometry reaches approximately
78 pixels above it and 38 pixels below it.

- Head: 58 by 46 pixels.
- Torso: 62 by 42 pixels.
- Shoulder span: 62 pixels.
- Upper arm, forearm, hand: 24, 20, and 8 pixels.
- Hip span: 28 pixels.
- Thigh, shin, foot: 20, 17, and 12 pixels.

The colored left and right limbs make anatomical handedness visible during
testing. The reusable scene never negates `FacingRoot.scale.x`.

## Animation Model

The external library contains:

- `RESET`: 0.1-second neutral front pose.
- `idle_front`, `idle_back`, `idle_side_left`, `idle_side_right`: 1.6-second
  loops with five subtle breathing keys.
- `walk_front`, `walk_back`, `walk_side_left`, `walk_side_right`: 0.72-second
  loops with a shared nine-key gait.

Every walk uses the same timeline:

| Time | Phase |
| ---: | --- |
| 0.00 | Left contact |
| 0.09 | Left down |
| 0.18 | Left passing |
| 0.27 | Left up |
| 0.36 | Right contact |
| 0.45 | Right down |
| 0.54 | Right passing |
| 0.63 | Right up |
| 0.72 | Repeated left contact |

The walk includes a two-pixel body bob, alternating thigh and arm swing, knee
bend, foot roll, restrained torso counter-rotation, and head stabilization.
Thigh-position compensation keeps each contact foot planted through its down
phase. Idle counter-moves the leg roots so breathing does not slide the feet.

`AnimationTree` contains separate idle and walk
`AnimationNodeStateMachine` nodes. Each has front, back, side-left, and
side-right states. All direction transitions use synchronized playback,
`reset = false`, and a 0.10-second crossfade. `AnimationNodeBlend2` blends idle
and walk over 0.12 seconds before `AnimationNodeTimeScale` applies speed.

## Direction Rules

- Down selects `front`.
- Up selects `back`.
- Left selects the authored `side_left` clips.
- Right selects the authored `side_right` clips.
- An axis must exceed the other normalized axis by 0.10 to change family.
- Near-equal diagonals retain the current side or vertical family.
- An initial diagonal uses its vertical sign.
- Zero motion returns to idle without changing facing.

Separate side clips preserve logical left and right hands. Do not add horizontal
root mirroring to this rig.

## Public API

```gdscript
set_motion(velocity: Vector2) -> void
set_facing_direction(direction: Vector2) -> bool
reset_to_idle() -> void
set_playback_speed(multiplier: float) -> void
set_debug_bones_visible(is_visible: bool) -> void
get_facing() -> StringName
get_locomotion_state() -> StringName
```

Signals:

```gdscript
facing_changed(facing: StringName)
locomotion_changed(state: StringName)
```

Playback speed clamps to 0.25-2.0. Explicit near-zero facing requests return
`false`. Missing clips, state-machine states, or required nodes disable playback
and report the missing dependency.

## Replacing Geometry

Each rigid `Polygon2D` is authored beneath its controlling bone and can be
replaced by a transparent `Sprite2D` part. Production artwork needs four
coherent views: front, back, left side, and right side. Keep joint pivots at
local zero, preserve overlap at articulated seams, and retain all tracked node
paths.

Promote this rig only after the compact silhouette and four-facing movement are
approved in the lab. A production adapter can then replace the active Player's
visual rig without moving locomotion input or world translation into this
animation facade.

## Manual Verification

1. Play `DirectionalRigComparisonLab.tscn` as the current scene.
2. Move in all eight directions and confirm both rigs receive identical motion.
3. Confirm front, back, left, and right use distinct compact clips.
4. Reverse left/right repeatedly and confirm the colored hands never swap.
5. Watch a complete walk loop and confirm contact, down, passing, and up poses
   alternate cleanly without a hitch at 0.72 seconds.
6. Stop in every facing and confirm subtle idle motion keeps both feet planted.
7. Walk against each room edge and confirm both collision shapes stay inside.
8. Resize to a smaller 16:9 window and confirm labels and HUD remain readable.

Automated coverage is in
`tests/CompactDirectionalAnimationRigTests.tscn`.
