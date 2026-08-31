extends Node

# Responsibility: Verify runtime potion instances own valid mixtures and consume once.

const HEALTH_POTION := preload("res://combat/potions/resources/HealthPotion.tres")
const POTION_ENTITY_SCENE := preload("res://combat/potions/PotionEntity.tscn")

var _failures: Array[String] = []
var _check_count := 0
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	_test_instance_creation_and_copy()
	_test_invalid_creation()
	_test_delivery_id_normalization()
	_test_apply_once_and_discard()
	_test_unsupported_and_invalid_contexts()
	_test_held_slot_ownership()
	_free_owned_nodes()
	if _failures.is_empty():
		print("PotionInstanceTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PotionInstanceTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _test_instance_creation_and_copy() -> void:
	var source_layers: Array[StringName] = [PotionReagent.BLUE, PotionReagent.RED, PotionReagent.RED]
	var potion := PotionInstance.create(HEALTH_POTION, source_layers)
	_expect(potion != null and potion.is_valid(), "matching layers create a valid instance")
	source_layers.clear()
	_expect(
		potion.get_created_layers() == [PotionReagent.BLUE, PotionReagent.RED, PotionReagent.RED],
		"instance owns a layer copy"
	)
	_expect(potion.get_recipe() == HEALTH_POTION, "instance references its immutable recipe")
	_expect(potion.get_color().is_equal_approx(HEALTH_POTION.mixed_color), "instance exposes recipe color")


func _test_invalid_creation() -> void:
	_expect(PotionInstance.create(null, []) == null, "null recipe is rejected")
	var wrong: Array[StringName] = [PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE]
	_expect(PotionInstance.create(HEALTH_POTION, wrong) == null, "nonmatching layers are rejected")


func _test_delivery_id_normalization() -> void:
	var empty_delivery_context := PotionImpactContext.new().configure(
		null,
		null,
		null,
		Vector2.ZERO,
		Vector2.ZERO,
		&""
	)
	_expect(
		empty_delivery_context.delivery_method == PotionDelivery.THROW,
		"empty delivery falls back to throw"
	)
	var unknown_delivery: StringName = &"splash"
	var unknown_delivery_context := PotionImpactContext.new().configure(
		null,
		null,
		null,
		Vector2.ZERO,
		Vector2.ZERO,
		unknown_delivery
	)
	_expect(
		unknown_delivery_context.delivery_method == unknown_delivery,
		"unknown non-empty delivery is preserved"
	)


func _test_apply_once_and_discard() -> void:
	var actor := Node2D.new()
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 50
	actor.add_child(health)
	add_child(actor)
	_owned_nodes.append(actor)
	var context := PotionImpactContext.new().configure(
		actor,
		actor,
		actor,
		Vector2.ZERO,
		Vector2.ZERO,
		PotionDelivery.DRINK
	)
	var potion := PotionInstance.create(
		HEALTH_POTION,
		[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]
	)
	_expect(potion.apply(context) == 1 and health.current_health == 80, "first valid application resolves")
	_expect(potion.apply(context) == 0 and health.current_health == 80, "second application is rejected")
	var discarded := PotionInstance.create(
		HEALTH_POTION,
		[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]
	)
	_expect(discarded.discard(), "unused potion can be discarded")
	_expect(not discarded.discard() and discarded.is_consumed(), "discard is idempotent")


func _test_unsupported_and_invalid_contexts() -> void:
	var wall := StaticBody2D.new()
	add_child(wall)
	_owned_nodes.append(wall)
	var wall_context := PotionImpactContext.new().configure(
		wall,
		wall,
		null,
		Vector2.ZERO,
		Vector2.RIGHT,
		PotionDelivery.THROW
	)
	var unsupported := PotionInstance.create(
		HEALTH_POTION,
		[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]
	)
	_expect(
		unsupported.apply(wall_context) == 0 and unsupported.is_consumed(),
		"unsupported but valid wall context consumes the potion"
	)
	var invalid := PotionInstance.create(
		HEALTH_POTION,
		[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]
	)
	_expect(
		invalid.apply(PotionImpactContext.new()) == 0 and not invalid.is_consumed(),
		"invalid context does not consume the potion"
	)


func _test_held_slot_ownership() -> void:
	_expect(ResourceLoader.exists("res://combat/potions/HeldPotionSlot.gd"), "held slot script exists")
	if not ResourceLoader.exists("res://combat/potions/HeldPotionSlot.gd"):
		return
	var slot_script := load("res://combat/potions/HeldPotionSlot.gd")
	_expect(slot_script != null, "held slot script loads")
	if slot_script == null:
		return
	var slot: Node = slot_script.new()
	add_child(slot)
	_owned_nodes.append(slot)
	var first_potion := PotionInstance.create(
		HEALTH_POTION,
		[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]
	)
	var second_potion := PotionInstance.create(
		HEALTH_POTION,
		[PotionReagent.BLUE, PotionReagent.RED, PotionReagent.RED]
	)
	var first_entity := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	var second_entity := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	add_child(first_entity)
	add_child(second_entity)
	_owned_nodes.append(first_entity)
	_owned_nodes.append(second_entity)
	_expect(first_entity.initialize(first_potion, self), "first real entity initializes")
	_expect(second_entity.initialize(second_potion, self), "second real entity initializes")
	var changed: Array[Variant] = []
	slot.connect(&"potion_changed", func(potion: PotionInstance) -> void:
		changed.append(potion)
	)
	_expect(not slot.call(&"has_potion"), "new held slot is empty")
	_expect(slot.call(&"get_potion") == null, "empty slot has no potion")
	_expect(slot.call(&"get_entity") == null, "empty slot has no entity")
	_expect(slot.call(&"hold", first_potion, first_entity), "matching potion and entity can be held")
	_expect(slot.call(&"has_potion"), "successful hold occupies the slot")
	_expect(slot.call(&"get_potion") == first_potion, "slot returns the held potion")
	_expect(slot.call(&"get_entity") == first_entity, "slot returns the held entity")
	_expect(changed == [first_potion], "hold emits the held potion")
	_expect(
		not slot.call(&"hold", second_potion, second_entity),
		"occupied slot rejects another matching pair"
	)
	_expect(changed == [first_potion], "rejected occupied hold emits no change")
	slot.call(&"clear")
	_expect(not slot.call(&"has_potion"), "clear empties the slot")
	_expect(slot.call(&"get_potion") == null, "clear removes the potion reference")
	_expect(slot.call(&"get_entity") == null, "clear removes the entity reference")
	_expect(changed == [first_potion, null], "clear emits null once")
	slot.call(&"clear")
	_expect(changed == [first_potion, null], "clearing an empty slot emits nothing")
	_expect(
		not slot.call(&"hold", first_potion, second_entity),
		"slot rejects a potion that does not match the entity"
	)
	_expect(not slot.call(&"has_potion"), "mismatched rejection leaves the slot empty")
	_expect(slot.call(&"hold", second_potion, second_entity), "slot can hold again after clear")
	_expect(changed == [first_potion, null, second_potion], "second hold emits the new potion")


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.free()


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
