extends Node2D

## Synchronizes the workshop HUD with the canonical PlayerModel public interface.

@onready var _player_model: Node = get_node_or_null(^"WorkshopActor/PlayerModel")
@onready var _facing_value: Label = get_node_or_null(
	^"HUD/StatusPanel/StatusRow/FacingValue"
) as Label
@onready var _locomotion_value: Label = get_node_or_null(
	^"HUD/StatusPanel/StatusRow/LocomotionValue"
) as Label
@onready var _bones_toggle: CheckButton = get_node_or_null(
	^"HUD/StatusPanel/StatusRow/BonesToggle"
) as CheckButton


func _ready() -> void:
	if not _has_required_nodes_and_interface():
		push_error("PlayerModelWorkshop requires its canonical model and compact HUD controls.")
		return

	_player_model.connect(&"facing_changed", _on_facing_changed)
	_player_model.connect(&"locomotion_changed", _on_locomotion_changed)
	_bones_toggle.toggled.connect(_on_bones_toggled)
	_on_facing_changed(_player_model.call(&"get_facing") as StringName)
	_on_locomotion_changed(_player_model.call(&"get_locomotion_state") as StringName)
	_on_bones_toggled(_bones_toggle.button_pressed)


func _has_required_nodes_and_interface() -> bool:
	return (
		_player_model != null
		and _player_model.has_method(&"get_facing")
		and _player_model.has_method(&"get_locomotion_state")
		and _player_model.has_method(&"set_debug_bones_visible")
		and _player_model.has_signal(&"facing_changed")
		and _player_model.has_signal(&"locomotion_changed")
		and _facing_value != null
		and _locomotion_value != null
		and _bones_toggle != null
	)


func _on_facing_changed(facing: StringName) -> void:
	_facing_value.text = String(facing).to_upper()


func _on_locomotion_changed(state: StringName) -> void:
	_locomotion_value.text = String(state).to_upper()


func _on_bones_toggled(is_pressed: bool) -> void:
	_player_model.call(&"set_debug_bones_visible", is_pressed)
