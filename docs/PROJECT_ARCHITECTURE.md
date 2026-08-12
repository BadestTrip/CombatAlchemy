# Project Architecture

> Status: Technical source of truth
> Last verified: 2026-08-09
> Creative companion: [Style and Vision](./STYLE_AND_VISION.md)
> Animation production guide:
> [Character Animation Lab](../experiments/character_animation/README.md)
> Directional locomotion experiment:
> [Directional Geometric Locomotion Lab](../experiments/directional_character_animation/README.md)
> Compact directional V2:
> [Balanced Compact Directional Rig V2](../experiments/compact_directional_character_animation/README.md)

## Project Scope

This is a Godot 4.x GDScript prototype. The active game is a real-time potion
combat sandbox reached from the main menu. There is no exploration layer,
enemy AI, victory state, defeat state, permanent save data, or automatic
combat-completion return flow in the current slice. The Pause Menu can still
route directly back to the Main Menu.

The code favors small scene-local components. The only autoloads are retained
application-shell services: scene routing, settings, music, and transitions.
Potion recipes, health, input translation, UI rendering, and projectile motion
remain independent of those autoloads.

The Player uses `ResearcherCutoutRig.tscn`, an inherited atlas-backed skin over
the reusable skeletal contract under `characters/animation/`. A
developer-facing animation lab remains under
`experiments/character_animation/`; the lab is not registered in
`project.godot`, but it exercises the same researcher skin, generic rig API,
and animation library used by `PlayerActor`.

## Runtime Flow

```text
project.godot
  -> mainmenu/StartMenu.tscn
	  -> MainMenu: New Game
		  -> GameManager.start_new_game()
			  -> SceneTransition.transition_to_scene()
				  -> combat/CombatScene.tscn

Combat input
  -> PotionInput signals
	  -> PotionCombatController
		  -> PotionMixer
		  -> PotionMixerUI
		  -> PlayerAnimationController
			  -> ResearcherCutoutRig / HumanoidCutoutRig animation event
				  -> Player PotionTarget, or PotionProjectile
			  -> PotionTarget
				  -> HealthComponent
					  -> ActorHealthBar
```

Escape opens the reusable `ui/PauseMenu.tscn`. Main Menu routes through
`GameManager`; Quit routes through `GameManager.quit_game()`.

The character animation lab has a separate developer-only flow:

```text
Play Current Scene: CharacterAnimationLab.tscn
  -> CharacterAnimationLab toolbar
	  -> ResearcherCutoutRig inherited playback API
		  -> AnimationTree
			  -> StateMachine
				  -> AnimationPlayer
					  -> HumanoidAnimationLibrary.tres
```

The directional locomotion experiment has another isolated flow:

```text
Play Current Scene: DirectionalAnimationLab.tscn
  -> DirectionalLabActor movement
	  -> DirectionalHumanoidRig.set_motion()
		  -> idle/walk locomotion blend
			  -> front/back/side synchronized blend spaces
				  -> DirectionalHumanoidAnimationLibrary.tres
```

The compact V2 experiment compares both directional contracts without entering
active scene flow:

```text
Play Current Scene: DirectionalRigComparisonLab.tscn
  -> ComparisonMover normalized world movement
      -> Original 26-bone rig at x = -140
      -> Compact 15-bone rig at x = 140
          -> synchronized idle/walk facing state machines
              -> CompactDirectionalHumanoidAnimationLibrary.tres
```

## Autoloads

The names below are public project interfaces and should not be renamed without
an explicit migration.

### GameManager

- File: `globals/GameManager.gd`
- Responsibility: route between the registered main-menu and combat scenes.
- Dependencies: `SceneRegistryData`; optional `/root/SceneTransition` autoload.
- Exports: scene registry and transition enable/disable setting.
- Public functions: `start_new_game()`, `go_to_main_menu()`, `quit_game()`.
- Internal functions: validate/load the registry, resolve scenes, and perform a
  direct or transitioned scene change.

### Settings

- File: `globals/Settings.gd`
- Responsibility: own persisted music and SFX volume values.
- Dependencies: `AudioServer` buses named `Music` and `SFX`.
- Storage: `user://settings.cfg` under the `audio` section.
- Public functions: `set_music_db()`, `set_sfx_db()`, `apply_audio()`,
  `save_settings()`, `load_settings()`.
- Startup: loads the config and applies both buses in `_ready()`.

### MusicManager

- File: `globals/MusicManager.gd`
- Responsibility: keep one persistent music player and follow scene-local
  `LevelMusic` declarations.
- Dependencies: nodes in the `level_music` group and the `Music` audio bus.
- Export: default playback volume.
- Public function: `crossfade_to()`.
- Internal functions: detect the current scene's `LevelMusic`, apply its loop
  and bus settings, stop duplicate local music players, cancel stale tweens,
  and restart a finished stream when looping is enabled.

### SceneTransition

