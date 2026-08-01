# Directional Geometric Locomotion Lab

This isolated Godot 4.7 experiment tests a low-cost arcade character pipeline:
eight-direction movement represented by front, back, and horizontally mirrored
side animation families. Run `DirectionalAnimationLab.tscn` with **Play Current
Scene**.

The experiment is not referenced by `project.godot`, combat, the active Player,
or the existing researcher animation lab.

## Files

- `DirectionalHumanoidRig.tscn`: editable geometric body, `Skeleton2D`,
  `AnimationPlayer`, and `AnimationTree`.
- `DirectionalHumanoidAnimationLibrary.tres`: authored FK idle and walk clips.
- `DirectionalHumanoidRig.gd`: direction selection, blending, mirroring, and
  the reusable public API.
- `DirectionalLabActor.tscn`: movement body, collision, rig instance, and
  following camera.
- `DirectionalAnimationLab.tscn`: bounded developer room and state readouts.

## Bone Contract

The animation tracks depend on these names and parent relationships:

```text
Root
└─ Pelvis
   ├─ SpineLower
   │  └─ Chest
   │     ├─ Neck
   │     │  └─ Head
   │     ├─ Clavicle_L
   │     │  └─ UpperArm_L
   │     │     └─ Forearm_L
   │     │        └─ Wrist_L
   │     │           └─ Hand_L
   │     └─ Clavicle_R
   │        └─ UpperArm_R
   │           └─ Forearm_R
   │              └─ Wrist_R
   │                 └─ Hand_R
   ├─ Thigh_L
   │  └─ Shin_L
   │     └─ Ankle_L
   │        └─ Foot_L
   │           └─ Toe_L
   └─ Thigh_R
      └─ Shin_R
         └─ Ankle_R
            └─ Foot_R
               └─ Toe_R
```

Do not rename or reparent these bones without migrating every animation track.
Each `Bone2D` stores its authored local transform as its rest pose.

## Animation Model

The library contains:

- `RESET`: `0.1` second neutral front pose.
- `idle_front`, `idle_back`, `idle_side`: `1.6` second loops.
- `walk_front`, `walk_back`, `walk_side`: `0.72` second loops.

Walk clips share contact keys at `0.0`, `0.18`, `0.36`, `0.54`, and `0.72`
seconds. Their common duration lets `AnimationNodeBlendSpace1D` use cyclic
constant synchronization, preserving the footstep phase while direction
changes. Direction blends take `0.10` seconds. The idle/walk blend takes
`0.12` seconds.

All movement is authored forward kinematics. World movement belongs to the
`CharacterBody2D`; the rig has no root motion, inverse kinematics, combat
actions, or gameplay rules.

## Direction Rules

- Down selects `front`.
- Up selects `back`.
- Horizontal movement selects `side_right` or mirrored `side_left`.
- Near-equal diagonals retain the current horizontal or vertical family.
- A first diagonal chooses front or back from its vertical sign.
- Zero motion changes walk to idle but preserves facing.

The normalized-axis hysteresis is `0.10`, which prevents analog input near a
diagonal boundary from repeatedly switching animation families.

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

`set_motion()` is sufficient for movement-facing characters.
`set_facing_direction()` lets future gameplay provide an aim direction after
updating locomotion. A near-zero explicit direction is rejected.

## Replacing Geometry

The polygons are rigid placeholders attached directly beneath their controlling
bones. A future skin should inherit the rig, keep the bone hierarchy, and
replace those polygons with transparent `Sprite2D` or `Polygon2D` parts.

Production artwork needs three coherent visual sets:

1. Front.
2. Back.
3. Right-facing side, mirrored for left.

Keep pivots at their controlling joints and overlap artwork around shoulders,
elbows, wrists, hips, knees, ankles, and toes. Direction-specific artwork may
add a skin adapter that swaps visual children, but movement code should
continue using the same rig API.

Bone indicators are development aids only. They start hidden and are controlled
through the Inspector or `set_debug_bones_visible()`.

## Manual Verification

1. Play `DirectionalAnimationLab.tscn`.
2. Move with WASD or arrow keys in all eight directions.
3. Alternate rapidly between front, back, and side movement.
4. Confirm turns blend without restarting the current step.
5. Stop and confirm the character returns to idle without changing facing.
6. Walk to every wall and confirm the actor and camera remain inside the room.
7. Resize to a smaller 16:9 window and confirm the status readout remains
   visible.

Automated coverage is in `tests/DirectionalAnimationRigTests.tscn`.
