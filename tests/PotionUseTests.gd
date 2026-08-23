extends Node

# Responsibility: Verify prepared potions apply immediately without animation-owned action state.

const COMBAT_SCENE_PATH := "res://combat/CombatScene.tscn"

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("PotionUseTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("PotionUseTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
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
	var projectiles := combat.get_node_or_null(^"Arena/Projectiles") as Node2D
	_expect(potion_input != null, "CombatScene exposes PotionInput")
	_expect(mixer != null, "CombatScene exposes PotionMixer")
	_expect(mixer_ui != null, "CombatScene exposes PotionMixerUI")
	_expect(player != null, "CombatScene exposes the Player controller")
	_expect(health != null, "CombatScene exposes player health")
	_expect(projectiles != null, "CombatScene exposes the projectile owner")
	_expect(
		combat.get_node_or_null(^"Arena/Player/PlayerAnimationController") == null,
		"CombatScene has no PlayerAnimationController"
	)
	if (
		potion_input == null
		or mixer == null
		or mixer_ui == null
		or player == null
		or health == null
		or projectiles == null
	):
		combat.queue_free()
		return

	var initial_health := health.current_health
	var initial_projectile_count := projectiles.get_child_count()
	potion_input.drink_requested.emit()
	potion_input.throw_requested.emit()
	_expect(health.current_health == initial_health, "no-recipe drink leaves health unchanged")
	_expect(
		projectiles.get_child_count() == initial_projectile_count,
		"no-recipe throw creates no projectile"
	)
	_expect(not mixer.has_prepared_potion(), "no-recipe input does not create a prepared potion")

	health.current_health = 40
	_prepare_health_potion(potion_input, mixer)
	_expect(mixer_ui.visible, "prepared potion is visible before drinking")
	potion_input.drink_requested.emit()
	_expect(health.current_health == 70, "drink applies the health recipe during the input signal")
	_expect(not mixer.has_prepared_potion(), "drink consumes the prepared recipe once")
	_expect(not mixer_ui.visible, "drink closes the mixer immediately")
	potion_input.drink_requested.emit()
	_expect(health.current_health == 70, "a second drink input cannot reuse the consumed recipe")

	_prepare_damage_potion(potion_input, mixer)
	var origin := player.get_throw_origin()
	var direction := player.get_throw_direction()
	var before := projectiles.get_child_count()
	potion_input.throw_requested.emit()
	_expect(projectiles.get_child_count() == before + 1, "throw spawns one projectile during the input signal")
	if projectiles.get_child_count() == before + 1:
		var projectile := projectiles.get_child(projectiles.get_child_count() - 1) as PotionProjectile
		_expect(projectile != null, "throw creates a PotionProjectile")
		if projectile != null:
			_expect(projectile.global_position.is_equal_approx(origin), "throw starts at the right-hand socket")
			_expect(
				(projectile.get("_direction") as Vector2).is_equal_approx(direction),
				"throw captures current mouse aim"
			)
	_expect(
		not mixer.has_prepared_potion() and not mixer_ui.visible,
		"throw consumes the recipe and closes the mixer"
	)
	var mixer_visible_after_throw := mixer_ui.visible
	var layers_after_throw := mixer.get_layers()
	potion_input.throw_requested.emit()
	_expect(projectiles.get_child_count() == before + 1, "a second throw input cannot launch another projectile")
	_expect(not mixer.has_prepared_potion(), "a second throw input cannot restore the consumed recipe")
	_expect(
		mixer_ui.visible == mixer_visible_after_throw and mixer.get_layers() == layers_after_throw,
		"a second throw input leaves the consumed mixer state unchanged"
	)

	potion_input.mixer_toggle_requested.emit()
	_expect(mixer_ui.visible, "Tab opens the mixer after immediate potion use")
	health.take_damage(5)
	potion_input.reagent_requested.emit(PotionReagent.GREEN)
	_expect(
		mixer.get_layers() == [PotionReagent.GREEN],
		"taking damage does not block mixer input"
	)
	Input.action_press(&"move_right")
	await get_tree().physics_frame
	health.take_damage(5)
	await get_tree().physics_frame
	Input.action_release(&"move_right")
	_expect(player.velocity.x > 0.0, "taking damage does not take locomotion ownership")
	potion_input.remove_reagent_requested.emit()
	_expect(mixer.get_layers().is_empty(), "remove remains available after damage")
	potion_input.reagent_requested.emit(PotionReagent.BLUE)
	potion_input.clear_mixture_requested.emit()
	_expect(mixer.get_layers().is_empty(), "clear remains available after damage")

	for projectile in projectiles.get_children():
		projectile.queue_free()
	combat.queue_free()
	await get_tree().process_frame


func _prepare_health_potion(potion_input: PotionInput, mixer: PotionMixer) -> void:
	_prepare_potion(
		potion_input,
		mixer,
		[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE],
		"health"
	)


func _prepare_damage_potion(potion_input: PotionInput, mixer: PotionMixer) -> void:
	_prepare_potion(
		potion_input,
		mixer,
		[PotionReagent.GREEN, PotionReagent.GREEN, PotionReagent.BLUE],
		"damage"
	)


func _prepare_potion(
	potion_input: PotionInput,
	mixer: PotionMixer,
	reagents: Array[StringName],
	potion_name: String
) -> void:
	mixer.clear()
	potion_input.mixer_toggle_requested.emit()
	for reagent in reagents:
		potion_input.reagent_requested.emit(reagent)
	_expect(mixer.get_layers() == reagents, "%s potion accepts input-driven reagents" % potion_name)
	potion_input.mix_requested.emit()
	_expect(mixer.has_prepared_potion(), "%s potion prepares through PotionInput" % potion_name)


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
