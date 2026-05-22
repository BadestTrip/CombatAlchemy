extends Node
class_name Combatant

@export var display_name: String
@export var max_hp: int
@export var weapon: Weapon

var current_hp: int

func _ready() -> void:
	current_hp = max_hp

func is_dead() -> bool:
	return current_hp <= 0

func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)

func get_attack_verb() -> String:
	if weapon == null:
		return "attacks"
	match weapon.weapon_type:
		"sword":
			return "slashes"
		"axe":
			return "cleaves"
		"club":
			return "smashes"
		"bow":
			return "shoots"
		"staff":
			return "strikes"
		_:
			return "hits"

func attack(target: Combatant) -> String:
	if weapon == null:
		return "%s has no weapon." % display_name

	if randf() > weapon.accuracy:
		return "%s missed with %s!" % [display_name,
		weapon.weapon_name]

	var damage: int = randi_range(weapon.min_damage, weapon.max_damage)
	target.take_damage(damage)

	var verb: String = get_attack_verb()

	return "%s %s %s with %s for %d damage." % [
		display_name,
		verb,
		target.display_name,
		weapon.weapon_name,
		damage
	]
