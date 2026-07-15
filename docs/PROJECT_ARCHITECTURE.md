# Project Architecture

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
		  -> Player PotionTarget, or PotionProjectile
			  -> PotionTarget
				  -> HealthComponent
					  -> ActorHealthBar
```

Escape opens the reusable `ui/PauseMenu.tscn`. Main Menu routes through
`GameManager`; Quit routes through `GameManager.quit_game()`.

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
| `globals/` | Autoload services and reusable scene-level music declaration. |
| `globals/resources/` | Scene registry and project information resources. |
| `mainmenu/` | Main menu, settings overlay, version plaque, and alchemy decoration. |
| `ui/` | Reusable pause menu. |
| `tests/` | Dependency-free potion domain test scene. |
| `music/`, `sprites/`, `extra/` | Audio, images, fonts, and shaders. |

## Combat Scene Composition

`combat/CombatScene.tscn` retains the registered combat scene path. Its root
uses `PotionCombatController` and contains:

- `Arena/Player`: `PlayerActor.tscn`, starting at 70/100 health, using
  `sprites/Standard.png`, with movement and a following camera.
- `Arena/Friend`: `TargetActor.tscn`, starting at 50/100 health, using
  `sprites/Pointed.png`.
- `Arena/Foe`: `TargetActor.tscn`, starting at 100/100 health, using
  `sprites/Pushed.png`.
- `Arena/Projectiles`: owner for thrown potion instances.
- `Systems/PotionInput`: maps Input Map actions to typed signals.
- `Systems/PotionMixer`: owns layers and the prepared recipe.
- `UI/PotionMixerUI`: scene-backed flask and reagent controls.
- `UI/PauseMenu`: reusable pause/settings overlay.
- `LevelMusic`: scene-local request for `music/Combat.mp3`.

Actors remain present and targetable at zero health. Healing can raise them
above zero again. No component changes scene or decides victory/defeat.

## Combat Script Reference

### PotionCombatController

- File: `combat/PotionCombatController.gd`
- Responsibility: coordinate components; it does not own recipes, health,
  drawing, movement, or projectile travel.
- Exports: paths for input, mixer, mixer UI, player controller, player target,
  projectile owner, plus the projectile scene.
- Functions: `_ready()` resolves dependencies; `_has_valid_dependencies()`
  reports missing wiring; `_connect_signals()` connects component boundaries;
  request handlers enforce mixer state; `_finish_prepared_potion()` clears and
  hides the UI after successful use.

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
- Public functions: `get_throw_origin()`, `get_throw_direction()`.
- Callback: `_physics_process()` reads four movement actions and calls
  `move_and_slide()`.

### HealthComponent

- File: `combat/actors/HealthComponent.gd`
- Responsibility: own bounded health independently of actor presentation.
- Signals: `health_changed`, `depleted`.
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
8. Right Mouse applies the recipe to the Player `PotionTarget`.
9. Left Mouse validates a projectile launch toward the cursor, then consumes the
   prepared recipe. The projectile applies that recipe to the first Friend/Foe
   target it hits or expires after its lifetime.
10. Successful drink/throw clears and hides the mixer. C cancels a prepared
    potion and leaves an open empty mixer.

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

Expected output contains `PotionDomainTests: PASS (18 tests)` and exits with
code 0.

### Manual Godot Checklist

1. Open the project and confirm no missing script, class, or resource errors.
2. Run the main project. Confirm main-menu music plays once.
3. Change both settings sliders, leave settings, reopen it, and confirm values;
   restart the project and confirm `user://settings.cfg` restores them.
4. Press New Game. Confirm the ink transition completes and combat music
   crossfades without duplicate playback.
5. Move with WASD/arrows. Confirm the camera follows the Player.
6. Confirm visible health bars start at Player 70, Friend 50, Foe 100.
7. Press Tab. Confirm one flask and R/G/B controls appear at bottom center.
8. Add layers with both number keys and buttons. Confirm bottom-up bands, the
   three-layer limit, Backspace LIFO removal, and C clearing.
9. Close/reopen an unfinished mixer with Tab. Confirm layers are preserved.
10. Try fewer than three layers and an unknown combination such as red/green/
	blue. Press Space and confirm the flask flashes/shakes without clearing.
11. Mix red/red/blue in multiple orders. Confirm the flask becomes one liquid,
	reagent buttons hide, and Tab is ignored while prepared.
12. Right-click the health potion. Confirm Player heals by 30 within its cap and
	the mixer clears/hides.
13. Mix green/green/blue and left-click toward Friend, Foe, and empty space on
	separate attempts. Confirm either target can take 30 damage and misses
	expire.
14. Throw a health potion at both Friend and Foe. Confirm recipe effect, not
	target identity, decides healing.
15. Reduce an actor to zero and heal it. Confirm its health bar recovers and the
	scene does not transition.
16. Prepare a potion and press C. Confirm an empty mixer remains open.
17. Press Escape. Confirm movement freezes; Resume, Settings, Main Menu, and Quit
	behave correctly while paused.
18. Resize through smaller 16:9 windows. Confirm the mixer stays fully visible at
	bottom center and health/UI text does not overlap.

## Change Guidelines

- Keep changes small and reviewable.
- Prefer script/resource edits before changing scene structure.
- Do not rename autoloads, registered scenes, or important scene nodes without
  an explicit migration request.
- Keep `PotionCombatController` as a coordinator. Put state/rules in their owning
  components instead of growing a new all-purpose manager.
- Do not couple recipe matching to insertion order or actor identity.
- After each change, list changed files and provide focused manual Godot steps.
