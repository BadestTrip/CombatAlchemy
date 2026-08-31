# Compact Player Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one compact 15-bone `PlayerModel` the editable workshop model and active combat visual, preserve immediate potion gameplay, and delete every retired character-model pipeline.

**Architecture:** `characters/player/PlayerModel.tscn` owns skeleton, visuals, sockets, and directional locomotion. `combat/actors/PlayerActor.tscn` remains a thin gameplay wrapper; `PlayerCombatController` forwards actual velocity to the model and exposes a right-hand projectile origin. `PotionCombatController` consumes prepared recipes synchronously, with no animation-event adapter.

**Tech Stack:** Godot 4.7.1, GDScript, `Skeleton2D`, `AnimationPlayer`, `AnimationTree`, scene-backed tests, PowerShell, Git.

**Spec:** `docs/superpowers/specs/2026-08-23-compact-player-consolidation-design.md`

## Global Constraints

- Preserve the existing scene path `res://combat/CombatScene.tscn` and gameplay wrapper path `res://combat/actors/PlayerActor.tscn`.
- Preserve all current user-authored compact-model and animation-library edits, including the `new_walking` clip, whether or not that clip is connected to the active locomotion tree.
- Keep separate authored `front`, `back`, `side_left`, and `side_right` animation families; never mirror `FacingRoot.scale.x`.
- Do not add action animations, IK, root motion, or new Input Map actions.
- Keep camera framing, health values, potion recipes, targeting, pause, menu, settings, music, and unrelated assets.
- Use the user-authored compact wrapper geometry when merging gameplay composition: capsule body collision radius `31`, height `120`, at `(0, -22)`; target radius `42`; camera position `(0, -55)`, zoom `(4, 4)`, smoothing speed `8`; health `70`; health-bar offsets `-70, -166, 70, -118`.
- Retain every image embedded by `docs/STYLE_AND_VISION.md` or `docs/ART_REFERENCE_INDEX.md`. Delete the researcher atlases and only development images proven unreferenced by active documentation.
- Preserve unrelated working-tree changes. Stage only task-owned paths at each commit.
- Historical specifications and plans may name deleted files. Stale-reference scans exclude `docs/superpowers/` and inspect active code, scenes, resources, and user-facing documentation.

## File Map

### Create

- `characters/player/PlayerModel.tscn`: canonical editable compact skeleton and visual workshop model.
- `characters/player/PlayerModel.gd`: directional locomotion facade and socket lookup.
- `characters/player/PlayerLocomotionLibrary.tres`: canonical external idle/walk library.
- `characters/player/PlayerModelWorkshop.tscn`: isolated one-model movement room.
- `characters/player/PlayerModelWorkshop.gd`: workshop HUD and bone-toggle synchronization.
- `characters/player/PlayerModelWorkshopActor.gd`: workshop-only movement and model forwarding.
- `characters/player/README.md`: bone, sprite, animation, and verification guide.
- `tests/PlayerModelTests.gd` and `.tscn`: canonical model structure, resources, API, and behavior.
- `tests/PlayerModelWorkshopTests.gd` and `.tscn`: isolated workshop composition and startup.
- `tests/PlayerActorTests.gd` and `.tscn`: active gameplay wrapper and movement integration.
- `tests/PotionUseTests.gd` and `.tscn`: synchronous drink and throw integration.

### Modify

- `combat/actors/PlayerCombatController.gd`: validate the model, forward velocity, resolve the right-hand throw origin.
- `combat/actors/PlayerActor.tscn`: replace researcher rig and animation adapter with canonical compact model.
- `combat/PotionCombatController.gd`: remove event timing and apply/launch immediately.
- `combat/CombatScene.tscn`: remove the animation-controller path.
- `docs/PROJECT_ARCHITECTURE.md`: replace retired animation architecture with the compact player pipeline.
- `docs/STYLE_AND_VISION.md`: point technical character references to the compact model and workshop.
- `docs/ART_REFERENCE_INDEX.md`: retain visual references while removing claims that researcher atlases are active.

### Delete

