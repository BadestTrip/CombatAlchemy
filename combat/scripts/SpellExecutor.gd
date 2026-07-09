extends Node
class_name SpellExecutor

const CHANT_EFFECT_PROJECTILE_SCRIPT := preload("res://combat/scripts/ChantEffectProjectile.gd")


func execute(result: SpellResultData, context: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var player_unit := context.get("player_unit") as CombatUnit
	var enemy_unit := context.get("enemy_unit") as CombatUnit

	var backlash_amount := 0
	if result.instability_label == "Unstable":
		backlash_amount = 5
	elif result.instability_label == "Forbidden":
		backlash_amount = 12

	if backlash_amount > 0 and player_unit != null:
		var self_damage := player_unit.take_damage(backlash_amount)
		lines.append("%s backlash deals %d damage to %s." % [
			result.instability_label,
			self_damage,
			player_unit.display_name
		])

	if player_unit != null and player_unit.hp <= 0:
		_spawn_effect(result, context, "fizzle")
		lines.append("The spell collapses before release.")
		return lines

	if result.shield > 0 and player_unit != null:
		player_unit.gain_shield(result.shield)
		lines.append("%s gains %d shield." % [player_unit.display_name, result.shield])

	if result.effect_type == "projectile_plus_shield":
		_spawn_effect(result, context, "shield")
		_spawn_effect(result, context, "projectile")
	elif result.effect_type == "shield":
		_spawn_effect(result, context, "shield")
	elif result.effect_type == "projectile":
		_spawn_effect(result, context, "projectile")
	else:
		_spawn_effect(result, context, "fizzle")

	if result.damage > 0 and result.effect_type.begins_with("projectile"):
		lines.append("%s flies toward the mouse aim." % result.display_name)
	elif result.damage > 0 and enemy_unit != null:
		var hp_damage := enemy_unit.take_damage(result.damage)
		lines.append("%s takes %d damage." % [enemy_unit.display_name, hp_damage])
	elif result.shield <= 0:
		lines.append("The chant releases a visible but weak magical effect.")

	if result.instability_label == "Strained":
		lines.append("The chant strains but holds.")

	if lines.is_empty():
		lines.append("The chant fizzles without a combat effect.")
	return lines


func _spawn_effect(result: SpellResultData, context: Dictionary, effect_type_override: String = "") -> void:
	var effects_parent := context.get("effects_parent") as Node
	if effects_parent == null:
		return

	var effect := CHANT_EFFECT_PROJECTILE_SCRIPT.new() as SimpleChantEffect
	effects_parent.add_child(effect)
	effect.setup(result, context, effect_type_override)