- File: `globals/InkwashTransition.gd`
- Scene: `globals/InkwashTransition.tscn`
- Responsibility: capture the outgoing viewport, change scene behind that
  snapshot, and reveal the incoming scene with the ink shader.
- Dependencies: `TransitionSnapshot` `TextureRect` and its `ShaderMaterial`.
- Signal: `transition_finished`.
- Exports: reveal duration and snapshot node path.
- Public functions: `is_busy()`, `set_transition_duration()`,
  `transition_to_scene()`.
- Process mode: always, so a transition can complete while the tree is paused.

## Directory Ownership

| Path | Ownership |
| --- | --- |
| `combat/CombatScene.tscn` | Active potion sandbox composition and wiring. |
| `combat/actors/` | Movement, health, potion receiving, actor scenes, world health bars. |
| `combat/potions/` | Reagent definitions, recipe data, mixer state, projectile behavior. |
| `combat/potions/resources/` | Editable recipes and the default recipe book. |
| `combat/ui/` | Flask rendering and bottom-center mixer controls. |
| `characters/animation/` | Generic humanoid rig, researcher skin, animation library, sockets, and playback facade. |
| `globals/` | Autoload services and reusable scene-level music declaration. |
| `globals/resources/` | Scene registry and project information resources. |
| `mainmenu/` | Main menu, settings overlay, version plaque, and alchemy decoration. |
| `ui/` | Reusable pause menu. |
| `experiments/character_animation/` | Developer animation lab and rigging guide for the production cutout rig. |
| `experiments/directional_character_animation/` | Isolated front/back/mirrored-side geometric locomotion rig and movement room. |
| `experiments/compact_directional_character_animation/` | Isolated compact four-facing rig, external clips, comparison lab, and guide. |
| `tests/` | Potion-domain, collision, rig, player-animation, and action-timing test scenes. |
| `sprites/characters/researcher/` | Transparent researcher atlases and their asset-production README. |
| `music/`, `sprites/`, `extra/` | Audio, remaining images, fonts, and shaders. |

## Combat Scene Composition

`combat/CombatScene.tscn` retains the registered combat scene path. Its root
uses `PotionCombatController` and contains:

- `Arena/Player`: `PlayerActor.tscn`, starting at 70/100 health, using the
  atlas-backed researcher cutout with movement, authored coat motion,
  event-timed potion actions, a right-hand flask prop, and a following camera.
- `Arena/Friend`: `TargetActor.tscn`, starting at 50/100 health, using
  `sprites/characters/overworld_character_TRUE_TRANSPARENT.png` through a scene
  override.
- `Arena/Foe`: `TargetActor.tscn`, starting at 100/100 health, using
  `sprites/characters/mini_boss_TRUE_TRANSPARENT.png` through a scene override.
- `Arena/Projectiles`: owner for thrown potion instances.
- `Systems/PotionInput`: maps Input Map actions to typed signals.
- `Systems/PotionMixer`: owns layers and the prepared recipe.
- `UI/PotionMixerUI`: scene-backed flask and reagent controls.
- `UI/PauseMenu`: reusable pause/settings overlay.
- `LevelMusic`: scene-local request for `music/CombatNew.mp3`.

Actors remain present and targetable at zero health. Healing can raise them
above zero again. No component changes scene or decides victory/defeat.

## Combat Script Reference

### PotionCombatController

- File: `combat/PotionCombatController.gd`
- Responsibility: coordinate components; it does not own recipes, health,
  drawing, movement, or projectile travel.
- Exports: paths for input, mixer, mixer UI, player movement controller, player
  animation controller, player target, projectile owner, plus the projectile
  scene.
- Functions: `_ready()` resolves dependencies; `_has_valid_dependencies()`
  reports missing wiring or an incomplete animation-adapter API;
  `_connect_signals()` connects component boundaries; request handlers reserve
  recipes and enforce mixer/action state; animation callbacks commit, discard,
  or fail safely; small helpers close the mixer and clear pending action
  ownership.

### PotionInput

- File: `combat/PotionInput.gd`
- Responsibility: translate named Input Map actions into intent signals.
- Signals: `mixer_toggle_requested`, `reagent_requested`, `mix_requested`,
  `drink_requested`, `throw_requested`, `remove_reagent_requested`,
  `clear_mixture_requested`.
- Function: `_unhandled_input()` emits one matching request and marks it
  handled. It contains no potion rules.

### PlayerCombatController

- File: `combat/actors/PlayerCombatController.gd`
- Responsibility: move the player and expose throw geometry.
- Export: movement speed.
- Signal: `movement_changed` reports velocity actually applied each physics
  tick.
- Public functions: `set_movement_locked()`, `is_movement_locked()`,
  `get_throw_origin()`, `get_throw_direction()`.
- Callback: `_physics_process()` reads four movement actions unless locked,
  calls `move_and_slide()`, and emits the resulting velocity.
