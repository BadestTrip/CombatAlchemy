extends Node

# Responsibility: Run headless behavioral tests for the potion domain.

const HEALTH_POTION = preload("res://combat/potions/resources/HealthPotion.tres")
const DAMAGE_POTION = preload("res://combat/potions/resources/DamagePotion.tres")
const DEFAULT_RECIPE_BOOK = preload("res://combat/potions/resources/PotionRecipeBook_Default.tres")

var _failures: Array[String] = []
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	_test_reagent_validation_and_colors()
	_test_recipe_validation_and_order_independent_matching()
	_test_health_recipe_in_alternate_order()
	_test_damage_recipe_in_alternate_order()
	_test_layer_limit_and_invalid_reagent_rejection()
	_test_incomplete_and_unknown_mixtures_preserve_layers()
	_test_layer_signals_and_remove_last_lifo()
	_test_clearing_layers()
	_test_rejected_mix_signal()
	_test_successful_mix_signals()
	_test_prepared_recipe_consumption()
	_test_health_damage_and_healing_clamp_to_bounds()
	_test_health_damaged_signal_reports_actual_damage_only()
	_test_health_depleted_emits_only_when_crossing_to_zero()
	_test_health_reset_and_ratio()
	_test_health_healing_from_zero_revives()
	_test_potion_target_applies_recipes_and_rejects_null()
	_test_potion_target_emits_only_for_accepted_recipes()
	_test_potion_target_rejects_invalid_recipe_and_health_paths()
	_test_player_movement_lock_contract()
	_free_owned_nodes()
	if _failures.is_empty():
		print("PotionDomainTests: PASS (20 tests)")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("PotionDomainTests: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_reagent_validation_and_colors() -> void:
	_expect(PotionReagent.is_valid(PotionReagent.RED), "red reagent is valid")
	_expect(PotionReagent.is_valid(PotionReagent.GREEN), "green reagent is valid")
	_expect(PotionReagent.is_valid(PotionReagent.BLUE), "blue reagent is valid")
	_expect(not PotionReagent.is_valid(&"yellow"), "unknown reagent is invalid")
	_expect(PotionReagent.get_color(PotionReagent.RED) != Color.WHITE, "red reagent has a color")
	_expect(PotionReagent.get_color(&"yellow") == Color.WHITE, "unknown reagent falls back to white")


func _test_recipe_validation_and_order_independent_matching() -> void:
	var recipe := PotionRecipeData.new()
	recipe.recipe_id = "test_recipe"
	recipe.display_name = "Test Recipe"
	recipe.red_count = 2
	recipe.blue_count = 1
	recipe.effect_type = PotionRecipeData.EffectType.HEAL
	recipe.effect_amount = 10
	_expect(recipe.is_valid(), "three-layer positive-effect recipe is valid")
	_expect(
		recipe.matches_layers([PotionReagent.BLUE, PotionReagent.RED, PotionReagent.RED]),
		"recipe matches layers regardless of order"
	)
	recipe.effect_amount = 0
	_expect(not recipe.is_valid(), "zero-effect recipe is invalid")


func _test_health_recipe_in_alternate_order() -> void:
	var mixer := _new_mixer()
	_expect(mixer.add_reagent(PotionReagent.BLUE), "health mix accepts blue first")
	_expect(mixer.add_reagent(PotionReagent.RED), "health mix accepts first red")
	_expect(mixer.add_reagent(PotionReagent.RED), "health mix accepts second red")
	_expect(mixer.mix(), "health mix prepares a recipe")
	var recipe = mixer.take_prepared_recipe()
	_expect(recipe == HEALTH_POTION, "health mix returns health potion")
	_expect(recipe.effect_type == PotionRecipeData.EffectType.HEAL, "health potion heals")
	_expect(recipe.effect_amount == 30, "health potion heals for 30")
	_expect(recipe.mixed_color.is_equal_approx(Color(0.8, 0.2, 0.8)), "health potion is magenta")


func _test_damage_recipe_in_alternate_order() -> void:
	var mixer := _new_mixer()
	_expect(mixer.add_reagent(PotionReagent.BLUE), "damage mix accepts blue first")
	_expect(mixer.add_reagent(PotionReagent.GREEN), "damage mix accepts first green")
	_expect(mixer.add_reagent(PotionReagent.GREEN), "damage mix accepts second green")
	_expect(mixer.mix(), "damage mix prepares a recipe")
	var recipe = mixer.take_prepared_recipe()
	_expect(recipe == DAMAGE_POTION, "damage mix returns damage potion")
	_expect(recipe.effect_type == PotionRecipeData.EffectType.DAMAGE, "damage potion damages")
	_expect(recipe.effect_amount == 30, "damage potion damages for 30")
	_expect(recipe.mixed_color.is_equal_approx(Color(0.0, 0.7, 0.65)), "damage potion is teal")


func _test_layer_limit_and_invalid_reagent_rejection() -> void:
	var mixer := _new_mixer()
	mixer.max_layers = 99
	_expect(mixer.max_layers == 3, "runtime layer limit is clamped to three")
	_expect(mixer.add_reagent(PotionReagent.RED), "first layer is accepted")
	_expect(mixer.add_reagent(PotionReagent.GREEN), "second layer is accepted")
	_expect(mixer.add_reagent(PotionReagent.BLUE), "third layer is accepted")
	_expect(not mixer.add_reagent(PotionReagent.RED), "fourth layer is rejected after an oversized assignment")
	_expect(mixer.get_layers().size() == 3, "layer limit preserves three layers")
	mixer.clear()
	_expect(not mixer.add_reagent(&"yellow"), "invalid reagent is rejected")
	_expect(mixer.get_layers().is_empty(), "invalid reagent does not add a layer")


func _test_incomplete_and_unknown_mixtures_preserve_layers() -> void:
	var incomplete_mixer := _new_mixer()
	incomplete_mixer.add_reagent(PotionReagent.RED)
	incomplete_mixer.add_reagent(PotionReagent.BLUE)
	var incomplete_layers := incomplete_mixer.get_layers()
	_expect(not incomplete_mixer.mix(), "incomplete mixture is rejected")
	_expect(incomplete_mixer.get_layers() == incomplete_layers, "incomplete mixture preserves layers")
	var unknown_mixer := _new_mixer()
	unknown_mixer.add_reagent(PotionReagent.RED)
	unknown_mixer.add_reagent(PotionReagent.GREEN)
	unknown_mixer.add_reagent(PotionReagent.BLUE)
	var unknown_layers := unknown_mixer.get_layers()
	_expect(not unknown_mixer.mix(), "unknown mixture is rejected")
	_expect(unknown_mixer.get_layers() == unknown_layers, "unknown mixture preserves layers")


func _test_layer_signals_and_remove_last_lifo() -> void:
	var mixer := _new_mixer()
	var events: Array[Dictionary] = []
	mixer.layers_changed.connect(func(layers: Array[StringName]) -> void:
		events.append({"name": "layers_changed", "payload": layers})
	)
	mixer.add_reagent(PotionReagent.RED)
	mixer.add_reagent(PotionReagent.BLUE)
	_expect(mixer.remove_last(), "remove_last succeeds when layers are present")
	_expect(mixer.get_layers() == [PotionReagent.RED], "remove_last removes the newest layer")
	_expect(events.size() == 3, "add, add, and remove each emit layers_changed")
	if events.size() != 3:
		return
	_expect(events[0]["name"] == "layers_changed", "first add emits layers_changed first")
	_expect(events[0]["payload"] == [PotionReagent.RED], "first add signal contains the first layer")
	_expect(
		events[1]["payload"] == [PotionReagent.RED, PotionReagent.BLUE],
		"second add signal preserves insertion order"
	)
	_expect(events[2]["payload"] == [PotionReagent.RED], "remove signal contains the LIFO result")


func _test_clearing_layers() -> void:
	var mixer := _new_mixer()
	mixer.add_reagent(PotionReagent.RED)
	mixer.add_reagent(PotionReagent.BLUE)
	var events: Array[Dictionary] = []
	mixer.layers_changed.connect(func(layers: Array[StringName]) -> void:
		events.append({"name": "layers_changed", "payload": layers})
	)
	mixer.mixture_cleared.connect(func() -> void:
		events.append({"name": "mixture_cleared"})
	)
	mixer.clear()
	_expect(mixer.get_layers().is_empty(), "clear removes all layers")
	_expect(events.size() == 2, "clear emits two state events")
	if events.size() == 2:
		_expect(events[0]["name"] == "layers_changed", "clear reports empty layers before completion")
		_expect(events[0]["payload"].is_empty(), "clear layers_changed payload is empty")
		_expect(events[1]["name"] == "mixture_cleared", "clear emits mixture_cleared last")
	_expect(not mixer.remove_last(), "remove_last rejects an empty mixture")


func _test_rejected_mix_signal() -> void:
	var mixer := _new_mixer()
	mixer.add_reagent(PotionReagent.RED)
	mixer.add_reagent(PotionReagent.BLUE)
	var events: Array[Dictionary] = []
	mixer.layers_changed.connect(func(layers: Array[StringName]) -> void:
		events.append({"name": "layers_changed", "payload": layers})
	)
	mixer.potion_prepared.connect(func(recipe: PotionRecipeData) -> void:
		events.append({"name": "potion_prepared", "payload": recipe})
	)
	mixer.mix_rejected.connect(func(layers: Array[StringName]) -> void:
		events.append({"name": "mix_rejected", "payload": layers})
	)
	mixer.mixture_cleared.connect(func() -> void:
		events.append({"name": "mixture_cleared"})
	)
	_expect(not mixer.mix(), "incomplete mix is rejected for signal verification")
	_expect(events.size() == 1, "rejected mix emits only mix_rejected")
	if events.size() != 1:
		return
	_expect(events[0]["name"] == "mix_rejected", "rejected mix signal has the expected ordering")
	_expect(
		events[0]["payload"] == [PotionReagent.RED, PotionReagent.BLUE],
		"mix_rejected payload preserves current layers"
	)


func _test_successful_mix_signals() -> void:
	var mixer := _new_mixer()
	mixer.add_reagent(PotionReagent.BLUE)
	mixer.add_reagent(PotionReagent.RED)
	mixer.add_reagent(PotionReagent.RED)
	var events: Array[Dictionary] = []
	mixer.layers_changed.connect(func(layers: Array[StringName]) -> void:
		events.append({"name": "layers_changed", "payload": layers})
	)
	mixer.potion_prepared.connect(func(recipe: PotionRecipeData) -> void:
		events.append({"name": "potion_prepared", "payload": recipe})
	)
	mixer.mix_rejected.connect(func(layers: Array[StringName]) -> void:
		events.append({"name": "mix_rejected", "payload": layers})
	)
	mixer.mixture_cleared.connect(func() -> void:
		events.append({"name": "mixture_cleared"})
	)
	_expect(mixer.mix(), "valid mix succeeds for signal verification")
	_expect(events.size() == 3, "successful mix emits three state events")
	if events.size() != 3:
		return
	_expect(events[0]["name"] == "layers_changed", "successful mix reports cleared layers first")
	_expect(events[0]["payload"].is_empty(), "successful mix layers_changed payload is empty")
	_expect(events[1]["name"] == "mixture_cleared", "successful mix reports clearing second")
	_expect(events[2]["name"] == "potion_prepared", "successful mix reports prepared recipe last")
	_expect(events[2]["payload"] == HEALTH_POTION, "potion_prepared payload is the matched recipe")


func _test_prepared_recipe_consumption() -> void:
	var mixer := _new_mixer()
	mixer.add_reagent(PotionReagent.RED)
	mixer.add_reagent(PotionReagent.BLUE)
	mixer.add_reagent(PotionReagent.RED)
	mixer.mix()
	_expect(mixer.has_prepared_potion(), "mixer tracks a prepared potion")
	_expect(not mixer.add_reagent(PotionReagent.GREEN), "prepared mixer rejects more layers")
	_expect(mixer.get_prepared_recipe() == HEALTH_POTION, "prepared recipe can be inspected without consuming it")
	_expect(mixer.has_prepared_potion(), "inspecting a prepared recipe preserves it")
	var recipe = mixer.take_prepared_recipe()
	_expect(recipe == HEALTH_POTION, "take_prepared_recipe returns the prepared recipe")
	_expect(not mixer.has_prepared_potion(), "taking the recipe consumes it")
	_expect(mixer.take_prepared_recipe() == null, "prepared recipe is only available once")


func _test_health_damage_and_healing_clamp_to_bounds() -> void:
	var health := _new_health_component()
	health.max_health = 100
	health.current_health = 70
	_expect(health.take_damage(25) == 25, "damage returns the amount actually removed")
	_expect(health.current_health == 45, "damage reduces current health")
	_expect(health.take_damage(99) == 45, "damage clamps at zero and returns the remainder")
	_expect(health.current_health == 0, "damage cannot reduce health below zero")
	_expect(health.heal(150) == 100, "healing returns the amount actually restored")
	_expect(health.current_health == 100, "healing clamps at maximum health")
	_expect(health.heal(1) == 0, "healing at maximum restores nothing")


func _test_health_damaged_signal_reports_actual_damage_only() -> void:
	var health := _new_health_component()
	health.max_health = 100
	health.current_health = 70
	_expect(health.has_signal(&"damaged"), "health exposes the damaged signal")
	if not health.has_signal(&"damaged"):
		return
	var damage_events: Array[int] = []
	health.connect(&"damaged", func(amount: int) -> void:
		damage_events.append(amount)
	)
	health.current_health = 60
	health.take_damage(0)
	health.take_damage(-5)
	health.take_damage(25)
	health.take_damage(100)
	health.take_damage(1)
	_expect(damage_events == [25, 35], "damaged reports only positive health actually removed by take_damage")


func _test_health_depleted_emits_only_when_crossing_to_zero() -> void:
	var health := _new_health_component()
	health.max_health = 10
	health.current_health = 10
	var depleted_count: Array[int] = [0]
	health.depleted.connect(func() -> void:
		depleted_count[0] += 1
	)
	health.take_damage(10)
	health.take_damage(1)
	health.heal(1)
	health.take_damage(1)
	_expect(depleted_count[0] == 2, "depleted emits only when health crosses from positive to zero")


func _test_health_reset_and_ratio() -> void:
	var health := _new_health_component()
	health.max_health = 100
	health.current_health = 25
	_expect(is_equal_approx(health.get_health_ratio(), 0.25), "health ratio reflects current health")
	health.reset_health(40, 60)
	_expect(health.max_health == 40, "reset updates maximum health")
	_expect(health.current_health == 40, "reset clamps current health to the new maximum")
	health.current_health = 1
	health.reset_health()
	_expect(health.max_health == 40 and health.current_health == 40, "default reset restores existing maximum health")


func _test_health_healing_from_zero_revives() -> void:
	var health := _new_health_component()
	health.max_health = 20
	health.current_health = 0
	_expect(health.heal(7) == 7, "healing from zero returns the restored amount")
	_expect(health.current_health == 7, "healing from zero revives health")


func _test_potion_target_applies_recipes_and_rejects_null() -> void:
	var target := _new_potion_target(50, 20)
	_expect(target.receive_potion(HEALTH_POTION), "target accepts a healing recipe")
	_expect(target.get_health_component().current_health == 50, "healing recipe restores target health")
	_expect(target.receive_potion(DAMAGE_POTION), "target accepts a damage recipe")
	_expect(target.get_health_component().current_health == 20, "damage recipe removes target health")
	_expect(not target.receive_potion(null), "target rejects a null recipe")


func _test_potion_target_emits_only_for_accepted_recipes() -> void:
	var target := _new_potion_target(100, 50)
	var received_count: Array[int] = [0]
	target.potion_received.connect(func(_recipe: PotionRecipeData) -> void:
		received_count[0] += 1
	)
	target.receive_potion(null)
	target.receive_potion(HEALTH_POTION)
	target.receive_potion(DAMAGE_POTION)
	_expect(received_count[0] == 2, "potion_received emits only for accepted recipes")


func _test_potion_target_rejects_invalid_recipe_and_health_paths() -> void:
	var invalid_recipe := PotionRecipeData.new()
	var valid_target := _new_potion_target(100, 50)
	var valid_target_events: Array[PotionRecipeData] = []
	valid_target.potion_received.connect(func(recipe: PotionRecipeData) -> void:
		valid_target_events.append(recipe)
	)
	_expect(not valid_target.receive_potion(invalid_recipe), "target rejects an invalid non-null recipe")
	_expect(valid_target_events.is_empty(), "invalid recipe does not emit potion_received")

	var missing_path_target := PotionTarget.new()
	_owned_nodes.append(missing_path_target)
	missing_path_target.health_component_path = NodePath("MissingHealth")
	var missing_path_events: Array[PotionRecipeData] = []
	missing_path_target.potion_received.connect(func(recipe: PotionRecipeData) -> void:
		missing_path_events.append(recipe)
	)
	_expect(not missing_path_target.receive_potion(HEALTH_POTION), "target rejects a missing health path")
	_expect(missing_path_events.is_empty(), "missing health path does not emit potion_received")

	var invalid_path_target := PotionTarget.new()
	_owned_nodes.append(invalid_path_target)
	var wrong_component := Node.new()
	wrong_component.name = "NotHealthComponent"
	invalid_path_target.add_child(wrong_component)
	invalid_path_target.health_component_path = NodePath("NotHealthComponent")
	var invalid_path_events: Array[PotionRecipeData] = []
	invalid_path_target.potion_received.connect(func(recipe: PotionRecipeData) -> void:
		invalid_path_events.append(recipe)
	)
	_expect(not invalid_path_target.receive_potion(DAMAGE_POTION), "target rejects a non-health component path")
	_expect(invalid_path_events.is_empty(), "invalid health path does not emit potion_received")


func _test_player_movement_lock_contract() -> void:
	var player := PlayerCombatController.new()
	add_child(player)
	_owned_nodes.append(player)
	_expect(player.has_signal(&"movement_changed"), "player controller exposes movement_changed")
	_expect(player.has_method(&"set_movement_locked"), "player controller can lock movement")
	_expect(player.has_method(&"is_movement_locked"), "player controller reports its movement lock")
	if (
		not player.has_signal(&"movement_changed")
		or not player.has_method(&"set_movement_locked")
		or not player.has_method(&"is_movement_locked")
	):
		return
	var velocity_events: Array[Vector2] = []
	player.connect(&"movement_changed", func(reported_velocity: Vector2) -> void:
		velocity_events.append(reported_velocity)
	)
	player.velocity = Vector2(80.0, 30.0)
	player.call(&"set_movement_locked", true)
	player._physics_process(1.0 / 60.0)
	_expect(player.call(&"is_movement_locked") as bool, "movement lock reports enabled")
	_expect(player.velocity == Vector2.ZERO, "movement lock clears player velocity")
	_expect(not velocity_events.is_empty() and velocity_events[-1] == Vector2.ZERO, "locked movement reports zero velocity")
	player.call(&"set_movement_locked", false)
	_expect(not (player.call(&"is_movement_locked") as bool), "movement lock can be disabled")


func _new_mixer() -> PotionMixer:
	var mixer := PotionMixer.new()
	mixer.recipe_book = DEFAULT_RECIPE_BOOK
	_owned_nodes.append(mixer)
	return mixer


func _new_potion_target(max_health: int, current_health: int) -> PotionTarget:
	var target := PotionTarget.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = max_health
	health.current_health = current_health
	target.add_child(health)
	target.health_component_path = NodePath("HealthComponent")
	_owned_nodes.append(target)
	return target


func _new_health_component() -> HealthComponent:
	var health := HealthComponent.new()
	_owned_nodes.append(health)
	return health


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
