extends Resource
class_name CombatAction

var action_id: StringName
var display_name: String
var actor: CombatUnit
var target: Variant
var target_zone: CombatZone
var action_type: StringName
var damage: int = 0
var push_distance: int = 0
var creates_event: StringName


func _init(
	id: StringName = &"",
	label: String = "",
	action_actor: CombatUnit = null,
	action_target: Variant = null,
	zone: CombatZone = null
) -> void:
	action_id = id
	display_name = label
	actor = action_actor
	target = action_target
	target_zone = zone


func get_target_name() -> String:
	if target is CombatUnit:
		return (target as CombatUnit).unit_name
	if target is ReactionObject:
		return (target as ReactionObject).display_name
	if target_zone != null:
		return target_zone.display_name
	return "No target"


func get_summary() -> String:
	if actor == null:
		return display_name
	return "%s: %s -> %s" % [actor.unit_name, display_name, get_target_name()]
