extends Node
class_name CombatUnit

signal changed
signal defeated

@export var display_name: String = "Unit"
@export var max_hp: int = 40
@export var hp: int = 40
@export var shield: int = 0


func _ready() -> void:
	hp = clampi(hp, 1, max_hp)
	changed.emit()


func reset_unit(new_max_hp: int = -1) -> void:
	if new_max_hp > 0:
		max_hp = new_max_hp
	hp = max_hp
	shield = 0
	changed.emit()


func take_damage(amount: int) -> int:
	var remaining_damage := maxi(0, amount)
	if remaining_damage == 0:
		return 0

	var absorbed := mini(shield, remaining_damage)
	shield -= absorbed
	remaining_damage -= absorbed

	if remaining_damage > 0:
		hp = maxi(0, hp - remaining_damage)

	changed.emit()
	if hp <= 0:
		defeated.emit()
	return remaining_damage


func gain_shield(amount: int) -> void:
	shield += maxi(0, amount)
	changed.emit()


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + maxi(0, amount))
	changed.emit()


func get_status_text() -> String:
	return "%s HP %d/%d  Shield %d" % [display_name, hp, max_hp, shield]
