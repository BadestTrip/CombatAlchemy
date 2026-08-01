# Character Animation Lab

This folder contains the isolated developer lab for the Godot-native cutout
animation system. Run `CharacterAnimationLab.tscn` with **Play Current Scene**.
The lab is not registered in `project.godot`; it exercises the same production
rig used by the combat Player without invoking gameplay.

## Files

- `../../characters/animation/HumanoidCutoutRig.tscn`: reusable `Skeleton2D`, rigid placeholder
  body parts, hand sockets, debug lines, `AnimationPlayer`, and `AnimationTree`.
- `../../characters/animation/ResearcherCutoutRig.tscn`: inherited production
  skin that hides the placeholders and assembles the researcher from
  atlas-backed `Sprite2D` parts.
- `../../characters/animation/HumanoidAnimationLibrary.tres`: reusable animation clips. It can
  be assigned to another humanoid rig when that rig preserves the same bone names and node paths.
- `../../characters/animation/HumanoidCutoutRig.gd`: public playback, socket lookup, and
  animation-event relay.
- `../../sprites/characters/researcher/README.md`: researcher prompts, atlas
  regions, scales, pivots, visual layers, and replacement checks.
- `CharacterAnimationLab.tscn`: developer stage and scene-authored playback controls.
- `CharacterAnimationLab.gd`: forwards toolbar input to the rig API.

Related gameplay consumers:

- `../../combat/actors/PlayerAnimationController.gd`: maps actual Player
  movement, potion actions, and damage to the rig API.
- `../../combat/actors/HeldPotionFlask.tscn`: scene-backed prop instanced under
  `HandSocket_R` by the Player adapter.

## Required Hierarchy

The animation tracks depend on these exact names and paths:

```text
HumanoidCutoutRig
`- FacingRoot
   `- Skeleton2D
	  `- Root
		 |- CoatTail_L
		 |- CoatTail_C
		 |- CoatTail_R
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

Do not rename or reparent these nodes when reusing
`HumanoidAnimationLibrary.tres`. `CoatTail_L`, `CoatTail_C`, and
`CoatTail_R` are tracked bones, not researcher-only decoration. Visual
children beneath a bone may be replaced or renamed without breaking animation
tracks.

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

The generic rig's `Polygon2D` nodes are rigid cutout placeholders.
`ResearcherCutoutRig.tscn` demonstrates the preferred replacement pattern: an
inherited skin hides each placeholder and adds a transparent `Sprite2D` under
the same `Bone2D`.

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

Use nonnegative layers so opaque arena or lab backgrounds cannot hide rear
limbs:

| Layer | Content |
| ---: | --- |
| 0 | Rear coat panels |
| 1 | Rear limbs |
| 2 | Pelvis and torso |
| 3 | Front limbs |
| 4 | Head and hat |
| 5 | Equipment and satchel |
| 12 | Held flask |
| 20 | Debug bones |

The researcher skin keeps its sprite nodes at each bone origin and uses
`Sprite2D.offset` plus documented source-pixel pivots. Check the pivot before
moving a bone. A skin may make a small, documented proportion adjustment, such
as the researcher's shoulder spacing, but the generic skeleton and tracked
paths should remain stable.

## Orientation Limits

`FacingRoot` provides horizontal mirroring for one front/three-quarter visual set. It does not
create a back view. Back-facing characters require a separate set of body-part artwork and usually
a visual-set switch while keeping the same logical skeleton.

Non-humanoid characters should receive their own skeleton hierarchy and animation library. Do not
force incompatible proportions, extra limbs, wings, or tails into this humanoid path contract.

## Playback Contract

Available states are `RESET`, `idle`, `walk`, `drink`, `throw`, and `hit`. Locomotion clips remain
in place. In the active combat scene, `PlayerCombatController` moves the
character root in world space and emits its applied velocity;
`PlayerAnimationController` uses that signal to choose `idle` or `walk` without
restarting the current clip every physics frame.

One-shot method-track events are:

- `drink_commit` at 0.55 seconds.
- `throw_release` at 0.45 seconds.
- `hit_peak` at 0.18 seconds.

The lab displays the most recent event. In combat, `PlayerAnimationController`
connects to these events and keeps gameplay rules outside the rig. The lab itself
has no gameplay wiring.

These method events are public timing boundaries, not decorative callbacks.
`PotionCombatController` reserves a prepared recipe when an action starts, then
applies or spawns it only at the matching event. Do not rename, remove, or move
an event without updating the adapter, combat controller, architecture guide,
and timing tests together.

Damage can transition directly from `drink` or `throw` to `hit`. Damage before
the matching event destroys the reserved potion; damage after it cannot undo
the committed effect. Every one-shot reports completion so movement and input
can recover. Missing events deliberately warn, discard the recipe, and hide the
held flask rather than leaving combat locked.

Every clip also contains deterministic coat-tail rotation tracks:

- `idle`: at most 1.5 degrees of opposing motion;
- `walk`: up to 5 degrees on the side panels and 2 degrees at center;
- `drink`: at most 2 degrees of restrained lag;
- `throw`: 5-7 degrees of windup and 8-10 degrees of release lag;
- `hit`: up to 10 degrees of recoil, returning to rest by the clip end.

These tracks are authored motion, not cloth physics.

## Adding Or Editing Clips

Edit `res://characters/animation/HumanoidAnimationLibrary.tres` through the
`AnimationPlayer` panel on an instance of the rig.
Keep movement in place and preserve the `RESET` values for every property animated by other clips.
Use the `AnimationTree` graph for transition timing; do not encode gameplay movement or damage in
animation tracks.

After changing bones, sockets, clips, transitions, or method-event timing, run:

- `tests/CharacterAnimationRigTests.tscn`
- `tests/PlayerAnimationControllerTests.tscn`
- `tests/PotionActionTimingTests.tscn`

The first protects the generic rig, coat contract, researcher atlas skin, and
lab. The second protects Player-facing
movement, mirroring, prop, and interruption behavior. The third protects the
actual recipe commit and projectile-release boundaries in `CombatScene`.
