# Project Architecture

> Status: Technical source of truth
> Last verified: 2026-08-23 with Godot 4.7.2
> Creative companion: [Style and Vision](./STYLE_AND_VISION.md)
> Player model guide: [PlayerModel](../characters/player/README.md)
> Visual reference pack: [Art Reference Index](./ART_REFERENCE_INDEX.md)

## Project Scope

CombatAlchemy is a Godot 4.x GDScript prototype. The active game is a
real-time potion combat sandbox reached from the main menu. The current slice
has player movement and collision, targetable actors with health, immediate
potion drinking and throwing, mixer UI, scene transitions, music, settings,
and pause navigation.

There is no exploration layer, enemy AI, victory state, defeat state,
permanent save data, or automatic combat-completion return flow. Current
backlog: enemy entity, flask UI, runtime storage and pickup mechanics, then
victory and defeat states.

The code favors scene-local components. The only autoloads are application
shell services: settings, music, transitions, and scene routing. Potion data,
health, input translation, UI rendering, player presentation, and projectile
motion remain independent of those autoloads.

## Runtime Flow

```text
project.godot
  -> mainmenu/StartMenu.tscn
	  -> MainMenu: New Game
		  -> GameManager.start_new_game()
			  -> SceneTransition.transition_to_scene()
				  -> combat/CombatScene.tscn

CombatScene
  -> PlayerActor (world movement, camera, collision, health)
	  -> PlayerModel (15-bone visuals, four-facing idle/walk, sockets)
  -> PotionCombatController
	  -> immediate drink: PotionTarget.receive_potion(recipe)
	  -> immediate throw: PlayerCombatController origin/direction
		  -> PotionProjectile.launch(...)

Play Current Scene
  -> characters/player/PlayerModelWorkshop.tscn
```

Escape opens `ui/PauseMenu.tscn`. Resume returns to the same scene; Main Menu
routes through `GameManager`; Quit calls `GameManager.quit_game()`.

## Directory Ownership

| Path | Ownership |
| --- | --- |
| `characters/player/` | Canonical compact player model, locomotion library, sockets, workshop, and model guide. |
| `combat/CombatScene.tscn` | Active potion sandbox composition and dependency wiring. |
| `combat/actors/` | Player movement, actor health, potion receiving, collision, cameras, and world health bars. |
| `combat/potions/` | Reagent constants, recipe resources, mixer state, and projectile behavior. |
| `combat/potions/resources/` | Editable default recipe book and recipe resources. |
| `combat/ui/` | Flask rendering and bottom-center mixer controls. |
| `globals/` | Autoload services and scene-level music declarations. |
| `globals/resources/` | Scene registry and project information resources. |
| `mainmenu/` | Main menu, settings overlay, version plaque, and alchemy decoration. |
| `ui/` | Reusable pause menu. |
| `tests/` | Six retained headless scene suites for player, potion, and collision behavior. |
| `docs/` | Active architecture, visual direction, and local art references. |
| `music/`, `sprites/`, `extra/` | Audio, remaining images, fonts, and shaders. |

## Scene Composition

### CombatScene

`combat/CombatScene.tscn` is the registered combat scene. Its root owns
`PotionCombatController` and composes:

- `Arena/Player`: `combat/actors/PlayerActor.tscn`, including
  `PlayerCombatController`, `characters/player/PlayerModel.tscn`, collision,
  following camera, `HealthComponent`, `PotionTarget`, and `ActorHealthBar`.
- `Arena/Friend` and `Arena/Foe`: `TargetActor.tscn` instances with distinct
  visuals and starting health.
- `Arena/Projectiles`: owner for thrown potion instances.
- `Systems/PotionInput`: maps Input Map actions to potion intent signals.
- `Systems/PotionMixer`: owns reagent layers and a prepared recipe.
- `UI/PotionMixerUI`: displays layers, prepared color, and reagent controls.
- `UI/PauseMenu`: reusable pause and settings overlay.
- `LevelMusic`: requests `music/CombatNew.mp3` from `MusicManager`.

Actors remain present and targetable at zero health. Healing can raise them
above zero. No component changes scenes or decides victory or defeat.

### PlayerActor