- Geometry boundary: `get_throw_origin()` is used to calculate mouse aim. The
  committed projectile origin comes from the animated hand socket instead.

### PlayerAnimationController

- File: `combat/actors/PlayerAnimationController.gd`
- Responsibility: adapt Player movement, health damage, and potion-use intent
  to the reusable rig without putting combat rules in animation resources.
- Dependencies/exports: rig path, Player controller path, HealthComponent path,
  and scene-backed held-flask scene.
- Signals: `action_event`, `action_interrupted`, and `action_finished`.
- Public functions: `request_potion_action()`, `is_busy()`, and
  `get_action_origin()`.
- Behavior: velocity chooses idle/walk; horizontal movement or captured throw
  aim chooses mirroring; drink/throw/hit lock movement; real pre-commit damage
  destroys the reserved potion and transitions to hit. Damage after a commit
  cannot undo the effect, and further damage during `hit` does not restart the
  clip.
- Event boundary: only the matching `drink_commit` or `throw_release` event is
  forwarded, and each action can forward it once. `state_finished` always
  releases movement. If an event is absent, teardown hides the held flask and
  lets `PotionCombatController` warn and discard the reserved recipe.
- Validation: startup checks every rig method and signal used by the adapter,
  both hand-flask methods, the right-hand socket, movement controller, and
  health component before connecting gameplay.

### HeldPotionFlask

- Files: `combat/actors/HeldPotionFlask.gd`,
  `combat/actors/HeldPotionFlask.tscn`
- Responsibility: provide an authored hand prop whose liquid reflects the
  prepared recipe color.
- Public functions: `show_potion()`, `hide_potion()`.
- Ownership: `PlayerAnimationController` instances it once under the rig's
  right-hand socket and controls only color and visibility. It is hidden on a
  successful commit/release, interruption, failed state request, and
  missing-event recovery.

### HealthComponent

- File: `combat/actors/HealthComponent.gd`
- Responsibility: own bounded health independently of actor presentation.
- Signals: `health_changed`, `depleted`, and `damaged` with the amount actually
  removed by `take_damage()`.
- Exports: `max_health`, `current_health`; both clamp through setters.
- Public functions: `take_damage()`, `heal()`, `reset_health()`,
  `get_health_ratio()`.
- Internal function: `_apply_health()` performs one atomic clamp/update and
  emits signals.

### PotionTarget

- File: `combat/actors/PotionTarget.gd`
- Responsibility: translate a recipe effect into health mutation.
- Dependency/export: path to one `HealthComponent`.
- Signal: `potion_received` after an accepted recipe.
- Public functions: `receive_potion()`, `get_health_component()`.

### ActorHealthBar

- File: `combat/actors/ActorHealthBar.gd`
- Responsibility: display actor name and exact current/maximum health in world
  space.
- Exports: display name and health-component path.
- Functions: `_ready()` validates/connects the component;
  `_on_health_changed()` refreshes all labels and the progress bar.

### PotionReagent

- File: `combat/potions/PotionReagent.gd`
- Responsibility: define the supported identifiers `red`, `green`, and `blue`.
- Public static functions: `is_valid()`, `get_color()`.

### PotionRecipeData

- File: `combat/potions/PotionRecipeData.gd`
- Responsibility: describe one exact three-layer recipe and its result.
- Enum: `EffectType` currently contains `HEAL` and `DAMAGE`.
- Exports: recipe ID, display name, each reagent count, effect type, positive
  effect amount, and prepared liquid color.
- Public functions: `is_valid()`, `matches_layers()`.
- Internal function: `_total_layers()`.

### PotionRecipeBookData

- File: `combat/potions/PotionRecipeBookData.gd`
- Responsibility: hold recipes and match a layer collection by counts rather
  than insertion order.
- Export: typed recipe array.
- Public function: `find_match()`.

### PotionMixer

- File: `combat/potions/PotionMixer.gd`
- Responsibility: own unfinished layers and at most one prepared recipe.
- Dependency/export: `PotionRecipeBookData`; layer limit, hard-clamped to three.
- Signals: `layers_changed`, `potion_prepared`, `mix_rejected`,
  `mixture_cleared`.
- Public functions: `add_reagent()`, `remove_last()`, `clear()`, `mix()`,
  `has_prepared_potion()`, `get_prepared_recipe()`,
  `take_prepared_recipe()`, `get_layers()`.
- Important ownership rule: inspect and validate a prepared recipe before
  calling `take_prepared_recipe()`. Taking it is the commit point.

### PotionProjectile

- File: `combat/potions/PotionProjectile.gd`
- Responsibility: move one recipe toward the cursor and apply it to the first
  accepted `PotionTarget`.
- Exports: speed and lifetime.
- Public function: `launch()` returns whether setup succeeded.
- Functions: `_physics_process()` moves/expires it; `_on_area_entered()` ignores
  the caster and commits only the first accepted hit.

