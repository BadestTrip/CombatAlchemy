extends Node
class_name ReactionObject

signal object_destroyed(object: ReactionObject)

@export var object_id: StringName
@export var display_name: String
@export var object_type: StringName
@export var starting_zone_id: StringName
@export var target_zone_id: StringName

var current_zone: CombatZone
var state: StringName = &"idle"
var is_destroyed: bool = false
var trigger_types: Array[StringName] = []


func _ready() -> void:
	add_to_group("reaction_objects")
	_configure_trigger_types()


func move_to_zone(zone: CombatZone) -> void:
	if current_zone != null:
		current_zone.remove_object(self)
	current_zone = zone
	if current_zone != null:
		current_zone.add_object(self)


func receive_event(event_data: Dictionary) -> bool:
	if is_destroyed:
		return false
	var event_type := StringName(event_data.get("type", &""))
	return trigger_types.has(event_type)


func trigger_reaction(_event_data: Dictionary) -> void:
	if not is_destroyed:
		state = &"triggered"


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	state = &"destroyed"
	if current_zone != null:
		var old_zone := current_zone
		current_zone = null
		old_zone.remove_object(self)
	object_destroyed.emit(self)


func _configure_trigger_types() -> void:
	match object_type:
		&"oil_jar":
			trigger_types = [&"object_hit"]
		&"campfire":
			trigger_types = [&"object_hit", &"unit_pushed"]
		&"explosive_barrel":
			trigger_types = [&"object_ignited", &"explosion_created"]
		&"rope_log":
			trigger_types = [&"rope_cut"]
		&"weak_bridge":
			trigger_types = [&"explosion_created", &"fire_created", &"round_end"]
		_:
			trigger_types = []
