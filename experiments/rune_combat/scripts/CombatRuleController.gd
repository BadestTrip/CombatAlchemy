extends Node
class_name CombatRuleController

@export var rules: CombatRuleData


func apply_rules(result: SpellResultData, _context: Dictionary) -> SpellResultData:
	# Placeholder: later architecture can inspect turn rules, arenas, silence, cooldowns, or modifiers here.
	if rules != null and not rules.allow_signature_spells and result.is_signature:
		result.is_signature = false
		result.signature_id = ""
		result.display_name = result.generated_name
	return result
