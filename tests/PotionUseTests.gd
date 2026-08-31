extends Node

# Responsibility: Verify one physical potion entity moves through held delivery states.

const COMBAT_SCENE_PATH := "res://combat/CombatScene.tscn"
const HEALTH_POTION := preload("res://combat/potions/resources/HealthPotion.tres")
const DAMAGE_POTION := preload("res://combat/potions/resources/DamagePotion.tres")

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
	var slot := combat.get_node_or_null(^"Systems/HeldPotionSlot")
	var mixer_ui := combat.get_node_or_null(^"UI/PotionMixerUI") as Control
	var player := combat.get_node_or_null(^"Arena/Player") as PlayerCombatController
	var health := combat.get_node_or_null(^"Arena/Player/HealthComponent") as HealthComponent
	var entities := combat.get_node_or_null(^"Arena/PotionEntities") as Node2D
	_expect(potion_input != null, "CombatScene exposes PotionInput")
	_expect(
		potion_input != null and potion_input.has_signal(&"potion_use_requested"),
		"PotionInput exposes one unified delivery signal"
	)
	_expect(mixer != null, "CombatScene exposes PotionMixer")
	_expect(slot != null, "CombatScene exposes HeldPotionSlot")
	_expect(mixer_ui != null, "CombatScene exposes PotionMixerUI")
	_expect(player != null, "CombatScene exposes the Player controller")
	_expect(health != null, "CombatScene exposes player health")
	_expect(entities != null, "CombatScene exposes the potion entity owner")
	_expect(
		combat.get_node_or_null(^"Arena/Player/PlayerAnimationController") == null,
		"CombatScene has no PlayerAnimationController"
	)
	_expect(InputMap.has_action(&"place_potion"), "place_potion exists in the Input Map")
	var place_events := InputMap.action_get_events(&"place_potion")
	var place_uses_q := false
	for event in place_events:
		if event is InputEventKey and (event as InputEventKey).physical_keycode == 81:
			place_uses_q = true
			break
	_expect(place_uses_q, "place_potion is mapped to physical Q")
	if (
		potion_input == null
		or not potion_input.has_signal(&"potion_use_requested")
		or mixer == null
		or slot == null
		or mixer_ui == null
		or player == null
		or health == null
		or entities == null
	):
		combat.queue_free()
		return

	_test_unified_delivery_input(potion_input)
	var initial_health := health.current_health
	var initial_entity_count := _find_potion_entities(combat).size()
	for delivery_method in [PotionDelivery.DRINK, PotionDelivery.THROW, PotionDelivery.PLACE]:
		potion_input.emit_signal(&"potion_use_requested", delivery_method)
	_expect(health.current_health == initial_health, "delivery input without a held potion changes no health")
	_expect(
		_find_potion_entities(combat).size() == initial_entity_count,
		"delivery input without a held potion creates no entity"
	)
	_expect(not (slot.call(&"has_potion") as bool), "delivery input without a held potion leaves the slot empty")

	health.current_health = 40
	var drink_entity := _prepare_health_potion(combat, potion_input, mixer, slot, mixer_ui, player, entities)
	if drink_entity != null:
		var drink_entity_id := drink_entity.get_instance_id()
		potion_input.emit_signal(&"potion_use_requested", PotionDelivery.DRINK)
		_expect(health.current_health == 70, "drink applies the held health potion")
		_expect(not (slot.call(&"has_potion") as bool), "drink clears the held slot")
		_expect(not mixer_ui.visible, "drink closes the mixer")
		_expect(drink_entity.get_state() == PotionEntity.State.CONSUMED, "drink consumes the held entity")
		_expect(drink_entity.get_potion().is_consumed(), "drink consumes the held potion instance")
		potion_input.emit_signal(&"potion_use_requested", PotionDelivery.DRINK)
		_expect(health.current_health == 70, "repeated drink input cannot reuse the consumed potion")
		_expect(drink_entity.get_instance_id() == drink_entity_id, "drink acts on the originally held entity")
	await get_tree().process_frame

	var throw_entity := _prepare_damage_potion(combat, potion_input, mixer, slot, mixer_ui, player, entities)
	if throw_entity != null:
		var throw_entity_id := throw_entity.get_instance_id()
		var origin := player.get_throw_origin()
		var direction := player.get_throw_direction()
		var child_count_before_throw := entities.get_child_count()
		potion_input.emit_signal(&"potion_use_requested", PotionDelivery.THROW)
		_expect(not (slot.call(&"has_potion") as bool), "throw clears the held slot")
		_expect(throw_entity.get_parent() == entities, "throw reparents the held entity to PotionEntities")
		_expect(throw_entity.get_instance_id() == throw_entity_id, "throw preserves the held entity instance ID")
		_expect(throw_entity.get_state() == PotionEntity.State.FLYING, "throw enters the flying state")
		_expect(throw_entity.global_position.is_equal_approx(origin), "throw starts at the player hand socket")
		_expect(
			(throw_entity.get("_direction") as Vector2).is_equal_approx(direction),
			"throw captures the player aim direction"
		)
		_expect(
			entities.get_child_count() == child_count_before_throw + 1,
			"throw moves one entity under PotionEntities without creating a second entity"
		)
		var thrown_child_count := entities.get_child_count()
		potion_input.emit_signal(&"potion_use_requested", PotionDelivery.THROW)
		_expect(entities.get_child_count() == thrown_child_count, "repeated throw input creates no entity")
		throw_entity.queue_free()
	await get_tree().process_frame

	var place_entity := _prepare_health_potion(combat, potion_input, mixer, slot, mixer_ui, player, entities)
	if place_entity != null:
		var place_entity_id := place_entity.get_instance_id()
		var place_position := player.call(&"get_place_position") as Vector2
		potion_input.emit_signal(&"potion_use_requested", PotionDelivery.PLACE)
		_expect(not (slot.call(&"has_potion") as bool), "place clears the held slot")
		_expect(place_entity.get_parent() == entities, "place reparents the held entity to PotionEntities")
		_expect(place_entity.get_instance_id() == place_entity_id, "place preserves the held entity instance ID")
		_expect(place_entity.get_state() == PotionEntity.State.PLACED, "place enters the placed state")
		_expect(
			place_entity.global_position.is_equal_approx(place_position),
			"place uses the player's placement geometry"
		)
		place_entity.queue_free()
	await get_tree().process_frame

	var discard_entity := _prepare_health_potion(combat, potion_input, mixer, slot, mixer_ui, player, entities)
	if discard_entity != null:
		var held_entity_id := discard_entity.get_instance_id()
		potion_input.mixer_toggle_requested.emit()
		_expect(mixer_ui.visible, "Tab is ignored while a potion is held")
		_expect(
			slot.call(&"get_entity") != null
			and (slot.call(&"get_entity") as PotionEntity).get_instance_id() == held_entity_id,
			"Tab preserves the held entity"
		)
		potion_input.clear_mixture_requested.emit()
		_expect(discard_entity.get_state() == PotionEntity.State.CONSUMED, "clear discards the held entity")
		_expect(discard_entity.get_potion().is_consumed(), "clear discards the held potion instance")
		_expect(not (slot.call(&"has_potion") as bool), "clear empties the held slot")
		_expect(mixer.get_layers().is_empty(), "clear leaves an empty mixer")
		_expect(mixer_ui.visible, "clear leaves the empty mixer open")
		_expect(_reagent_buttons_visible(mixer_ui), "clear resets the open mixer to mixing state")

	Input.action_release(&"move_right")
	combat.queue_free()
	await get_tree().process_frame


