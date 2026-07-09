extends Node
class_name SpellResolver

@export var grammar_interpreter_path: NodePath
@export var signature_resolver_path: NodePath
@export var instability_calculator_path: NodePath

@onready var grammar_interpreter: RuneGrammarInterpreter = get_node(grammar_interpreter_path) as RuneGrammarInterpreter
@onready var signature_resolver: SignatureSpellResolver = get_node(signature_resolver_path) as SignatureSpellResolver
@onready var instability_calculator: InstabilityCalculator = get_node(instability_calculator_path) as InstabilityCalculator


func resolve(sequence: Array, context: Dictionary = {}) -> SpellResultData:
	var result := grammar_interpreter.interpret(sequence)
	var signature := signature_resolver.find_signature(sequence)

	if signature != null:
		result.display_name = signature.display_name
		result.description = signature.description
		result.set_tags(signature.tags)
		result.is_signature = true
		result.signature_id = signature.id
		result.power += signature.power_modifier

	var instability := instability_calculator.calculate(sequence, grammar_interpreter.get_rune_catalog())
	result.instability_score = int(instability.get("score", 0))
	result.instability_label = str(instability.get("label", "Stable"))
	if signature != null:
		result.instability_score += signature.instability_modifier
		result.instability_label = instability_calculator.get_label_for_score(result.instability_score)

	_assign_combat_values(result)

	_assign_effect_values(result)
	return result


func preview(sequence: Array) -> SpellResultData:
	return resolve(sequence)


func _assign_combat_values(result: SpellResultData) -> void:
	var damage := 0
	var shield := 0

	if result.has_tag("damage") or result.has_tag("fire") or result.has_tag("shock") or result.has_tag("cut") or result.has_tag("edge"):
		damage += result.power + 2
	if result.has_tag("fire"):
		damage += 2
	if result.has_tag("shock"):
		damage += 3
	if result.has_tag("cut") or result.has_tag("edge"):
		damage += 2
	if result.is_signature:
		damage += 3

	if result.has_tag("shield") or result.has_tag("protection") or result.has_tag("ward"):
		shield += result.power + 4
	if result.has_tag("light"):
		shield += 2
	if result.is_signature and shield > 0:
		shield += 3

	result.damage = damage
	result.shield = shield
	result.affects_enemy = damage > 0
	result.affects_self = result.instability_label == "Unstable" or result.instability_label == "Forbidden"


func _assign_effect_values(result: SpellResultData) -> void:
	var has_damage_tags := result.has_tag("damage") or result.has_tag("fire") or result.has_tag("shock") or result.has_tag("cut") or result.has_tag("edge") or result.has_tag("projectile")
	var has_shield_tags := result.has_tag("shield") or result.has_tag("protection") or result.has_tag("ward") or result.has_tag("light")
	var has_damage := result.damage > 0 or has_damage_tags
	var has_shield := result.shield > 0 or has_shield_tags

	if has_damage and has_shield:
		result.effect_type = "projectile_plus_shield"
		result.effect_kind = "mixed"
	elif has_shield:
		result.effect_type = "shield"
		result.effect_kind = "shield"
	elif has_damage:
		result.effect_type = "projectile"
		result.effect_kind = "projectile"
	else:
		result.effect_type = "fizzle"
		result.effect_kind = "pulse"

	result.effect_speed = 650.0
	result.effect_radius = 8.0
	result.effect_lifetime = 0.9
	result.projectile_speed = result.effect_speed
	result.projectile_lifetime = result.effect_lifetime
	result.projectile_size = result.effect_radius

	if result.has_tag("shock") or result.has_tag("unstable"):
		result.effect_color = Color(0.45, 0.7, 1.0, 0.95)
		result.effect_speed = 760.0
		result.effect_radius = 9.0
	elif result.has_tag("fire"):
		result.effect_color = Color(1.0, 0.42, 0.12, 0.95)
	elif result.has_tag("cut") or result.has_tag("edge"):
		result.effect_color = Color(0.95, 0.72, 0.68, 0.95)
	elif result.has_tag("shield") or result.has_tag("protection") or result.has_tag("ward") or result.has_tag("light"):
		result.effect_color = Color(1.0, 0.88, 0.52, 0.9)
	elif result.has_tag("stone"):
		result.effect_color = Color(0.55, 0.5, 0.43, 0.95)
	else:
		result.effect_color = Color(0.78, 0.62, 1.0, 0.85)

	if result.is_signature:
		result.effect_radius += 3.0
	if result.instability_label == "Unstable" or result.instability_label == "Forbidden":
		result.effect_radius += 4.0

	result.projectile_speed = result.effect_speed
	result.projectile_lifetime = result.effect_lifetime
	result.projectile_size = result.effect_radius
