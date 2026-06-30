extends Node
class_name SpellResolver

@export var grammar_interpreter_path: NodePath
@export var signature_resolver_path: NodePath
@export var instability_calculator_path: NodePath
@export var combat_rule_controller_path: NodePath

@onready var grammar_interpreter: RuneGrammarInterpreter = get_node(grammar_interpreter_path) as RuneGrammarInterpreter
@onready var signature_resolver: SignatureSpellResolver = get_node(signature_resolver_path) as SignatureSpellResolver
@onready var instability_calculator: InstabilityCalculator = get_node(instability_calculator_path) as InstabilityCalculator
@onready var combat_rule_controller: CombatRuleController = get_node_or_null(combat_rule_controller_path) as CombatRuleController


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

	if combat_rule_controller != null:
		result = combat_rule_controller.apply_rules(result, context)
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
