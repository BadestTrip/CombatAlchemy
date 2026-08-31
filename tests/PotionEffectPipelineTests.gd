extends Node

# Responsibility: Verify recipe-owned effects resolve against impacted object capabilities.

const EFFECT_SCRIPT_PATH := "res://combat/potions/effects/PotionEffectData.gd"
const HEALTH_EFFECT_SCRIPT_PATH := "res://combat/potions/effects/HealthPotionEffectData.gd"
const CONTEXT_SCRIPT_PATH := "res://combat/potions/effects/PotionImpactContext.gd"
const RESOLVER_SCRIPT_PATH := "res://combat/potions/effects/PotionEffectResolver.gd"
const IMPACT_HITBOX_SCRIPT_PATH := "res://combat/actors/ImpactHitbox.gd"


class UnsupportedTestEffect:
	extends PotionEffectData

	func is_valid() -> bool:
		return true

	func apply(_context: PotionImpactContext) -> ApplyResult:
		return ApplyResult.UNSUPPORTED


var _failures: Array[String] = []
var _check_count := 0
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	if _required_scripts_exist():
		_test_impact_hitbox_resolves_its_subject()
		_test_recipe_requires_valid_effects()
		_test_health_effects_apply_through_subject_components()
		_test_supported_and_unsupported_effects_resolve_independently()
		_test_unsupported_subject_is_a_clean_no_op()
	_free_owned_nodes()
	if _failures.is_empty():
		print("PotionEffectPipelineTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"PotionEffectPipelineTests: FAIL (%d failures, %d checks)"
		% [_failures.size(), _check_count]
	)
	get_tree().quit(1)


func _required_scripts_exist() -> bool:
	var all_exist := true
	for path in [
		EFFECT_SCRIPT_PATH,
		HEALTH_EFFECT_SCRIPT_PATH,
		CONTEXT_SCRIPT_PATH,
		RESOLVER_SCRIPT_PATH,
		IMPACT_HITBOX_SCRIPT_PATH,
	]:
		var exists := FileAccess.file_exists(path)
		_expect(exists, "%s exists" % path.get_file())
		all_exist = all_exist and exists
	return all_exist


func _test_impact_hitbox_resolves_its_subject() -> void:
	var subject := Node2D.new()
	_owned_nodes.append(subject)
	var hitbox_script := load(IMPACT_HITBOX_SCRIPT_PATH) as Script
	var hitbox := hitbox_script.new() as Area2D if hitbox_script != null else null
	_expect(hitbox != null, "ImpactHitbox instantiates as Area2D")
	if hitbox == null:
		return
	subject.add_child(hitbox)
	_expect(
		hitbox.call(&"get_effect_subject") == subject,
		"ImpactHitbox resolves its configured parent subject"
	)


func _test_recipe_requires_valid_effects() -> void:
	var effect := _new_health_effect(0, 30)
	var recipe := _new_recipe([effect])
	_expect(recipe.is_valid(), "three-layer recipe with a valid effect is valid")

	var empty_recipe := _new_recipe([])
	_expect(not empty_recipe.is_valid(), "recipe without effects is invalid")

	effect.set(&"amount", 0)
	_expect(not recipe.is_valid(), "recipe rejects an invalid effect resource")


func _test_health_effects_apply_through_subject_components() -> void:
	var subject := Node2D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100
	health.current_health = 50
	subject.add_child(health)
	_owned_nodes.append(subject)

	var context := _new_context(subject, subject)
	var heal_recipe := _new_recipe([_new_health_effect(0, 30)])
	var damage_recipe := _new_recipe([_new_health_effect(1, 20)])

	_expect(
		PotionEffectResolver.apply_recipe(heal_recipe, context) == 1,
		"resolver reports one applied healing effect"
	)
	_expect(health.current_health == 80, "healing effect uses the subject HealthComponent")
	_expect(
		PotionEffectResolver.apply_recipe(damage_recipe, context) == 1,
		"resolver reports one applied damage effect"
	)
	_expect(health.current_health == 60, "damage effect uses the subject HealthComponent")


func _test_unsupported_subject_is_a_clean_no_op() -> void:
	var wall := StaticBody2D.new()
	_owned_nodes.append(wall)
	var context := _new_context(wall, wall)
	var recipe := _new_recipe([_new_health_effect(1, 30)])
	_expect(
		PotionEffectResolver.apply_recipe(recipe, context) == 0,
		"object without HealthComponent reports no applied effects"
	)
	_expect(is_instance_valid(wall), "unsupported effect does not remove or invalidate its subject")


func _test_supported_and_unsupported_effects_resolve_independently() -> void:
	var subject := Node2D.new()
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 50
	subject.add_child(health)
	_owned_nodes.append(subject)

	var unsupported := UnsupportedTestEffect.new()
	var healing := _new_health_effect(0, 10)
	var unsupported_first: Array[PotionEffectData] = [unsupported, healing]
	var context := _new_context(subject, subject)
	_expect(
		PotionEffectResolver.apply_recipe(_new_recipe(unsupported_first), context) == 1,
		"a supported effect applies after an unsupported effect"
	)
	_expect(health.current_health == 60, "unsupported-first recipe applies healing exactly once")

	health.current_health = 50
	var supported_first: Array[PotionEffectData] = [healing, unsupported]
	_expect(
		PotionEffectResolver.apply_recipe(_new_recipe(supported_first), context) == 1,
		"a supported effect applies before an unsupported effect"
	)
	_expect(health.current_health == 60, "supported-first recipe applies healing exactly once")


func _new_recipe(effects: Array[PotionEffectData]) -> PotionRecipeData:
	var recipe := PotionRecipeData.new()
	recipe.recipe_id = "pipeline_test"
	recipe.display_name = "Pipeline Test"
	recipe.red_count = 2
	recipe.blue_count = 1
	recipe.effects = effects
	return recipe


func _new_health_effect(operation: int, amount: int) -> HealthPotionEffectData:
	var effect := HealthPotionEffectData.new()
	effect.operation = operation as HealthPotionEffectData.Operation
	effect.amount = amount
	return effect


func _new_context(subject: Node, collider: Node) -> PotionImpactContext:
	var context := PotionImpactContext.new()
	context.configure(
		subject,
		collider,
		null,
		Vector2.ZERO,
		Vector2.RIGHT,
		PotionDelivery.DRINK
	)
	return context


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.free()


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