`combat/actors/PlayerActor.tscn` owns active player world behavior. The root
`CharacterBody2D` runs `PlayerCombatController.gd`; it contains the canonical
`PlayerModel`, collision, camera, health, potion target, and health bar. World
velocity is passed directly to `PlayerModel.set_motion()`. Throw origin is the
model's `hand_right` socket, with the actor position as a defensive fallback.

### PlayerModel

`characters/player/PlayerModel.tscn` owns presentation only. Its authored
15-bone `Skeleton2D`, geometric body parts, two hand sockets,
`AnimationPlayer`, and `AnimationTree` are directly editable. Four separate
facings (`front`, `back`, `side_left`, `side_right`) each provide idle and walk
clips through `characters/player/PlayerLocomotionLibrary.tres`. Horizontal
facings use authored positive-scale states; they are not mirrored at runtime.

Stable socket IDs are `hand_left` and `hand_right`. Consumers call
`get_socket()` instead of depending on internal bone paths. The complete bone
tree and sprite-replacement contract are in
`characters/player/README.md`.

### PlayerModelWorkshop

`characters/player/PlayerModelWorkshop.tscn` is the isolated Play Current
Scene workshop. `PlayerModelWorkshopActor.gd` owns movement and collision;
`PlayerModel.gd` remains presentation-only; `PlayerModelWorkshop.gd` keeps the
facing, locomotion, and debug-bone controls synchronized. The workshop is not
registered in `project.godot` and is not a runtime dependency of combat.

## Retained Script Reference

Public methods below exclude Godot lifecycle callbacks and private methods
whose names begin with an underscore. `None` means the script intentionally
exposes no item in that category.

### Player And Combat

| Script | Responsibility | Dependencies | Signals | Exports | Public methods |
| --- | --- | --- | --- | --- | --- |
| `characters/player/PlayerModel.gd` | Own compact visual facing, locomotion blending, sockets, and debug bones. | Authored model nodes, required clips, and `AnimationTree` state machines. | `facing_changed`, `locomotion_changed` | None | `set_motion()`, `set_facing_direction()`, `reset_to_idle()`, `set_playback_speed()`, `set_debug_bones_visible()`, `get_facing()`, `get_locomotion_state()`, `get_socket()` |
| `characters/player/PlayerModelWorkshop.gd` | Synchronize workshop status controls with the canonical model. | Workshop `PlayerModel`, labels, and bones toggle. | None | None | None |
| `characters/player/PlayerModelWorkshopActor.gd` | Move and collide the workshop actor while forwarding velocity to the model. | Input Map movement actions and a model exposing `set_motion()`. | None | `movement_speed`, `player_model_path` | None |
| `combat/PotionCombatController.gd` | Coordinate potion input, mixer state, UI, immediate drinking, and immediate projectile spawning. | `PotionInput`, `PotionMixer`, `PotionMixerUI`, `PlayerCombatController`, player `PotionTarget`, projectile parent and scene. | None | Six dependency paths and `projectile_scene` | None |
| `combat/PotionInput.gd` | Translate named Input Map actions into potion intent. | Project input actions and `PotionReagent`. | `mixer_toggle_requested`, `reagent_requested`, `mix_requested`, `drink_requested`, `throw_requested`, `remove_reagent_requested`, `clear_mixture_requested` | None | None |
| `combat/actors/PlayerCombatController.gd` | Move the active player and provide world-space throw geometry. | Movement actions and `PlayerModel.set_motion()`/`get_socket()`. | `movement_changed` | `speed`, `player_model_path` | `set_movement_locked()`, `is_movement_locked()`, `get_throw_origin()`, `get_throw_direction()` |
| `combat/actors/HealthComponent.gd` | Own bounded actor health. | None. | `health_changed`, `depleted`, `damaged` | `max_health`, `current_health` | `take_damage()`, `heal()`, `reset_health()`, `get_health_ratio()` |
| `combat/actors/PotionTarget.gd` | Validate and apply a potion recipe to one health component. | `PotionRecipeData` and configured `HealthComponent`. | `potion_received` | `health_component_path` | `receive_potion()`, `get_health_component()` |
| `combat/actors/ActorHealthBar.gd` | Display an actor name and exact world-space health values. | Configured `HealthComponent` and scene labels/bar. | None | `display_name`, `health_component_path` | None |
| `combat/potions/PotionReagent.gd` | Define supported reagent IDs and colors. | None. | None | None | Static `is_valid()`, `get_color()` |
| `combat/potions/PotionRecipeData.gd` | Describe one exact three-layer potion recipe and effect. | `PotionReagent`. | None | ID, name, three counts, effect type, effect amount, mixed color | `is_valid()`, `matches_layers()` |
| `combat/potions/PotionRecipeBookData.gd` | Find an order-independent recipe match. | `PotionRecipeData` resources. | None | `recipes` | `find_match()` |
| `combat/potions/PotionMixer.gd` | Collect layers and prepare or consume one recipe. | `PotionReagent` and configured `PotionRecipeBookData`. | `layers_changed`, `potion_prepared`, `mix_rejected`, `mixture_cleared` | `max_layers`, `recipe_book` | `add_reagent()`, `remove_last()`, `clear()`, `mix()`, `has_prepared_potion()`, `get_prepared_recipe()`, `take_prepared_recipe()`, `get_layers()` |
| `combat/potions/PotionProjectile.gd` | Move a prepared potion, apply it to the first accepted target, and expire. | Valid `PotionRecipeData`, `PotionTarget`, projectile visuals. | None | `speed`, `lifetime` | `launch()` |
| `combat/ui/FlaskView.gd` | Render layers, a completed mixture, and failed-mix feedback. | Child polygons/outline and `PotionReagent` colors. | None | None | `set_layers()`, `show_mixed()`, `show_failure()`, `reset_view()` |
| `combat/ui/PotionMixerUI.gd` | Present reagent controls and reflect mixer state. | `FlaskView` and three reagent buttons. | `reagent_selected` | None | `set_open()`, `show_mixing()`, `show_ready()`, `show_mix_failure()`, `reset_view()` |

