extends Node

# Responsibility: Verify that CombatScene commits prepared potions at authored player events.

const COMBAT_SCENE_PATH := "res://combat/CombatScene.tscn"
const FRAME_RATE := 60.0

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("PotionActionTimingTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("PotionActionTimingTests: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _run_tests() -> void:
	var combat_scene := load(COMBAT_SCENE_PATH) as PackedScene
	_expect(combat_scene != null, "CombatScene exists and parses")
	if combat_scene == null:
		return
	var combat := combat_scene.instantiate()
	_expect(combat != null, "CombatScene instantiates")
	if combat == null:
		return
	var level_music := combat.get_node_or_null(^"LevelMusic")
	if level_music != null:
		level_music.free()
	add_child(combat)
	await get_tree().process_frame

	var potion_input := combat.get_node_or_null(^"Systems/PotionInput") as PotionInput
	var mixer := combat.get_node_or_null(^"Systems/PotionMixer") as PotionMixer
	var mixer_ui := combat.get_node_or_null(^"UI/PotionMixerUI") as Control
	var player := combat.get_node_or_null(^"Arena/Player") as PlayerCombatController
	var health := combat.get_node_or_null(^"Arena/Player/HealthComponent") as HealthComponent
	var adapter := combat.get_node_or_null(^"Arena/Player/PlayerAnimationController")
	var projectiles := combat.get_node_or_null(^"Arena/Projectiles") as Node2D
	_expect(potion_input != null, "CombatScene exposes PotionInput")
	_expect(mixer != null, "CombatScene exposes PotionMixer")
	_expect(mixer_ui != null, "CombatScene exposes PotionMixerUI")
	_expect(player != null, "CombatScene exposes the Player controller")
	_expect(health != null, "CombatScene exposes player health")
	_expect(adapter != null, "CombatScene exposes PlayerAnimationController")
	_expect(projectiles != null, "CombatScene exposes the projectile owner")
	if (
		potion_input == null
		or mixer == null
		or mixer_ui == null
		or player == null
		or health == null
		or adapter == null
		or projectiles == null
	):
		combat.queue_free()
		return

	health.current_health = 40
	_prepare_health_potion(mixer)
	_expect(mixer_ui.visible, "prepared potion is visible before drinking")
	potion_input.drink_requested.emit()
	_expect(health.current_health == 40, "drink does not heal on input")
	_expect(not mixer.has_prepared_potion(), "accepted drink reserves the prepared recipe")
	_expect(adapter.call(&"is_busy") as bool, "accepted drink starts the authored action")
	_expect(not mixer_ui.visible, "accepted drink closes the mixer UI")
	potion_input.mixer_toggle_requested.emit()
	potion_input.reagent_requested.emit(PotionReagent.GREEN)
	potion_input.clear_mixture_requested.emit()
	_expect(not mixer_ui.visible and mixer.get_layers().is_empty(), "mixer input stays blocked during drink")
	adapter.emit_signal(&"action_event", &"throw_release", Vector2.RIGHT)
	_expect(health.current_health == 40, "mismatched action event cannot apply the reserved drink")
	await _advance(0.45)
	_expect(health.current_health == 40, "drink remains unapplied before drink_commit")
	await _advance(0.25)
	_expect(health.current_health == 70, "drink_commit applies the reserved health potion once")
	adapter.emit_signal(&"action_event", &"drink_commit", Vector2.ZERO)
	_expect(health.current_health == 70, "duplicate drink_commit cannot apply the potion twice")
	_expect(await _wait_until_not_busy(adapter, 0.8), "drink action finishes after commit")

	_prepare_damage_potion(mixer)
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	Input.warp_mouse(viewport_center + Vector2(300.0, 0.0))
	await get_tree().process_frame
	var captured_direction := player.get_throw_direction()
	var throw_release_origins: Array[Vector2] = []
	adapter.connect(&"action_event", func(event_name: StringName, _direction: Vector2) -> void:
		if event_name == &"throw_release":
			throw_release_origins.append(adapter.call(&"get_action_origin") as Vector2)
	)
	var projectile_count_before := projectiles.get_child_count()
	potion_input.throw_requested.emit()
	_expect(projectiles.get_child_count() == projectile_count_before, "throw does not spawn on input")
	_expect(not mixer.has_prepared_potion(), "accepted throw reserves the prepared recipe")
	_expect(adapter.call(&"is_busy") as bool, "accepted throw starts the authored action")
	Input.warp_mouse(viewport_center - Vector2(300.0, 0.0))
	await _advance(0.35)
	_expect(projectiles.get_child_count() == projectile_count_before, "throw remains unspawned before throw_release")
	await _advance(0.25)
	_expect(projectiles.get_child_count() == projectile_count_before + 1, "throw_release spawns one projectile")
	if projectiles.get_child_count() == projectile_count_before + 1:
		var projectile := projectiles.get_child(projectiles.get_child_count() - 1) as PotionProjectile
		var launched_direction: Vector2 = projectile.get("_direction")
		_expect(launched_direction.is_equal_approx(captured_direction), "throw_release uses aim captured at action start")
		var launch_origin := (
			projectile.global_position
			- launched_direction * projectile.speed * float(projectile.get("_elapsed"))
		)
		_expect(
			throw_release_origins.size() == 1
			and launch_origin.is_equal_approx(throw_release_origins[0]),
			"throw_release launches from the animated right-hand socket"
		)
	adapter.emit_signal(&"action_event", &"throw_release", Vector2.LEFT)
	_expect(projectiles.get_child_count() == projectile_count_before + 1, "duplicate throw_release cannot spawn twice")
	_expect(await _wait_until_not_busy(adapter, 0.8), "throw action finishes after release")

	health.current_health = 30
	_prepare_health_potion(mixer)
	potion_input.drink_requested.emit()
	await _advance(0.2)
	health.take_damage(5)
	_expect(health.current_health == 25, "external damage applies during the drink wind-up")
	await _advance(1.1)
	_expect(health.current_health == 25, "pre-commit interruption destroys the health potion")
	_expect(not mixer.has_prepared_potion(), "interrupted potion is not restored to the mixer")
	_expect(not mixer_ui.visible, "interrupted potion leaves the mixer closed")
	_expect(not (adapter.call(&"is_busy") as bool), "hit recovery eventually releases the player")

	for projectile in projectiles.get_children():
		projectile.queue_free()
	await get_tree().process_frame
	health.current_health = 80
	_prepare_damage_potion(mixer)
	potion_input.throw_requested.emit()
	await _advance(0.2)
	health.take_damage(5)
	await _advance(0.2)
	health.take_damage(5)
	_expect(health.current_health == 70, "additional damage during hit still changes health")
	await _advance(0.32)
	_expect(not (adapter.call(&"is_busy") as bool), "additional damage during hit does not restart recovery")
	_expect(projectiles.get_child_count() == 0, "pre-release damage destroys a thrown potion before spawn")

	health.current_health = 100
	_prepare_damage_potion(mixer)
	potion_input.drink_requested.emit()
	await _advance(0.7)
	_expect(health.current_health == 70, "self-damage commits before its hit reaction")
	await _advance(0.8)
	_expect(health.current_health == 70, "post-commit hit does not reapply or undo self-damage")
	_expect(not (adapter.call(&"is_busy") as bool), "self-damage hit recovers to idle")

	_prepare_health_potion(mixer)
	var held_flask := combat.get_node_or_null(
		^"Arena/Player/PlayerVisual/FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/Hand_R/HandSocket_R/HeldPotionFlask"
	) as Node2D
	var health_before_missing_event := health.current_health
	potion_input.drink_requested.emit()
	_expect(held_flask != null and held_flask.visible, "reserved potion appears in the animated hand")
	adapter.call(&"_on_rig_state_finished", &"drink")
	await get_tree().process_frame
	_expect(health.current_health == health_before_missing_event, "missing drink event applies no potion effect")
	_expect(not mixer.has_prepared_potion(), "missing-event recipe remains consumed from the mixer")
	_expect(not (adapter.call(&"is_busy") as bool), "missing-event recovery releases combat input")
	_expect(held_flask != null and not held_flask.visible, "missing-event recovery hides the animated flask")

	combat.queue_free()
	await get_tree().process_frame


func _prepare_health_potion(mixer: PotionMixer) -> void:
	mixer.clear()
	_expect(mixer.add_reagent(PotionReagent.RED), "health potion accepts first red")
	_expect(mixer.add_reagent(PotionReagent.RED), "health potion accepts second red")
	_expect(mixer.add_reagent(PotionReagent.BLUE), "health potion accepts blue")
	_expect(mixer.mix(), "health potion prepares")


func _prepare_damage_potion(mixer: PotionMixer) -> void:
	mixer.clear()
	_expect(mixer.add_reagent(PotionReagent.GREEN), "damage potion accepts first green")
	_expect(mixer.add_reagent(PotionReagent.GREEN), "damage potion accepts second green")
	_expect(mixer.add_reagent(PotionReagent.BLUE), "damage potion accepts blue")
	_expect(mixer.mix(), "damage potion prepares")


func _advance(duration: float) -> void:
	for _frame in range(ceili(duration * FRAME_RATE)):
		await get_tree().process_frame


func _wait_until_not_busy(adapter: Node, timeout: float) -> bool:
	for _frame in range(ceili(timeout * FRAME_RATE)):
		if not (adapter.call(&"is_busy") as bool):
			return true
		await get_tree().process_frame
	return not (adapter.call(&"is_busy") as bool)


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