- `characters/animation/`
- `experiments/character_animation/`
- `experiments/directional_character_animation/`
- `experiments/compact_directional_character_animation/`
- `combat/actors/PlayerAnimationController.gd` and `.gd.uid`
- `combat/actors/HeldPotionFlask.gd`, `.gd.uid`, and `.tscn`
- `combat/actors/PlayerModel.tscn`
- `sprites/characters/researcher/`
- `tests/CharacterAnimationRigTests.*`
- `tests/CompactDirectionalAnimationRigTests.*`
- `tests/DirectionalAnimationRigTests.*`
- `tests/PlayerAnimationControllerTests.*`
- `tests/PotionActionTimingTests.*`
- `tests/ResearcherMirroringTests.*`

---

### Task 1: Promote The Canonical Compact Player Model

**Files:**
- Create: `tests/PlayerModelTests.gd`
- Create: `tests/PlayerModelTests.tscn`
- Create: `characters/player/PlayerModel.gd`
- Create: `characters/player/PlayerModel.tscn`
- Create: `characters/player/PlayerLocomotionLibrary.tres`
- Source: `experiments/compact_directional_character_animation/PlayerModel.tscn`
- Source: `experiments/compact_directional_character_animation/CompactDirectionalHumanoidRig.gd`
- Source: `experiments/compact_directional_character_animation/CompactDirectionalHumanoidAnimationLibrary.tres`

**Interfaces:**
- Consumes: the approved user-authored compact scene and animation resources.
- Produces: `PlayerModel.set_motion()`, `set_facing_direction()`, `reset_to_idle()`, `set_playback_speed()`, `set_debug_bones_visible()`, `get_facing()`, `get_locomotion_state()`, and `get_socket()`.

- [ ] **Step 1: Write the canonical-model test against production paths**

Create `tests/PlayerModelTests.tscn`:

```text
[gd_scene format=3]

[ext_resource type="Script" path="res://tests/PlayerModelTests.gd" id="1_test"]

[node name="PlayerModelTests" type="Node"]
script = ExtResource("1_test")
```

Base `tests/PlayerModelTests.gd` on the existing compact-rig test, but use these constants and contract additions:

```gdscript
extends Node

const MODEL_SCENE_PATH := "res://characters/player/PlayerModel.tscn"
const MODEL_SCRIPT_PATH := "res://characters/player/PlayerModel.gd"
const ANIMATION_LIBRARY_PATH := "res://characters/player/PlayerLocomotionLibrary.tres"
const REQUIRED_METHODS: Array[StringName] = [
	&"set_motion",
	&"set_facing_direction",
	&"reset_to_idle",
	&"set_playback_speed",
	&"set_debug_bones_visible",
	&"get_facing",
	&"get_locomotion_state",
	&"get_socket",
]
```

Retain the existing checks for the exact 15-bone hierarchy, `100x116` visual bounds, rest transforms, four idle and four walk clips, nine gait keys, planted feet, synchronized `0.10` direction transitions, `0.12` idle/walk blending, hysteresis, speed clamping, and positive `FacingRoot.scale.x`. Add:

```gdscript
var left_socket := model.call(&"get_socket", &"hand_left") as Marker2D
var right_socket := model.call(&"get_socket", &"hand_right") as Marker2D
_expect(left_socket != null and left_socket.name == &"HandSocket_L", "hand_left resolves the authored left socket")
_expect(right_socket != null and right_socket.name == &"HandSocket_R", "hand_right resolves the authored right socket")
_expect(model.call(&"get_socket", &"unknown") == null, "unknown socket ids return null")
```

- [ ] **Step 2: Run the test and verify the production scene is missing**

Run:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --fixed-fps 60 --path . res://tests/PlayerModelTests.tscn
```

Expected: nonzero exit and a failed check for `res://characters/player/PlayerModel.tscn`.

- [ ] **Step 3: Copy the approved compact resources into production ownership**

Create `characters/player/`. Copy the full current contents, not the committed baseline:

```text
experiments/compact_directional_character_animation/PlayerModel.tscn
  -> characters/player/PlayerModel.tscn
experiments/compact_directional_character_animation/CompactDirectionalHumanoidRig.gd
  -> characters/player/PlayerModel.gd
experiments/compact_directional_character_animation/CompactDirectionalHumanoidAnimationLibrary.tres
  -> characters/player/PlayerLocomotionLibrary.tres
```

In `PlayerModel.tscn`, keep the root name `PlayerModelSkeleton`, all current visual edits, and all node unique IDs. Change only external paths:

```text
res://characters/player/PlayerModel.gd
res://characters/player/PlayerLocomotionLibrary.tres
```

