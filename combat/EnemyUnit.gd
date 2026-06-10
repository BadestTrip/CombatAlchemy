extends CombatUnit
class_name EnemyUnit

@export var enemy_type: StringName
@export var min_damage: int = 2
@export var max_damage: int = 4

var current_intent: Dictionary = {}


func _ready() -> void:
	team = Team.ENEMY
	super._ready()
	add_to_group("enemies")


func generate_intent(living_heroes: Array[HeroUnit]) -> Dictionary:
	current_intent.clear()
	if not is_alive or living_heroes.is_empty():
		return current_intent

	var target: HeroUnit = living_heroes.pick_random()
	var damage := randi_range(min_damage, max_damage)
	current_intent = {
		"type": &"attack",
		"target": target,
		"damage": damage,
		"description": "%s intends to attack %s for %d" % [
			unit_name,
			target.unit_name,
			damage
		]
	}
	return current_intent


func execute_intent() -> Dictionary:
	if not is_alive or current_intent.is_empty():
		return {}

	var target := current_intent.get("target") as HeroUnit
	if target == null or not target.is_alive:
		return {}

	var damage := int(current_intent.get("damage", min_damage))
	target.take_damage(damage)
	return {
		"type": &"unit_damaged",
		"source": self,
		"target": target,
		"zone": target.current_zone,
		"amount": damage,
		"log": "%s attacks %s for %d damage." % [unit_name, target.unit_name, damage]
	}