### Application Shell

| Script | Responsibility | Dependencies | Signals | Exports | Public methods |
| --- | --- | --- | --- | --- | --- |
| `globals/GameManager.gd` | Route high-level actions to registered scenes. | `SceneRegistryData`, `SceneTree`, optional `SceneTransition`. | None | `use_ink_transition`, `scene_registry` | `start_new_game()`, `go_to_main_menu()`, `quit_game()` |
| `globals/Settings.gd` | Persist and apply Music/SFX bus levels. | `AudioServer`, `user://settings.cfg`. | None | None | `set_music_db()`, `set_sfx_db()`, `apply_audio()`, `save_settings()`, `load_settings()` |
| `globals/MusicManager.gd` | Own persistent scene music and crossfades. | `LevelMusic` nodes and requested audio bus. | Inherited `AudioStreamPlayer.finished` | `default_volume_db` | `crossfade_to()` |
| `globals/InkwashTransition.gd` | Change scenes behind a captured ink-wash snapshot. | Snapshot `TextureRect`, `ShaderMaterial`, and `SceneTree`. | `transition_finished` | `ink_reveal_time`, `transition_snapshot_path` | `is_busy()`, `set_transition_duration()`, `transition_to_scene()` |
| `globals/LevelMusic.gd` | Describe a scene's music request. | `AudioStream` and named audio bus. | None | `music`, `volume_db`, `crossfade`, `loop`, `bus` | `get_music()`, `get_crossfade()`, `get_loop()`, `get_volume_db()`, `get_bus()` |
| `globals/resources/SceneRegistryData.gd` | Register main-menu and combat scenes. | `PackedScene`. | None | `main_menu_scene`, `combat_scene` | None |
| `globals/resources/ProjectInfoData.gd` | Supply main-menu project metadata. | None. | None | `project_version`, `current_focus`, `build_label`, `show_focus`, `show_build_label` | None |
| `mainmenu/MainMenu.gd` | Coordinate menu controls, styling, settings visibility, and game start/quit. | `GameManager`, `SceneTransition`, `SettingsMenu`, `AlchemySeal`, `MainMenuStyleData`. | None | `transition_duration`, `menu_style` | None |
| `mainmenu/SettingsMenu.gd` | Synchronize audio sliders with persistent settings. | `Settings` autoload and menu controls. | `close_requested` | None | None |
| `mainmenu/VersionStone.gd` | Present project version and focus metadata. | Labels and optional `ProjectInfoData`. | None | `project_info` | None |
| `mainmenu/AlchemySeal.gd` | Draw and animate the decorative menu seal. | `CanvasItem` drawing. | None | Geometry, animation, and appearance tuning values | None |
| `mainmenu/resources/MainMenuStyleData.gd` | Store main-menu visual tuning. | Optional background texture. | None | Background, seal, shader, vignette, and pulse values | None |
| `ui/PauseMenu.gd` | Own pause input, settings navigation, resume, menu routing, and quit. | `SettingsMenu`, `GameManager`, and `ui_cancel`. | None | None | None |