Remove copied resource UID declarations from the new scene/library and copied UID attributes on their external references while the source copies coexist. Godot may generate new production UIDs; do not duplicate the experimental UIDs.

- [ ] **Step 4: Add stable socket lookup to `PlayerModel.gd`**

Add constants and the public method:

```gdscript
const HAND_LEFT_SOCKET_PATH := ^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_L/Forearm_L/Hand_L/HandSocket_L"
const HAND_RIGHT_SOCKET_PATH := ^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_R/Forearm_R/Hand_R/HandSocket_R"

func get_socket(socket_id: StringName) -> Marker2D:
	match socket_id:
		&"hand_left":
			return get_node_or_null(HAND_LEFT_SOCKET_PATH) as Marker2D
		&"hand_right":
			return get_node_or_null(HAND_RIGHT_SOCKET_PATH) as Marker2D
		_:
			return null
```

Extend dependency validation so missing hand sockets are reported as `HandSocket_L` or `HandSocket_R` and disable playback consistently with other missing rig dependencies.

- [ ] **Step 5: Run the canonical model test**

Run the Task 1 test command again.

Expected: `PlayerModelTests: PASS` and exit code `0`. The exact check count is allowed to change as assertions are consolidated.

- [ ] **Step 6: Commit the canonical model**

```powershell
git add -- characters/player/PlayerModel.gd characters/player/PlayerModel.tscn characters/player/PlayerLocomotionLibrary.tres tests/PlayerModelTests.gd tests/PlayerModelTests.tscn
git commit -m "Feat: promote compact player model"
```

---

### Task 2: Replace The Comparison Lab With One Player Workshop

**Files:**
- Create: `characters/player/PlayerModelWorkshopActor.gd`
- Create: `characters/player/PlayerModelWorkshop.gd`
- Create: `characters/player/PlayerModelWorkshop.tscn`
- Create: `characters/player/README.md`
- Create: `tests/PlayerModelWorkshopTests.gd`
- Create: `tests/PlayerModelWorkshopTests.tscn`

**Interfaces:**
- Consumes: `PlayerModel.set_motion()`, model state signals, and debug visibility.
- Produces: one isolated Play Current Scene workshop with no runtime registration.

- [ ] **Step 1: Write the workshop composition test**

Create a test scene with the same two-node format as Task 1 and implement checks that load `res://characters/player/PlayerModelWorkshop.tscn`, instantiate it, and assert:

```gdscript
const WORKSHOP_PATH := "res://characters/player/PlayerModelWorkshop.tscn"

var actor := workshop.get_node_or_null(^"WorkshopActor") as CharacterBody2D
var model := workshop.get_node_or_null(^"WorkshopActor/PlayerModel")
var camera := workshop.get_node_or_null(^"WorkshopActor/Camera2D") as Camera2D
var collision := workshop.get_node_or_null(^"WorkshopActor/CollisionShape2D") as CollisionShape2D
var facing_label := workshop.get_node_or_null(^"HUD/StatusPanel/StatusRow/FacingValue") as Label
var locomotion_label := workshop.get_node_or_null(^"HUD/StatusPanel/StatusRow/LocomotionValue") as Label
var bones_toggle := workshop.get_node_or_null(^"HUD/StatusPanel/StatusRow/BonesToggle") as CheckButton

_expect(actor != null, "workshop has one movement owner")
_expect(model != null and model.scene_file_path == "res://characters/player/PlayerModel.tscn", "workshop instances the canonical model")
_expect(camera != null and not camera.position_smoothing_enabled, "workshop camera follows without smoothing")
_expect(collision != null, "workshop actor has one gameplay-sized collision")
_expect(facing_label != null and locomotion_label != null and bones_toggle != null, "workshop exposes only compact state controls")
```

Also assert four wall bodies, camera limits `0, 0, 3200, 1800`, no `PlayerActor`, no potion nodes, and no reference from `project.godot` to `PlayerModelWorkshop`.

- [ ] **Step 2: Run the workshop test and verify it fails**

Run:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --fixed-fps 60 --path . res://tests/PlayerModelWorkshopTests.tscn
```

Expected: nonzero exit because the workshop scene does not exist.

- [ ] **Step 3: Implement the workshop-only movement owner**

Create `PlayerModelWorkshopActor.gd`:

```gdscript
extends CharacterBody2D