### FlaskView

- File: `combat/ui/FlaskView.gd`
- Responsibility: render three authored liquid bands and prepared/failure
  states without owning mixer rules.
- Public functions: `set_layers()`, `show_mixed()`, `show_failure()`,
  `reset_view()`.
- Internal function: `_stop_animation()` prevents stale tween completion from
  overwriting a newer state.

### PotionMixerUI

- File: `combat/ui/PotionMixerUI.gd`
- Responsibility: expose the scene-backed flask plus R/G/B buttons.
- Signal: `reagent_selected`.
- Public functions: `set_open()`, `show_mixing()`, `show_ready()`,
  `show_mix_failure()`, `reset_view()`.
- Button callbacks emit reagent intent only; the controller and mixer decide
  whether it is accepted.

## Character Animation System And Lab

The reusable Godot-native 2D skeletal cutout system lives under
`characters/animation/` and is active on the Player. Run
`experiments/character_animation/CharacterAnimationLab.tscn` with **Play
Current Scene** to edit and exercise the same rig independently of combat.

### HumanoidCutoutRig Scene

- File: `characters/animation/HumanoidCutoutRig.tscn`
- Responsibility: author the reusable humanoid skeleton, rigid placeholder
  body parts, hand sockets, optional bone overlay, and playback nodes.
- Root structure: `HumanoidCutoutRig/FacingRoot/Skeleton2D` with standardized
  `Root`, `Spine`, `Head`, paired arm/hand bones, paired leg/foot bones, and
  `CoatTail_L`, `CoatTail_C`, and `CoatTail_R`.
- Visual approach: engine-native `Polygon2D` parts parented directly to their
  controlling `Bone2D`. These are structural placeholders retained for future
  humanoid skins. There is no weighted deformation, IK, or root motion.
- Coat rest contract: left is `(-14, 8)`, length 76, rotation 3 degrees;
  center is `(0, 10)`, length 84, rotation 0 degrees; right is `(14, 8)`,
  length 72, rotation -3 degrees.
- Visual layers: rear coat 0, rear limbs 1, pelvis/torso 2, front limbs 3,
  head/hat 4, equipment 5, held flask 12, and debug lines 20. Negative visual
  layers are prohibited because an opaque stage can hide them.
- Facing: horizontal mirroring changes only `FacingRoot`; gameplay/world
  transforms are not involved.
- Attachment points: `HandSocket_L` and `HandSocket_R` are `Marker2D` nodes
  exposed as `hand_left` and `hand_right`; the Player attaches its flask to
  `hand_right`.
- Naming contract: reusable animation tracks depend on the exact bone names and
  node paths. Visual children may be replaced, but tracked bones must not be
  renamed or reparented without migrating the animation library.

The exact hierarchy, rest-pose workflow, artwork overlap, and pivot guidance
are documented in `experiments/character_animation/README.md`.

### ResearcherCutoutRig Scene

- File: `characters/animation/ResearcherCutoutRig.tscn`
- Responsibility: provide the active Player appearance without duplicating the
  generic skeleton, playback graph, sockets, or public script.
- Inheritance: instances `HumanoidCutoutRig.tscn`, hides every placeholder
  `Polygon2D`, and adds 21 atlas-backed `Sprite2D` parts under their controlling
  bones.
- Textures: `sprites/characters/researcher/researcher_core.png`,
  `researcher_arms.png`, `researcher_legs.png`, and `researcher_coat.png`.
- Pivot rule: each sprite remains at local zero and uses
  `offset = region_size / 2 - joint_pivot_px`. Every pivot is authored as node
  metadata and protected by the rig test.
- Proportion override: researcher shoulders use local `x = +/-27` instead of
  the generic `x = +/-31`; tracked names, rotations, children, hand sockets,
  and animation paths remain unchanged.
- Consumers: `combat/actors/PlayerActor.tscn` and
  `experiments/character_animation/CharacterAnimationLab.tscn`.
- Asset specification: exact prompts, regions, pivots, scales, overlap, and
  replacement checks live in `sprites/characters/researcher/README.md`.

### HumanoidAnimationLibrary

- File: `characters/animation/HumanoidAnimationLibrary.tres`
- Type: external `AnimationLibrary` assigned to the rig's `AnimationPlayer`.
- Reuse rule: another humanoid can share the library only when it preserves the
  tracked node paths and has broadly compatible proportions.
- Playback graph: the `AnimationTree` is a BlendTree whose `StateMachine`
  output passes through `TimeScale` before the final output.
- Startup: the rig starts in `idle`.
- Transitions: `idle` and `walk` blend over 0.12 seconds; action states enter
  over 0.08 seconds and automatically return to `idle` over 0.10 seconds.
  Damage can interrupt `drink` or `throw` into `hit` over 0.04 seconds.
