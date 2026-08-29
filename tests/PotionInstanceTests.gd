extends Node

# Responsibility: Verify runtime potion instances own valid mixtures and consume once.

const HEALTH_POTION := preload("res://combat/potions/resources/HealthPotion.tres")

var _failures: Array[String] = []
var _check_count := 0
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	_test_instance_creation_and_copy()
	_test_invalid_creation()
	_test_delivery_id_normalization()
	_test_apply_once_and_discard()
	_test_unsupported_and_invalid_contexts()
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


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.free()


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