@export_range(0.0, 1000.0, 1.0) var movement_speed := 220.0
@export var player_model_path: NodePath = ^"PlayerModel"

@onready var _player_model := get_node_or_null(player_model_path)

func _ready() -> void:
	if _player_model == null or not _player_model.has_method(&"set_motion"):
		push_error("PlayerModelWorkshopActor requires a PlayerModel with set_motion().")
		set_physics_process(false)

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction.normalized() * movement_speed if not direction.is_zero_approx() else Vector2.ZERO
	move_and_slide()
	_player_model.call(&"set_motion", velocity)
```

- [ ] **Step 4: Implement the workshop HUD controller**

Create `PlayerModelWorkshop.gd` with typed node lookups. Validate the model, two labels, and toggle; connect `facing_changed`, `locomotion_changed`, and `toggled`; initialize labels from getters; call `set_debug_bones_visible(is_pressed)` from the toggle. Do not handle gameplay or bones directly.

- [ ] **Step 5: Author `PlayerModelWorkshop.tscn`**

Use this scene ownership tree:

```text
PlayerModelWorkshop (Node2D, PlayerModelWorkshop.gd)
|- RoomFloor (Polygon2D, 3200x1800)
|- RoomBorder (Line2D)
|- Walls (Node2D)
|  |- NorthWall/SouthWall/WestWall/EastWall (StaticBody2D + CollisionShape2D)
|- WorkshopActor (CharacterBody2D, PlayerModelWorkshopActor.gd, position 1600,900)
|  |- PlayerModel (instance of canonical PlayerModel.tscn)
|  |- CollisionShape2D (CapsuleShape2D radius 31, height 120, position 0,-22)
|  `- Camera2D (limits 0,0,3200,1800; smoothing disabled)
`- HUD (CanvasLayer)
   `- StatusPanel/StatusRow
      |- LocomotionCaption + LocomotionValue
      |- FacingCaption + FacingValue
      `- BonesToggle (CheckButton, off by default)
```

Keep the HUD compact and use the existing comparison lab's restrained neutral colors. Do not add instructions, action buttons, or decorative cards.

- [ ] **Step 6: Write the workshop README**

Document the exact 15-bone tree, stable socket IDs, four-facing clip names, no-mirroring rule, scene ownership, how to replace each `Polygon2D` with a sprite part, pivots at local joint zero, overlap at shoulders/elbows/wrists/hips/knees/ankles, and Play Current Scene checks for all eight movement directions.

- [ ] **Step 7: Run the model and workshop tests**

Run both Task 1 and Task 2 commands.

Expected: both print `PASS` and exit `0`.

- [ ] **Step 8: Commit the workshop**

```powershell
git add -- characters/player/PlayerModelWorkshopActor.gd characters/player/PlayerModelWorkshop.gd characters/player/PlayerModelWorkshop.tscn characters/player/README.md tests/PlayerModelWorkshopTests.gd tests/PlayerModelWorkshopTests.tscn
git commit -m "Feat: add compact player workshop"
```

---

### Task 3: Switch The Active Player To The Canonical Model

**Files:**
- Create: `tests/PlayerActorTests.gd`
- Create: `tests/PlayerActorTests.tscn`
- Modify: `combat/actors/PlayerCombatController.gd`
- Modify: `combat/actors/PlayerActor.tscn`

**Interfaces:**
- Consumes: canonical model locomotion and `get_socket(&"hand_right")`.
- Produces: active movement forwarding plus existing `get_throw_origin()` and `get_throw_direction()` gameplay API.

- [ ] **Step 1: Write the active-player integration test**

Load `res://combat/actors/PlayerActor.tscn` and assert the following exact composition:

```gdscript
var player := player_scene.instantiate() as PlayerCombatController
var model := player.get_node_or_null(^"PlayerModel")
var camera := player.get_node_or_null(^"Camera2D") as Camera2D
var body_collision := player.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
var health := player.get_node_or_null(^"HealthComponent") as HealthComponent
var target := player.get_node_or_null(^"PotionTarget") as PotionTarget
var health_bar := player.get_node_or_null(^"ActorHealthBar") as Control

_expect(model != null and model.scene_file_path == "res://characters/player/PlayerModel.tscn", "PlayerActor instances the canonical model")
_expect(player.get_node_or_null(^"PlayerAnimationController") == null, "PlayerActor has no retired action adapter")
_expect(camera != null and camera.zoom.is_equal_approx(Vector2(4, 4)), "camera framing is retained")
_expect(body_collision != null and body_collision.shape is CapsuleShape2D, "compact capsule collision is retained")
_expect(health != null and health.current_health == 70, "player health is retained")
_expect(target != null and health_bar != null, "potion target and health bar are retained")
```