- Coat motion: every clip tracks all three coat bones. Idle stays within 1.5
  degrees, walk reaches 5 degrees on side panels and 2 degrees at center,
  drink stays within 2 degrees, throw uses up to 10 degrees of authored lag,
  and hit uses 10 degrees of recoil. There is no cloth physics.

| Clip | Duration | Looping | Event |
| --- | ---: | --- | --- |
| `RESET` | 0.10 s | No | None |
| `idle` | 1.60 s | Yes | None |
| `walk` | 0.80 s | Yes | None |
| `drink` | 1.00 s | No | `drink_commit` at 0.55 s |
| `throw` | 0.75 s | No | `throw_release` at 0.45 s |
| `hit` | 0.45 s | No | `hit_peak` at 0.18 s |

All locomotion remains in place. `PlayerCombatController` owns world movement;
the animation adapter observes its emitted velocity.

### HumanoidCutoutRig Script

- File: `characters/animation/HumanoidCutoutRig.gd`
- Responsibility: provide a small playback facade over authored rig and
  animation resources; it does not create bones, body parts, clips, or UI.
- Dependencies: unique nodes `FacingRoot`, `DebugBones`, `AnimationPlayer`, and
  `AnimationTree`, plus a state-machine parameter named `StateMachine` and a
  time-scale parameter named `TimeScale`.
- Signals: `state_changed(state)`, `state_finished(state)`, and
  `animation_event(event_name)`.
- Public functions: `play_state()`, `reset_to_idle()`, `set_mirrored()`,
  `set_playback_speed()`, `set_debug_bones_visible()`, `get_current_state()`,
  `get_available_states()`, and `get_socket()`.
- Validation: invalid state requests return `false`; playback speed clamps to
  0.25-2.0.
- Internal event relay: animation method tracks call `_emit_animation_event()`,
  which emits the public `animation_event` signal.

### CharacterAnimationLab

- Scene: `experiments/character_animation/CharacterAnimationLab.tscn`
- Script: `experiments/character_animation/CharacterAnimationLab.gd`
- Responsibility: provide a neutral responsive stage and scene-authored
  controls for exercising the active researcher skin through the generic rig's
  public API.
- Controls: Idle, Walk, Drink, Throw, Hit, playback speed, Mirror, Bones, and
  Reset.
- Feedback: labels show the current state and most recent animation event.
- Scope rule: the lab controller forwards UI input only. It does not construct
  rig nodes, alter animation data, or invoke gameplay. Combat and the lab are
  separate consumers of the same researcher scene.

### Directional Geometric Locomotion Lab

- Guide: `experiments/directional_character_animation/README.md`
- Responsibility: test a reusable high-detail FK skeleton with eight-direction
  movement represented by front, back, and mirrored side animation families.
- Playback: synchronized `1.6` second idle and `0.72` second walk loops blend
  through one `AnimationTree` without restarting the gait phase.
- Lab: one `CharacterBody2D` moves at 220 pixels per second in a bounded room
  while a fixed-orientation `Camera2D` follows without smoothing.
- Public adapter: accepts velocity or an explicit facing direction and reports
  `idle`/`walk` plus `front`/`back`/`side_left`/`side_right`.
- Isolation: it is not registered in `project.godot` and is not referenced by
  the active Player, combat scene, or production researcher rig.

### Balanced Compact Directional Rig V2

- Guide: `experiments/compact_directional_character_animation/README.md`
- Rig: 15 authored `Bone2D` nodes and rigid polygons form a 100 by 116 pixel
  arcade silhouette with stable left/right hand sockets.
- Playback: four idle and four walk clips use separate front, back, side-left,
  and side-right states. Every walk shares the same nine-key 0.72-second gait.
- Direction changes: idle and walk state machines use synchronized,
  non-resetting 0.10-second crossfades; locomotion blends over 0.12 seconds.
- Anatomy: side clips are authored independently and never mirror
  `FacingRoot`; colored placeholder limbs make hand identity inspectable.
- Comparison lab: one `CharacterBody2D` sends normalized 220-pixel-per-second
  motion to the original and compact rigs at native scale, with two collision
  shapes and one unsmoothed bounded camera.
- Public adapter: preserves the original directional API and signal names so a
  later production skin can be evaluated without changing movement ownership.
- Promotion path: replace polygons with four directional sprite sets, preserve
  bone paths and pivots, then integrate through a focused Player adapter.
- Isolation: V2 is absent from combat, autoloads, active Player scenes, and
  `project.godot`.

## Shell Script Reference

### LevelMusic

- File: `globals/LevelMusic.gd`
- Responsibility: declare scene-local music settings without playing audio.
- Exports: stream, volume, crossfade duration, loop flag, bus.
- Public getters: `get_music()`, `get_crossfade()`, `get_loop()`,
  `get_volume_db()`, `get_bus()`.

### SceneRegistryData

- File: `globals/resources/SceneRegistryData.gd`
- Responsibility: editable scene references used by `GameManager`.
- Exports: `main_menu_scene`, `combat_scene`.

