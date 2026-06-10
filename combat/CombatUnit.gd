extends Node
class_name CombatUnit

signal unit_damaged(unit: CombatUnit, amount: int)
signal unit_healed(unit: CombatUnit, amount: int)
signal unit_died(unit: CombatUnit)
signal zone_changed(unit: CombatUnit, old_zone: CombatZone, new_zone: CombatZone)

enum Team {
	HERO,
	ENEMY
}

@export var unit_name: String
@export var team: Team = Team.HERO
@export var max_hp: int = 10
@export var starting_zone_id: StringName

var current_hp: int
var current_zone: CombatZone
var is_alive: bool = true
var status_effects: Array[StringName] = []


func _ready() -> void:
	current_hp = max_hp
	is_alive = current_hp > 0
	add_to_group("combat_units")


func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	var applied := mini(amount, current_hp)
	current_hp -= applied
	unit_damaged.emit(self, applied)
	if current_hp <= 0:
		die()
	elif current_zone != null:
		current_zone.refresh_display()


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	var old_hp := current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var applied := current_hp - old_hp
	if applied > 0:
		unit_healed.emit(self, applied)
		if current_zone != null:
			current_zone.refresh_display()


func move_to_zone(zone: CombatZone) -> bool:
	if not is_alive or zone == null or not zone.can_enter():
		return false
	if current_zone == zone:
		return true

	var old_zone := current_zone
	if old_zone != null:
		old_zone.remove_unit(self)
	current_zone = zone
	current_zone.add_unit(self)
	zone_changed.emit(self, old_zone, current_zone)
	return true


func apply_status(status_id: StringName) -> void:
	if not status_id.is_empty() and not status_effects.has(status_id):
		status_effects.append(status_id)


func remove_status(status_id: StringName) -> void:
	status_effects.erase(status_id)


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	current_hp = 0
	if current_zone != null:
		var old_zone := current_zone
		current_zone = null
		old_zone.remove_unit(self)
	unit_died.emit(self)