Add the Player to the tree, press `move_right`, await two physics frames, release it, and assert `velocity.x > 0`, model state is `walk/side_right`, then after one more physics frame model state is `idle/side_right`. Repeat with left and verify `FacingRoot.scale.x > 0`.

Set the actor to a known global position. Assert `get_throw_origin()` equals the global position of `get_socket(&"hand_right")`. Instantiate a second controller without a model and assert its throw-origin fallback equals its own global position.

- [ ] **Step 2: Run the active-player test and verify it fails**

Run:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --fixed-fps 60 --path . res://tests/PlayerActorTests.tscn
```

Expected: nonzero exit because `PlayerActor` still instances the researcher rig and action adapter.

- [ ] **Step 3: Make `PlayerCombatController` the locomotion bridge**

Add:

```gdscript
@export var player_model_path: NodePath = ^"PlayerModel"
@onready var _player_model := get_node_or_null(player_model_path)

func _ready() -> void:
	if _player_model == null or not _player_model.has_method(&"set_motion"):
		push_error("PlayerCombatController requires a PlayerModel with set_motion().")
		set_physics_process(false)
```

After `move_and_slide()`, call `_player_model.call(&"set_motion", velocity)` and continue emitting `movement_changed(velocity)` for observability. Keep movement-lock methods for API compatibility, even though immediate potion use no longer locks movement.

Rewrite `get_throw_origin()`:

```gdscript
func get_throw_origin() -> Vector2:
	if _player_model != null and _player_model.has_method(&"get_socket"):
		var socket := _player_model.call(&"get_socket", &"hand_right") as Marker2D
		if socket != null:
			return socket.global_position
	return global_position
```

Keep `get_throw_direction()` normalized and based on `get_throw_origin()`.

- [ ] **Step 4: Merge the user-authored compact wrapper into `PlayerActor.tscn`**

Replace `ResearcherCutoutRig` with one `PlayerModel` instance. Remove `PlayerAnimationController`. Use the compact wrapper's capsule and all exact values listed in Global Constraints. Retain the root scene UID and root name `PlayerActor` so `CombatScene` needs no player-scene path change.

- [ ] **Step 5: Run Player model, workshop, and actor tests**

Run the Task 1, Task 2, and Task 3 commands.

Expected: all pass and exit `0`.

- [ ] **Step 6: Commit active player integration**

```powershell
git add -- combat/actors/PlayerCombatController.gd combat/actors/PlayerActor.tscn tests/PlayerActorTests.gd tests/PlayerActorTests.tscn
git commit -m "Feat: switch combat to compact player"
```

---

### Task 4: Replace Event-Timed Potion Actions With Immediate Use

**Files:**
- Create: `tests/PotionUseTests.gd`
- Create: `tests/PotionUseTests.tscn`
- Modify: `combat/PotionCombatController.gd`
- Modify: `combat/CombatScene.tscn`
- Delete: `tests/PotionActionTimingTests.gd`
- Delete: `tests/PotionActionTimingTests.gd.uid`
- Delete: `tests/PotionActionTimingTests.tscn`

**Interfaces:**
- Consumes: `PotionMixer.take_prepared_recipe()`, `PotionTarget.receive_potion()`, `PlayerCombatController.get_throw_origin()`, and `get_throw_direction()`.
- Produces: synchronous right-click drink and left-click throw with no pending action state.

- [ ] **Step 1: Write immediate potion-use tests**

Start from the existing `PotionActionTimingTests` scene setup, rename the test to `PotionUseTests`, and remove adapter/event assertions. Test synchronous drink:

```gdscript
health.current_health = 40
_prepare_health_potion(mixer)
potion_input.drink_requested.emit()
_expect(health.current_health == 70, "drink applies the health recipe during the input signal")
_expect(not mixer.has_prepared_potion(), "drink consumes the prepared recipe once")
_expect(not mixer_ui.visible, "drink closes the mixer immediately")
potion_input.drink_requested.emit()
_expect(health.current_health == 70, "a second drink input cannot reuse the consumed recipe")
```

Test synchronous throw before advancing a frame:

```gdscript
_prepare_damage_potion(mixer)
var origin := player.get_throw_origin()
var direction := player.get_throw_direction()
var before := projectiles.get_child_count()
potion_input.throw_requested.emit()
_expect(projectiles.get_child_count() == before + 1, "throw spawns one projectile during the input signal")
var projectile := projectiles.get_child(projectiles.get_child_count() - 1) as PotionProjectile
_expect(projectile.global_position.is_equal_approx(origin), "throw starts at the right-hand socket")
_expect((projectile.get("_direction") as Vector2).is_equal_approx(direction), "throw captures current mouse aim")
_expect(not mixer.has_prepared_potion() and not mixer_ui.visible, "throw consumes the recipe and closes the mixer")
```

Also verify invalid no-recipe input changes nothing, `CombatScene` contains no `PlayerAnimationController`, and taking damage has no effect on mixer input or locomotion ownership.

- [ ] **Step 2: Run the new test and verify the old controller contract fails**

Run:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --fixed-fps 60 --path . res://tests/PotionUseTests.tscn
```