### ProjectInfoData

- File: `globals/resources/ProjectInfoData.gd`
- Responsibility: version/focus/build text used by the main-menu plaque.
- Exports: project version, current focus, build label, and visibility flags.

### MainMenu

- File: `mainmenu/MainMenu.gd`
- Responsibility: own New Game, Settings, and Quit interactions and apply the
  menu style resource.
- Exports: transition duration and `MainMenuStyleData`.
- Functions: `_ready()` validates and connects dependencies; button handlers
  call `GameManager`; style/transition helpers update retained presentation.

### MainMenuStyleData

- File: `mainmenu/resources/MainMenuStyleData.gd`
- Responsibility: provide editable high-level main-menu presentation values.
- Exports: background, alchemy-seal appearance/motion, and retained shader
  controls.

### AlchemySeal

- Files: `mainmenu/AlchemySeal.gd`, `mainmenu/AlchemySeal.tscn`
- Responsibility: draw and animate abstract alchemy rings with red, green, and
  blue marks. It is decorative and has no combat-data dependency.
- Exports: geometry, colors, opacity, pulse, and rotation controls.
- Functions: `_ready()`, `_process()`, `_draw()`, plus small internal
  geometry/alpha helpers.

### SettingsMenu

- File: `mainmenu/SettingsMenu.gd`
- Responsibility: bridge music/SFX sliders to the `Settings` autoload.
- Signal: `close_requested`.
- Functions: `_ready()` validates/connects controls; slider callbacks persist
  dB values; the Back callback hides the panel and emits the close request.

### VersionStone

- File: `mainmenu/VersionStone.gd`
- Responsibility: display `ProjectInfoData` with explicit fallback text.
- Export: `project_info` with a refresh setter.
- Functions: `_ready()`, `_refresh_labels()`, `_get_project_info()`.

### PauseMenu

- File: `ui/PauseMenu.gd`
- Responsibility: pause/unpause the tree and expose Resume, Settings, Main Menu,
  and Quit actions.
- Dependency: embedded `mainmenu/Settings.tscn` and `GameManager`.
- Functions: `_enter_tree()` selects always-process mode; `_ready()` connects
  controls; `_unhandled_input()` handles Escape; open/close/settings/button
  handlers own visibility and pause state.

### PotionDomainTests

- Files: `tests/PotionDomainTests.gd`, `tests/PotionDomainTests.tscn`
- Responsibility: run dependency-free behavioral checks and exit with status 0
  or 1.
- Coverage: order-independent recipes, strict three-layer limits, rejected-mix
  preservation/signals, prepared ownership, health bounds/signals/recovery, and
  target acceptance.

### PotionProjectileCollisionTests

- Files: `tests/PotionProjectileCollisionTests.gd`,
  `tests/PotionProjectileCollisionTests.tscn`
- Responsibility: verify a real `Area2D` overlap applies one thrown potion and
  consumes the projectile without mutating physics monitoring during the
  overlap callback.
- Coverage: target/projectile instantiation, health-component wiring, valid
  launch, exactly-once damage, and projectile cleanup after the first accepted
  hit.

### CharacterAnimationRigTests

- Files: `tests/CharacterAnimationRigTests.gd`,
  `tests/CharacterAnimationRigTests.tscn`
- Responsibility: verify the production cutout rig contract and its independent
  developer lab.
- Coverage: required humanoid and coat bones, coat rest transforms and motion
  ranges, hand sockets, clip names/durations/loop modes, exact method-track
  event times, AnimationTree nodes and interruption transitions, socket
  lookup, public state requests, invalid-state rejection, mirroring scope,
  playback-speed clamps, debug-line visibility, nonnegative visual layers,
  all 21 researcher AtlasTextures and pivots, placeholder hiding, Player/lab
  skin wiring, automatic action returns, and 1280x720 lab containment.

### PlayerAnimationControllerTests

- Files: `tests/PlayerAnimationControllerTests.gd`,
  `tests/PlayerAnimationControllerTests.tscn`
- Responsibility: verify the real PlayerActor animation composition and public
  adapter contract.
- Coverage: rig transform, health-bar clearance, locomotion without repeated
  clip restarts, facing retention, action locks, held-flask visibility/color,
  event forwarding, captured throw aim, interruption, missing-event cleanup,
  hit recovery, and invalid-action rejection.

### PotionActionTimingTests

- Files: `tests/PotionActionTimingTests.gd`,
  `tests/PotionActionTimingTests.tscn`
- Responsibility: verify CombatScene reserves and commits recipes through
  authored animation events rather than raw input timing.
- Coverage: delayed drink/throw, hand-socket spawn, captured aim, blocked mixer
  input, duplicate/mismatched event rejection, drink and throw interruption,
  repeated hit damage, missing-event cleanup, and post-commit self-damage
  recovery.

## Potion Data Flow

