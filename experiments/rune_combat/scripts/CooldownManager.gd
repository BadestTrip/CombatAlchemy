extends Node
class_name CooldownManager

var _cooldowns: Dictionary = {}


func is_spell_available(spell_id: String) -> bool:
	return int(_cooldowns.get(spell_id, 0)) <= 0


func set_cooldown(spell_id: String, turns: int) -> void:
	_cooldowns[spell_id] = maxi(0, turns)


func tick_turn() -> void:
	for spell_id in _cooldowns.keys():
		_cooldowns[spell_id] = maxi(0, int(_cooldowns[spell_id]) - 1)