Expected: nonzero exit because the current controller waits for animation events.

- [ ] **Step 3: Simplify `PotionCombatController` dependencies and state**

Delete `ACTION_*`, `EVENT_*`, `player_animation_controller_path`, `_player_animation_controller`, `_pending_recipe`, `_pending_action`, animation API validation, action signal connections, busy guards, action-event handlers, and pending-action helpers.

Keep validation for input, mixer, UI, player controller, player target, projectile parent, and projectile scene.

- [ ] **Step 4: Implement immediate drink**

```gdscript
func _on_drink_requested() -> void:
	if not _potion_mixer.has_prepared_potion():
		return
	var recipe := _potion_mixer.take_prepared_recipe()
	if recipe == null:
		return
	_close_mixer_after_use()
	if not _player_potion_target.receive_potion(recipe):
		push_warning("Player rejected the prepared drink recipe.")
```

- [ ] **Step 5: Implement immediate throw**

Instantiate and validate the projectile before consuming the recipe. Then capture origin/direction, take the recipe, close the mixer, add the projectile, and launch:

```gdscript
func _on_throw_requested() -> void:
	if not _potion_mixer.has_prepared_potion() or projectile_scene == null:
		return
	if not is_instance_valid(_projectiles_parent) or not is_instance_valid(_player_combat_controller):
		return
	var projectile := projectile_scene.instantiate() as PotionProjectile
	if projectile == null:
		push_warning("Prepared throw could not instantiate PotionProjectile.")
		return
	var origin := _player_combat_controller.get_throw_origin()
	var direction := _player_combat_controller.get_throw_direction()
	var recipe := _potion_mixer.take_prepared_recipe()
	if recipe == null:
		projectile.free()
		return
	_close_mixer_after_use()
	_projectiles_parent.add_child(projectile)
	if not projectile.launch(recipe, origin, direction, _player_potion_target):
		push_warning("Prepared throw could not launch PotionProjectile.")
```

Rename `_close_mixer_for_action()` to `_close_mixer_after_use()`. Leave Tab, reagent, mix, remove, and clear behavior unchanged except for removal of obsolete busy checks.

- [ ] **Step 6: Remove animation wiring from `CombatScene.tscn`**

Delete only:

```text
player_animation_controller_path = NodePath("Arena/Player/PlayerAnimationController")
```

Do not alter the other controller paths or UI composition.