1. Tab toggles an unfinished mixer. A prepared potion cannot be hidden.
2. Keys 1/2/3 or the R/G/B buttons emit a reagent request.
3. `PotionMixer.add_reagent()` accepts valid identifiers until three layers are
   present. It emits a copied layer array to the UI.
4. Space calls `PotionMixer.mix()`.
5. `PotionRecipeBookData.find_match()` compares reagent counts. Input order does
   not matter.
6. Unknown or incomplete mixtures emit `mix_rejected`; layers remain unchanged.
7. A valid match clears the bands, stores one prepared recipe, emits
   `potion_prepared`, blends the flask, and hides reagent buttons.
8. Right Mouse or Left Mouse asks `PlayerAnimationController` to start a drink
   or throw. Accepted actions reserve the recipe, close the mixer, lock movement,
   and display the colored hand flask.
9. `drink_commit` applies the reserved recipe to the Player. `throw_release`
   spawns it from the animated right-hand socket using aim captured at action
   start.
10. Real damage before commit/release discards the potion and transitions to
    hit. Damage after commit cannot undo an applied effect or spawned projectile.
11. Duplicate, mismatched, or missing animation events cannot apply a recipe
    twice, leave it pending, or leave the held flask visible. C still cancels a
    prepared potion before an action starts and leaves an open empty mixer.

## Default Recipes

| Resource | Counts | Effect | Amount | Prepared color |
| --- | --- | --- | --- | --- |
| `HealthPotion.tres` | 2 red, 1 blue | Heal | 30 | Magenta |
| `DamagePotion.tres` | 2 green, 1 blue | Damage | 30 | Teal |

Both resources are registered in
`combat/potions/resources/PotionRecipeBook_Default.tres`.

## Adding A Recipe

1. Create a `PotionRecipeData` resource under
   `combat/potions/resources/`.
2. Assign a unique `recipe_id`, optional display name, non-negative color
   counts totaling exactly three, an effect type, positive amount, and liquid
   color.
3. Add the resource to the `recipes` array in
   `PotionRecipeBook_Default.tres`.
4. Add order-independent success and invalid-data checks to
   `tests/PotionDomainTests.gd`.
5. Test all permutations needed for the recipe. Matching is count-based, so no
   duplicate recipe resource is needed for another insertion order.

To add a new effect category, extend `PotionRecipeData.EffectType` and add one
handling branch in `PotionTarget.receive_potion()`. Keep visual/projectile code
dependent on the recipe's color, not its effect type.

## Input Actions

| Action | Default input | Owner |
| --- | --- | --- |
| `move_up` | W / Up | Player movement |
| `move_down` | S / Down | Player movement |
| `move_left` | A / Left | Player movement |
| `move_right` | D / Right | Player movement |
| `toggle_mixer` | Tab | Open/hide unfinished mixer |
| `add_red_reagent` | 1 | Add red layer |
| `add_green_reagent` | 2 | Add green layer |
| `add_blue_reagent` | 3 | Add blue layer |
| `mix_potion` | Space | Attempt recipe match |
| `drink_potion` | Right Mouse | Apply prepared recipe to Player |
| `throw_potion` | Left Mouse | Throw prepared recipe toward cursor |
| `remove_reagent` | Backspace | Remove newest unfinished layer |
| `clear_mixture` | C | Clear/cancel mixture |
| `ui_cancel` | Escape | Toggle pause/settings return |

## Verification

### Automated Domain Scene

With a working Godot executable on `PATH`:

```powershell
godot --headless --path . res://tests/PotionDomainTests.tscn
```

Expected output contains `PotionDomainTests: PASS (20 tests)` and exits with
code 0.

### Automated Projectile Collision Scene

```powershell
godot --headless --path . res://tests/PotionProjectileCollisionTests.tscn
```

Expected output contains `PotionProjectileCollisionTests: PASS (6 checks)` and
exits with code 0. Run this test with normal physics timing rather than forcing
a fixed FPS.

### Automated Character Animation Scene

```powershell
godot --headless --fixed-fps 60 --path . res://tests/CharacterAnimationRigTests.tscn
```

Expected output contains `CharacterAnimationRigTests: PASS (467 checks)` and
exits with code 0. Fixed FPS provides deterministic timing for one-shot event
and automatic-return checks.

### Automated Player Animation Scene

```powershell
godot --headless --fixed-fps 60 --path . res://tests/PlayerAnimationControllerTests.tscn
```

Expected output contains `PlayerAnimationControllerTests: PASS (66 checks)` and
exits with code 0.

### Automated Compact Directional Rig Scene

```powershell
godot --headless --fixed-fps 60 --path . res://tests/CompactDirectionalAnimationRigTests.tscn
```

Expected output contains
`CompactDirectionalAnimationRigTests: PASS (475 checks)`. It validates the
compact rig, authored clips, direction graph, public API, and comparison lab.

