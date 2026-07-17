# Character Animation Lab

This folder is an isolated Godot-native cutout animation experiment. Run
`CharacterAnimationLab.tscn` with **Play Current Scene**. Nothing here is registered in
`project.godot` or connected to combat.

## Files

- `HumanoidCutoutRig.tscn`: reusable `Skeleton2D`, rigid placeholder body parts, hand sockets,
  debug lines, `AnimationPlayer`, and `AnimationTree`.
- `HumanoidAnimationLibrary.tres`: reusable animation clips. It can be assigned to another
  humanoid rig when that rig preserves the same bone names and node paths.
- `HumanoidCutoutRig.gd`: small public playback API and animation-event relay.
- `CharacterAnimationLab.tscn`: developer stage and scene-authored playback controls.
- `CharacterAnimationLab.gd`: forwards toolbar input to the rig API.

## Required Hierarchy

The animation tracks depend on these exact names and paths:

```text
HumanoidCutoutRig
`- FacingRoot
   `- Skeleton2D
	  `- Root
		 |- Spine
		 |  |- Head
		 |  |- UpperArm_L
		 |  |  `- Forearm_L
		 |  |     `- Hand_L
		 |  |        `- HandSocket_L
		 |  `- UpperArm_R
		 |     `- Forearm_R
		 |        `- Hand_R
		 |           `- HandSocket_R
		 |- Thigh_L
		 |  `- Shin_L
		 |     `- Foot_L
		 `- Thigh_R
			`- Shin_R
			   `- Foot_R
```

Do not rename or reparent these nodes when reusing `HumanoidAnimationLibrary.tres`. Visual
children beneath a bone may be replaced or renamed without breaking animation tracks.

## Rest Pose

The reusable rig uses a mild A-pose. Each `Bone2D.rest` is its local neutral transform.

To revise the pose:

1. Stop `AnimationTree` preview playback.
2. Move and rotate the bones into the new neutral pose.
3. Use the Skeleton2D editor command that writes the current bone transforms as the rest pose,
   or set each affected bone's `rest` property to its current local transform.
4. Update the `RESET` clip to the same values.
5. Recheck every clip, especially hand-to-face contact and foot placement.

The `RESET` clip and the bone rest transforms must agree. A mismatch causes unexpected blending
when switching clips or replacing visual parts.

## Replacing Placeholder Parts

The `Polygon2D` nodes are rigid cutout placeholders. Replace a placeholder with a transparent
`Sprite2D` under the same `Bone2D`; do not move the bone just to compensate for artwork alignment.

- Put the sprite origin at the joint controlled by its parent bone.
- Place upper-arm pivots at shoulders, forearm pivots at elbows, hand pivots at wrists, thigh
  pivots at hips, shin pivots at knees, and foot pivots at ankles.
- Include hidden overlap around shoulders, elbows, knees, wrists, and coat seams. A practical first
  pass is 6-12 pixels at prototype scale, then adjust for the final texture resolution.
- Keep transparent padding consistent across a character set so swapping parts does not shift the
  silhouette.
- Use `z_index` to keep rear limbs behind the torso and front limbs in front.
- Attach held props to `HandSocket_L` or `HandSocket_R`, not directly to an arm sprite.

A flattened character image cannot reveal hidden joints. Production cutout characters need one
transparent image per articulated part.

## Orientation Limits

`FacingRoot` provides horizontal mirroring for one front/three-quarter visual set. It does not
create a back view. Back-facing characters require a separate set of body-part artwork and usually
a visual-set switch while keeping the same logical skeleton.

Non-humanoid characters should receive their own skeleton hierarchy and animation library. Do not
force incompatible proportions, extra limbs, wings, or tails into this humanoid path contract.

## Playback Contract

Available states are `RESET`, `idle`, `walk`, `drink`, `throw`, and `hit`. Locomotion clips remain
in place; a future gameplay controller should move the character root in world space.

One-shot method-track events are:

- `drink_commit` at 0.55 seconds.
- `throw_release` at 0.45 seconds.
- `hit_peak` at 0.18 seconds.

The lab displays the most recent event. Future gameplay may connect to the rig's
`animation_event(event_name)` signal, but this experiment intentionally has no gameplay wiring.

## Adding Or Editing Clips

Edit `HumanoidAnimationLibrary.tres` through the `AnimationPlayer` panel on an instance of the rig.
Keep movement in place and preserve the `RESET` values for every property animated by other clips.
Use the `AnimationTree` graph for transition timing; do not encode gameplay movement or damage in
animation tracks.