- [ ] **Step 7: Run immediate-use and potion regressions**

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --fixed-fps 60 --path . res://tests/PotionUseTests.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --fixed-fps 60 --path . res://tests/PotionDomainTests.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --fixed-fps 60 --path . res://tests/PotionProjectileCollisionTests.tscn
```

Expected: all three pass and exit `0`.

- [ ] **Step 8: Commit immediate potion use**

```powershell
git add -- combat/PotionCombatController.gd combat/CombatScene.tscn tests/PotionUseTests.gd tests/PotionUseTests.tscn tests/PotionActionTimingTests.gd tests/PotionActionTimingTests.gd.uid tests/PotionActionTimingTests.tscn
git commit -m "Feat: use prepared potions immediately"
```

---

### Task 5: Delete Retired Models, Tests, And Atlases

**Files:**
- Delete: every path listed in the plan's Delete section that remains after Task 4.
- Modify: none outside deletion scope.

**Interfaces:**
- Consumes: passing canonical model, active Player, and potion-use replacements.
- Produces: one remaining player-model pipeline and no stale runtime references.

- [ ] **Step 1: Prove replacements pass immediately before deletion**

Run `PlayerModelTests`, `PlayerModelWorkshopTests`, `PlayerActorTests`, and `PotionUseTests`.

Expected: all pass and exit `0`.

- [ ] **Step 2: Delete retired animation code and scenes**

Remove these complete directories:

```text
characters/animation/
experiments/character_animation/
experiments/directional_character_animation/
experiments/compact_directional_character_animation/
sprites/characters/researcher/
```

Remove:

```text
combat/actors/PlayerAnimationController.gd
combat/actors/PlayerAnimationController.gd.uid
combat/actors/HeldPotionFlask.gd
combat/actors/HeldPotionFlask.gd.uid
combat/actors/HeldPotionFlask.tscn
combat/actors/PlayerModel.tscn
```

The canonical `characters/player/` files must already exist and pass before this step.

- [ ] **Step 3: Delete superseded tests**

Remove all `.gd`, `.gd.uid`, and `.tscn` files for:

```text
CharacterAnimationRigTests
CompactDirectionalAnimationRigTests
DirectionalAnimationRigTests
PlayerAnimationControllerTests
ResearcherMirroringTests
```

`PotionActionTimingTests` was replaced in Task 4 and must already be absent.

- [ ] **Step 4: Verify image retention and deletion**

Confirm these are absent:

```text
sprites/characters/researcher/researcher_core.png
sprites/characters/researcher/researcher_arms.png
sprites/characters/researcher/researcher_legs.png
sprites/characters/researcher/researcher_coat.png
```

Scan Markdown image targets in `docs/STYLE_AND_VISION.md` and `docs/ART_REFERENCE_INDEX.md`; retain all `ART_REF_G01` through `G06` and `ART_REF_S01` through `S05` because the active art index embeds them.

- [ ] **Step 5: Run stale runtime-reference checks**

```powershell
rg -n "HumanoidCutoutRig|ResearcherCutoutRig|PlayerAnimationController|HeldPotionFlask|DirectionalHumanoidRig|CompactDirectionalHumanoidRig|experiments/(character_animation|directional_character_animation|compact_directional_character_animation)|researcher_(core|arms|legs|coat)" characters combat tests project.godot --glob '*.gd' --glob '*.tscn' --glob '*.tres'
```

Expected: no matches. Do not include `docs/superpowers/` in this assertion because the approved historical spec and plan name deleted paths.

- [ ] **Step 6: Run all retained automated tests**

Run:

```powershell
$godot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godot --headless --fixed-fps 60 --path . res://tests/PlayerModelTests.tscn
& $godot --headless --fixed-fps 60 --path . res://tests/PlayerModelWorkshopTests.tscn
& $godot --headless --fixed-fps 60 --path . res://tests/PlayerActorTests.tscn
& $godot --headless --fixed-fps 60 --path . res://tests/PotionUseTests.tscn
& $godot --headless --fixed-fps 60 --path . res://tests/PotionDomainTests.tscn
& $godot --headless --fixed-fps 60 --path . res://tests/PotionProjectileCollisionTests.tscn
```

Expected: every command prints `PASS` and exits `0`.

- [ ] **Step 7: Commit destructive cleanup separately**

Review `git status --short` before staging. Stage only the deleted paths above, then:

```powershell
git commit -m "Feat: remove retired character models"
```

---

### Task 6: Rewrite Active Documentation And Complete Verification

**Files:**
- Modify: `docs/PROJECT_ARCHITECTURE.md`
- Modify: `docs/STYLE_AND_VISION.md`
- Modify: `docs/ART_REFERENCE_INDEX.md`
- Modify: `characters/player/README.md` only if verification exposes omissions.

**Interfaces:**
- Consumes: final retained file tree and passing tests.
- Produces: accurate onboarding and art references with no links to deleted implementation files.

- [ ] **Step 1: Rewrite architecture ownership and flow**

Remove sections for generic humanoid, researcher skin, original directional lab, compact comparison lab, `PlayerAnimationController`, held flask, and event-timing tests. Document:

```text
CombatScene
  -> PlayerActor (world movement, camera, collision, health)
      -> PlayerModel (15-bone visuals, four-facing idle/walk, sockets)
  -> PotionCombatController
      -> immediate drink: PotionTarget.receive_potion(recipe)
      -> immediate throw: PlayerCombatController origin/direction -> PotionProjectile.launch(...)