### Automated Potion Action Timing Scene

```powershell
godot --headless --fixed-fps 60 --path . res://tests/PotionActionTimingTests.tscn
```

Expected output contains `PotionActionTimingTests: PASS (69 checks)` and exits
with code 0. This scene removes its local `LevelMusic` before entering the tree
because music behavior is outside the timing test. It intentionally simulates
one missing animation event, so the expected output also contains the warning
that the unfinished recipe was discarded.

### Manual Godot Checklist

1. Open the project and confirm no missing script, class, or resource errors.
2. Run the main project. Confirm main-menu music plays once.
3. Change both settings sliders, leave settings, reopen it, and confirm values;
   restart the project and confirm `user://settings.cfg` restores them.
4. Press New Game. Confirm the ink transition completes and combat music
   crossfades without duplicate playback.
5. Move with WASD/arrows. Confirm the researcher enters walk, both arms and
   both legs remain visible, coat panels move without opening seams, horizontal
   movement changes facing, vertical movement preserves facing, and the camera
   follows.
6. Confirm visible health bars start at Player 70, Friend 50, Foe 100.
7. Press Tab. Confirm one flask and R/G/B controls appear at bottom center.
8. Add layers with both number keys and buttons. Confirm bottom-up bands, the
   three-layer limit, Backspace LIFO removal, and C clearing.
9. Close/reopen an unfinished mixer with Tab. Confirm layers are preserved.
10. Try fewer than three layers and an unknown combination such as red/green/
	blue. Press Space and confirm the flask flashes/shakes without clearing.
11. Mix red/red/blue in multiple orders. Confirm the flask becomes one liquid,
	reagent buttons hide, and Tab is ignored while prepared.
12. Right-click the health potion. Confirm the mixer closes, a colored flask
   appears in the right hand, movement locks, and healing occurs at
   `drink_commit` rather than on the click.
13. Mix green/green/blue and left-click toward Friend, Foe, and empty space on
   separate attempts. Confirm the Player faces the captured aim, movement locks,
   the projectile leaves the animated hand at `throw_release`, either target can
   take 30 damage, and misses expire.
14. Throw a health potion at both Friend and Foe. Confirm recipe effect, not
	target identity, decides healing.
15. Reduce an actor to zero and heal it. Confirm its health bar recovers and the
	scene does not transition.
16. Prepare a potion and press C. Confirm an empty mixer remains open.
17. Pause during a drink or throw. Confirm animation/event timing freezes and
   resumes without duplicating the potion; Resume, Settings, Main Menu, and Quit
   still behave correctly.
18. Resize through smaller 16:9 windows. Confirm the mixer stays fully visible at
	bottom center and health/UI text does not overlap.

### Manual Character Animation Checklist

1. Open `experiments/character_animation/CharacterAnimationLab.tscn` and use
   **Play Current Scene**.
2. Confirm the researcher skin starts in `idle` with the bone overlay visible.
   Verify both arms, both legs, the hat/head, torso, satchel, and all three coat
   panels render over the neutral stage.
3. Select Idle and Walk. Confirm both loop in place and blend without moving the
   scene root through world space.
4. Select Drink, Throw, and Hit. Confirm each action plays once, all coat
   panels show restrained secondary motion, each expected event is reported,
   and playback automatically returns to `idle`.
5. Move the speed slider through 0.25x, 1.0x, and 2.0x. Confirm animation speed
   changes without changing transition ownership or world position.
6. Toggle Mirror. Confirm only the authored facing container flips, the
   equipment/satchel swap sides consistently, and the rig remains centered.
7. Toggle Bones. Confirm all cyan bone indicators hide and reappear while body
   parts remain visible.
8. Select Reset. Confirm the lab returns to `idle` and clears the last-event
   label.
9. Resize through smaller 16:9 windows. Confirm the stage remains centered and
   the toolbar stays inside the viewport without overlapping controls.
10. Run the main project with F5. Prepare drink and throw potions. Confirm the
    scene-backed flask follows the researcher's animated right hand, hides at
    `drink_commit` or `throw_release`, and the lab UI never enters active scene
    flow.

## Change Guidelines

- Keep changes small and reviewable.
- Prefer script/resource edits before changing scene structure.
- Do not rename autoloads, registered scenes, or important scene nodes without
  an explicit migration request.
- Keep `PotionCombatController` as a coordinator. Put state/rules in their owning
  components instead of growing a new all-purpose manager.
- Do not couple recipe matching to insertion order or actor identity.
- Keep the animation lab isolated from gameplay even though it shares the
  production rig. Add future actor integrations through focused adapters rather
  than teaching `HumanoidCutoutRig` about health, input, or potion rules.
- Preserve the humanoid rig's tracked bone names and paths when reusing
  `HumanoidAnimationLibrary.tres`; migrate animation tracks deliberately if the
  hierarchy changes.
- After each change, list changed files and provide focused manual Godot steps.
