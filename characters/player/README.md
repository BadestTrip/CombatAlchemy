# PlayerModel

> Reviewed: 2026-09-12. Current runtime: compact 15-bone geometric model.
> Approved replacement: full-body pixel sprite sheets, not implemented yet.
> [Architecture](../../docs/PROJECT_ARCHITECTURE.md) |
> [Style and Vision](../../docs/STYLE_AND_VISION.md) |
> [Pixel-Art Conversion Plan](../../docs/superpowers/plans/2026-09-12-pixel-art-conversion.md)

`PlayerModel.tscn` is the shared player presentation scene used by combat and the
workshop. It does not own gameplay: callers supply world velocity, read facing
and locomotion state, and resolve stable hand sockets. The current physical
potion attaches to `hand_right` and follows that animated marker.

`PlayerModelWorkshop.tscn` is an isolated Play Current Scene workshop. Its
`WorkshopActor` owns movement, collision, and camera; the model remains
presentation-only. The workshop is not registered in `project.godot` and must
not become a gameplay dependency. It will continue to use the same model after
the approved visual conversion, not a second experimental rig.

## Stable Public Interface

| Current method or signal | Responsibility |
| --- | --- |
| `set_motion(velocity: Vector2)` | Select locomotion and facing from actual movement. |
| `set_facing_direction(direction: Vector2) -> bool` | Request facing; reject near-zero direction without changing it. |
| `reset_to_idle()` | Restore the model's idle state. |
| `set_playback_speed(multiplier: float)` | Clamp playback to 0.25-2.0. |
| `set_debug_bones_visible(is_visible: bool)` | Toggle the current bone overlay. |
| `get_facing() -> StringName` | Return front, back, side_left, or side_right. |
| `get_locomotion_state() -> StringName` | Return idle or walk. |
| `get_socket(socket_id: StringName) -> Marker2D` | Resolve hand_left or hand_right without exposing bone paths. |
| `facing_changed(facing: StringName)` | Report an actual facing change. |
| `locomotion_changed(state: StringName)` | Report an actual idle/walk change. |

The conversion preserves these interfaces. It plans a new
`set_debug_guides_visible()` method, with `set_debug_bones_visible()` retained as
a compatibility wrapper. The new guide method does not exist yet.

## Current Bone Tree

The authored skeleton contains exactly 15 bones:

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

The stable socket IDs are:

- `hand_left` -> `Hand_L/HandSocket_L`
- `hand_right` -> `Hand_R/HandSocket_R`

Consumers must resolve sockets with `get_socket()` rather than depending on the internal node paths.

## Current Facing Clips

The four authored facings are `front`, `back`, `side_left`, and `side_right`. Each has an idle and walk clip:

- `idle_front`, `idle_back`, `idle_side_left`, `idle_side_right`
- `walk_front`, `walk_back`, `walk_side_left`, `walk_side_right`

Left and right are separately authored. Do not mirror `FacingRoot` or any sprite replacement with negative scale.

The current clips live in `PlayerLocomotionLibrary.tres` and are driven by the
scene's `AnimationPlayer` and `AnimationTree`. Direction uses dominant-axis
selection with 0.10 hysteresis. Zero motion retains facing. Potion drinking,
throwing, and placing are immediate; the model has no action-timing clips.

## Current-Rig Maintenance Only

Until conversion, bone/rest paths remain current test dependencies. A temporary
body-part replacement must keep its pivot at the controlling joint and overlap
shoulders, elbows, wrists, hips, knees, and ankles through the motion range.
This explains how to maintain the existing rig; it is **not** the new art
production brief. Do not commission more articulated cutout atlases for the
approved pixel direction.

## Planned Pixel-Sheet Workflow

1. Approve four neutral researcher facings at native size and integer enlargement,
   together with gameplay and main-menu compositions. Old G06 approval is not
   approval of these new pixel samples.
2. Clean art to **32 x 40** cells using the agreed eight-value grayscale ramp.
   Keep the broad hat, obscured face, compact coat, equipment silhouette, and
   both hands empty. The live potion entity provides the bottle.
3. Produce a **192 x 160** full-body sheet with four rows and six cells per row.
   Use front, back, side-left, side-right rows; each has two idle frames followed
   by four alternating contact/passing walk frames. Keep the feet at one stable
   per-cell pivot and preserve anatomical left/right through all rows.
4. Replace model internals with `Sprite2D` and native `AnimationPlayer` tracks.
   Idle is 1.6 seconds; walk is 0.72 seconds. Select discrete frames, preserve
   gait phase on turns, and do not mirror, interpolate, or stretch drawings.
5. Author left/right hand marker positions per frame. Continue resolving them
   through `get_socket()`. The same `PotionEntity` must follow the correct hand
   without duplicating a bottle in the art.
6. Convert the workshop's bone overlay into frame bounds/socket guides and
   update structure-specific tests. Retain the same movement room and public
   motion/facing contract.

Rendering uses the planned 640 x 360 viewport, nearest integer scaling, 3 world
units per source pixel, and camera zoom 1/3. Keep world movement and collisions
unchanged and align sprite feet with the existing ground position. The active
camera/viewport configuration has not yet been converted.

No action clips, delays, bone animation, IK, or new gameplay mechanics belong to
this sheet pass. Approve readable native-scale animation before adding frames.

## Current Workshop Checks

Play `PlayerModelWorkshop.tscn` with Play Current Scene. Bone indicators start
off and respond to the `BONES` CheckButton. Exercise all eight movement directions:

- up, down, left, and right
- up-left, up-right, down-left, and down-right

Verify that the actor stays inside all four walls, the camera follows without
smoothing, idle resumes on stopping, and each diagonal selects the expected
authored facing without mirroring. These describe the current skeletal lab.

## Conversion Acceptance Checks

These checks are planned, not reported as passed by this documentation update:

- Native and enlarged frames use one pixel grid, clean alpha, and stable feet.
- Idle/walk turns retain phase, side changes never mirror, and speed clamps hold.
- Frame/socket guides toggle; hand-left/right IDs remain stable.
- The held bottle tracks every facing/frame in combat, with immediate potion use.
- Movement speed, body collision, camera following, and target health are unchanged.
- Gameplay and workshop fit 1280 x 720, 1920 x 1080, 2560 x 1440, and 1366 x 768
  windows with integer scaling and letterboxing rather than resampled pixels.
- Run model, workshop, actor, and all potion suites listed in the architecture
  guide. Replace bone-only assertions, not gameplay safety checks.