Play Current Scene
  -> characters/player/PlayerModelWorkshop.tscn
```

List every retained script with responsibility, dependencies, signals, exports, and public methods. Replace test commands and expected outputs with the six retained test scenes from Task 5.

- [ ] **Step 2: Update style and art-reference technical notes**

In `STYLE_AND_VISION.md`, keep G02 and G06 as visual targets. Replace active technical references to `HumanoidCutoutRig`, `ResearcherCutoutRig`, and the researcher atlas README with `characters/player/PlayerModel.tscn` and `characters/player/README.md`.

In `ART_REFERENCE_INDEX.md`, replace the claim that `ResearcherCutoutRig.tscn` currently uses 21 atlas regions with a statement that G06 is retained as costume/silhouette reference while the active compact workshop uses geometric placeholders pending new directional sprite parts.

- [ ] **Step 3: Validate active documentation links and image paths**

```powershell
rg -n "characters/animation|experiments/character_animation|experiments/directional_character_animation|experiments/compact_directional_character_animation|PlayerAnimationController|HeldPotionFlask|researcher_(core|arms|legs|coat)" docs/PROJECT_ARCHITECTURE.md docs/STYLE_AND_VISION.md docs/ART_REFERENCE_INDEX.md characters/player/README.md
```

Expected: no matches.

Confirm every relative image path embedded with Markdown syntax in `STYLE_AND_VISION.md` and `ART_REFERENCE_INDEX.md` resolves to an existing local file.

- [ ] **Step 4: Validate all Godot resource paths**

Run a project import and parse smoke test:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --editor --path . --quit
```

Expected: exit `0`, no parse errors, no missing `res://` resources, and no duplicate resource UID warnings.

- [ ] **Step 5: Run scene smoke tests**

```powershell
$godot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godot --headless --fixed-fps 60 --path . --quit-after 120 res://characters/player/PlayerModelWorkshop.tscn
& $godot --headless --fixed-fps 60 --path . --quit-after 120 res://combat/CombatScene.tscn
& $godot --headless --fixed-fps 60 --path . --quit-after 120
```

Expected: all exit `0` without script, scene, or missing-resource errors.

- [ ] **Step 6: Run final static checks**

```powershell
git diff --check
rg -n "drink_commit|throw_release|action_interrupted|action_finished|request_potion_action" characters combat tests project.godot --glob '*.gd' --glob '*.tscn' --glob '*.tres'
git status --short
```

Expected: `git diff --check` is clean; event/action scan has no matches; status contains only intentional task files plus preserved unrelated user changes.

- [ ] **Step 7: Perform manual Godot verification**

1. Open `characters/player/PlayerModel.tscn`; verify bones, placeholder parts, sockets, `AnimationPlayer`, and `AnimationTree` are directly editable.
2. Play `PlayerModelWorkshop.tscn`; test all eight movement directions, stop in every facing, and toggle debug bones.
3. Start New Game; verify combat displays the compact model and the camera follows it.
4. Test movement against arena collision and verify the health bar follows.
5. Prepare `red, red, blue`; Right Mouse applies healing immediately.
6. Prepare `green, green, blue`; Left Mouse immediately throws from the right hand at Friend and Foe.
7. Throw into empty space and verify expiry.
8. Open pause and settings, resume, and verify movement continues correctly.
9. Resize to a smaller 16:9 window and verify the mixer and world remain usable.

- [ ] **Step 8: Commit documentation**

```powershell
git add -- docs/PROJECT_ARCHITECTURE.md docs/STYLE_AND_VISION.md docs/ART_REFERENCE_INDEX.md characters/player/README.md
git commit -m "Feat: document compact player architecture"
```

## Completion Report

Report:

- Canonical model, workshop, active-player, and immediate-potion files changed.
- Retired directories, tests, and researcher atlases deleted.
- Automated test results and Godot import/smoke-test results.
- Any pre-existing unrelated worktree changes left untouched.
- Manual Godot steps for movement, facing, potion use, pause, and resizing.
