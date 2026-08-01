extends Node2D

## Displays the current locomotion and facing state in the isolated movement room.

@onready var _rig := get_node_or_null(
	^"DirectionalLabActor/DirectionalHumanoidRig"
)
@onready var _locomotion_value := get_node_or_null(
	^"HUD/StatusPanel/StatusRow/LocomotionValue"
) as Label
@onready var _facing_value := get_node_or_null(
	^"HUD/StatusPanel/StatusRow/FacingValue"
) as Label


func _ready() -> void:
	if not _validate_dependencies():
		return
	_rig.connect(&"locomotion_changed", _on_locomotion_changed)
	_rig.connect(&"facing_changed", _on_facing_changed)
	_on_locomotion_changed(_rig.call(&"get_locomotion_state") as StringName)
	_on_facing_changed(_rig.call(&"get_facing") as StringName)


func _on_locomotion_changed(state: StringName) -> void:
	_locomotion_value.text = String(state).to_upper()


func _on_facing_changed(facing: StringName) -> void:
	_facing_value.text = String(facing).replace("_", " ").to_upper()


func _validate_dependencies() -> bool:
	var missing: Array[String] = []
	if _rig == null:
		missing.append("DirectionalHumanoidRig")
	elif not _rig.has_signal(&"locomotion_changed") or not _rig.has_signal(&"facing_changed"):
		missing.append("directional rig signals")
	if _locomotion_value == null:
		missing.append("LocomotionValue")
	if _facing_value == null:
		missing.append("FacingValue")
	if missing.is_empty():
		return true
	push_error("DirectionalAnimationLab requires: %s." % ", ".join(missing))
	return false
