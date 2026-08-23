# PlayerModel

`PlayerModel.tscn` is the production-facing compact player visual. It owns presentation state only: callers provide world velocity through `set_motion()`, read facing and locomotion state through the getters or signals, resolve stable sockets through `get_socket()`, and opt into bone indicators through `set_debug_bones_visible()`.

`PlayerModelWorkshop.tscn` is an isolated Play Current Scene workshop. Its `WorkshopActor` owns movement, collision, and the camera; the instanced `PlayerModel` remains presentation-only. The workshop is not registered in `project.godot` and must not become a gameplay dependency.

## Bone Tree

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

## Facing Clips

The four authored facings are `front`, `back`, `side_left`, and `side_right`. Each has an idle and walk clip:

- `idle_front`, `idle_back`, `idle_side_left`, `idle_side_right`
- `walk_front`, `walk_back`, `walk_side_left`, `walk_side_right`

Left and right are separately authored. Do not mirror `FacingRoot` or any sprite replacement with negative scale.

## Replacing Geometry

Replace each body-part `Polygon2D` with a sprite part under the same `Bone2D`. Preserve the existing bone hierarchy, rest transforms, and socket markers. Author every sprite pivot at local joint zero so animation continues to rotate around the intended anatomical joint.

Build deliberate overlap into the art at both shoulders, elbows, wrists, hips, knees, and ankles. The overlap must cover the full authored motion range without exposing gaps while keeping each part visually attached to its parent.

## Workshop Checks

Play `PlayerModelWorkshop.tscn` with Play Current Scene. Bone indicators must start off and respond only to the `BONES` CheckButton. Exercise all eight movement directions with the existing movement inputs:

- up, down, left, and right
- up-left, up-right, down-left, and down-right

Verify that the actor stays inside all four walls, the camera follows without smoothing, idle resumes when movement stops, and each diagonal consistently selects the expected authored facing without mirroring.