### Test Runners

| Script | Responsibility | Dependencies | Signals | Exports | Public methods |
| --- | --- | --- | --- | --- | --- |
| `tests/PlayerModelTests.gd` | Validate the 15-bone model, animations, facings, sockets, bounds, public behavior, and dependency failures. | `PlayerModel.tscn` and player model resources. | None | None | None |
| `tests/PlayerModelWorkshopTests.gd` | Validate workshop composition, controls, movement, collision, camera, and debug bones. | `PlayerModelWorkshop.tscn`. | None | None | None |
| `tests/PlayerActorTests.gd` | Validate active player composition, movement/model forwarding, and throw origin/fallback. | `PlayerActor.tscn` and `PlayerModel`. | None | None | None |
| `tests/PotionDomainTests.gd` | Validate reagents, recipes, mixer signals/state, health, targets, and movement lock. | Potion-domain and actor scripts. | None | None | None |
| `tests/PotionProjectileCollisionTests.gd` | Validate launched projectile collision and recipe delivery. | `PotionProjectile`, `PotionTarget`, and health data. | None | None | None |
| `tests/PotionUseTests.gd` | Validate immediate drink/throw input paths, UI closure, origin/direction, self-ignore, hit, and expiry. | `CombatScene.tscn` and potion/player runtime components. | None | None | None |

## Potion Data Flow

1. `PotionInput` converts one handled Input Map action into one signal.
2. `PotionCombatController` accepts reagent edits only while the mixer is open
   and no potion is prepared.
3. `PotionMixer` validates reagent IDs, enforces three layers, and asks its
   `PotionRecipeBookData` for an order-independent exact match.
4. A rejected mix preserves its layers and asks `PotionMixerUI` to show brief
   failure feedback.
5. A successful mix clears the layers, owns one prepared recipe, and asks the
   UI to show a uniform prepared color.
6. Right Mouse takes the prepared recipe, closes the mixer immediately, and
   calls the player's `PotionTarget.receive_potion(recipe)`.
7. Left Mouse captures `PlayerCombatController.get_throw_origin()` and
   `get_throw_direction()`, takes the recipe, closes the mixer immediately,
   instances `PotionProjectile`, and calls `launch(...)`.
8. The projectile ignores the player's target, applies its recipe to the first
   accepting `PotionTarget`, or expires after its configured lifetime.

No animation event delays, owns, commits, or cancels potion use.

## Default Recipes

| Resource | Layers, any order | Effect |
| --- | --- | --- |
| `combat/potions/resources/HealthPotion.tres` | red, red, blue | Heal 30 |
| `combat/potions/resources/DamagePotion.tres` | green, green, blue | Damage 30 |

`PotionRecipeBook_Default.tres` lists both resources. To add a recipe, create a
valid `PotionRecipeData` resource with exactly three total layers and a
positive amount, then append it to that book. Extend `EffectType` and
`PotionTarget.receive_potion()` together when adding a new effect family.

## Input Actions

| Action | Default input | Owner |
| --- | --- | --- |
| `move_up`, `move_down`, `move_left`, `move_right` | W/S/A/D and arrows | `PlayerCombatController`, workshop actor |
| `toggle_mixer` | Tab | `PotionInput` |
| `add_red_reagent`, `add_green_reagent`, `add_blue_reagent` | 1/2/3 | `PotionInput` |
| `mix_potion` | Space | `PotionInput` |
| `drink_potion` | Right Mouse | `PotionInput` |
| `throw_potion` | Left Mouse | `PotionInput` |
| `remove_reagent` | Backspace | `PotionInput` |
| `clear_mixture` | C | `PotionInput` |
| `ui_cancel` | Escape | `PauseMenu` |

## Verification