func _test_unified_delivery_input(potion_input: PotionInput) -> void:
	var requested: Array[StringName] = []
	potion_input.connect(&"potion_use_requested", func(delivery_method: StringName) -> void:
		requested.append(delivery_method)
	)
	for action in [&"drink_potion", &"throw_potion", &"place_potion"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		potion_input._unhandled_input(event)
	_expect(
		requested == [PotionDelivery.DRINK, PotionDelivery.THROW, PotionDelivery.PLACE],
		"PotionInput emits one unified delivery signal for drink, throw, and place"
	)


func _prepare_health_potion(
	combat: Node,
	potion_input: PotionInput,
	mixer: PotionMixer,
	slot: Node,
	mixer_ui: Control,
	player: PlayerCombatController,
	entities: Node2D
) -> PotionEntity:
	return _prepare_potion(
		combat,
		potion_input,
		mixer,
		slot,
		mixer_ui,
		player,
		entities,
		[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE],
		HEALTH_POTION,
		"health"
	)


func _prepare_damage_potion(
	combat: Node,
	potion_input: PotionInput,
	mixer: PotionMixer,
	slot: Node,
	mixer_ui: Control,
	player: PlayerCombatController,
	entities: Node2D
) -> PotionEntity:
	return _prepare_potion(
		combat,
		potion_input,
		mixer,
		slot,
		mixer_ui,
		player,
		entities,
		[PotionReagent.GREEN, PotionReagent.GREEN, PotionReagent.BLUE],
		DAMAGE_POTION,
		"damage"
	)


func _prepare_potion(
	combat: Node,
	potion_input: PotionInput,
	mixer: PotionMixer,
	slot: Node,
	mixer_ui: Control,
	player: PlayerCombatController,
	entities: Node2D,
	reagents: Array[StringName],
	expected_recipe: PotionRecipeData,
	potion_name: String
) -> PotionEntity:
	mixer.clear()
	if not mixer_ui.visible:
		potion_input.mixer_toggle_requested.emit()
	for reagent in reagents:
		potion_input.reagent_requested.emit(reagent)
	_expect(mixer.get_layers() == reagents, "%s potion accepts input-driven reagents" % potion_name)
	potion_input.mix_requested.emit()
	_expect(slot.call(&"has_potion") as bool, "%s potion occupies HeldPotionSlot" % potion_name)
	var entity := slot.call(&"get_entity") as PotionEntity
	_expect(entity != null, "%s potion exposes its held entity" % potion_name)
	if entity == null:
		return null
	var global_entities := _find_potion_entities(combat)
	_expect(global_entities.size() == 1 and global_entities[0] == entity, "%s has one global PotionEntity" % potion_name)
	_expect(entity.get_state() == PotionEntity.State.HELD, "%s entity is held" % potion_name)
	_expect(entity.get_potion() == slot.call(&"get_potion"), "%s entity and slot share the potion instance" % potion_name)
	_expect(entity.get_potion().get_recipe() == expected_recipe, "%s entity owns the expected recipe" % potion_name)
	_expect(entity.get_parent() == player.call(&"get_potion_holder"), "%s entity is parented to HandSocket_R" % potion_name)
	_expect(entity.get_parent() != entities, "%s held entity is not a direct PotionEntities child" % potion_name)
	_expect(entities.get_child_count() == 0, "%s leaves PotionEntities empty while held" % potion_name)
	_expect(mixer_ui.visible and not _reagent_buttons_visible(mixer_ui), "%s displays the ready mixer UI" % potion_name)
	return entity


func _find_potion_entities(root: Node) -> Array[PotionEntity]:
	var entities: Array[PotionEntity] = []
	_collect_potion_entities(root, entities)
	return entities


func _collect_potion_entities(node: Node, entities: Array[PotionEntity]) -> void:
	for child in node.get_children():
		if child is PotionEntity:
			entities.append(child as PotionEntity)
		_collect_potion_entities(child, entities)


func _reagent_buttons_visible(mixer_ui: Control) -> bool:
	for child_name in [&"RedButton", &"GreenButton", &"BlueButton"]:
		var button := mixer_ui.get_node_or_null(NodePath("ReagentButtons/%s" % child_name)) as Button
		if button == null or not button.visible:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