Godot 4.7.2 on this Windows installation requires explicit `--scene` for
scene execution. The GUI-subsystem executable must be launched with an
explicit process wait so exit codes and complete output are observable.

### Import And Scene Smokes

```powershell
$godot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'

function Invoke-GodotWait([string]$arguments) {
	$psi = [System.Diagnostics.ProcessStartInfo]::new()
	$psi.FileName = $godot
	$psi.Arguments = $arguments
	$psi.WorkingDirectory = (Get-Location).Path
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$process = [System.Diagnostics.Process]::Start($psi)
	$stdoutTask = $process.StandardOutput.ReadToEndAsync()
	$stderrTask = $process.StandardError.ReadToEndAsync()
	$process.WaitForExit()
	Write-Output ($stdoutTask.Result.TrimEnd())
	Write-Output ($stderrTask.Result.TrimEnd())
	if ($process.ExitCode -ne 0) {
		throw "Godot exited $($process.ExitCode): $arguments"
	}
}

Invoke-GodotWait '--headless --editor --path . --quit'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --quit-after 120 --scene res://characters/player/PlayerModelWorkshop.tscn'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --quit-after 120 --scene res://combat/CombatScene.tscn'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --quit-after 120 --scene res://mainmenu/StartMenu.tscn'
```

Expected: each process exits `0`; no parse, scene, missing-resource, or
duplicate-UID diagnostics. Godot 4.7.2 may report an active MP3 playback/resource
during forced `--quit-after` cleanup of a music scene; this is distinct from a
missing-resource failure.

### Retained Test Scenes

Run each suite through the same `Invoke-GodotWait` helper:

```powershell
Invoke-GodotWait '--headless --fixed-fps 60 --path . --scene res://tests/PlayerModelTests.tscn'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --scene res://tests/PlayerModelWorkshopTests.tscn'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --scene res://tests/PlayerActorTests.tscn'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --scene res://tests/PotionDomainTests.tscn'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --scene res://tests/PotionProjectileCollisionTests.tscn'
Invoke-GodotWait '--headless --fixed-fps 60 --path . --scene res://tests/PotionUseTests.tscn'
```

Expected output:

- `PlayerModelTests: PASS (469 checks)`
- `PlayerModelWorkshopTests: PASS (41 checks)`
- `PlayerActorTests: PASS (18 checks)`
- `PotionDomainTests: PASS (20 tests)`
- `PotionProjectileCollisionTests: PASS (6 checks)`
- `PotionUseTests: PASS (34 checks)`

Every suite must exit `0`. Deliberate dependency-error diagnostics appear in
`PlayerModelTests` and `PotionDomainTests`; those messages are fixture
coverage, not suite failures.

### Manual Godot Checklist

1. Open `characters/player/PlayerModel.tscn`. Verify the 15 bones, geometric
   parts, both hand sockets, `AnimationPlayer`, and `AnimationTree` are
   directly editable.
2. Play `PlayerModelWorkshop.tscn` as the current scene. Exercise all eight
   movement directions, stop in every facing, collide with all four walls,
   and toggle debug bones.
3. Start New Game. Verify combat displays the compact model, the camera follows
   it, arena collision blocks movement, and the health bar follows.
4. Prepare red, red, blue and use Right Mouse. Verify healing is immediate.
5. Prepare green, green, blue and use Left Mouse. Verify a projectile launches
   immediately from the right hand and can hit Friend and Foe.
6. Throw into empty space and verify the projectile expires.
7. Open pause and settings, resume, and verify movement continues.
8. Resize to a smaller 16:9 window and verify the mixer and world remain usable.

## Change Guidelines

- Keep `PlayerModel` presentation-only; world movement, collision, camera, and
  health belong to `PlayerActor` and its actor components.
- Preserve the 15-bone hierarchy, authored four-facing clips, positive model
  scale, and stable socket IDs when replacing geometric parts with sprites.
- Keep immediate potion application in `PotionCombatController`; animation is
  visual feedback and must not own gameplay outcomes.
- Keep recipe matching in resource data and mixer code, not scene controllers
  or UI scripts.
- Keep health reusable and free of scene routing or victory decisions.
- Add new routed scenes through `SceneRegistryData` and `GameManager`.
- Keep developer workshops out of `project.godot` runtime routing.
- Add or update focused headless scene coverage when a public contract changes.
