extends Node2D

## Keeps the minimal comparison HUD synchronized with the compact rig's public state.

@onready var _compact_rig := get_node_or_null(
	^"ComparisonMover/CompactRigMount/CompactDirectionalHumanoidRig"
)
@onready var _locomotion_value: Label = get_node_or_null(
	^"HUD/StatusPanel/StatusRow/LocomotionValue"
) as Label
@onready var _facing_value: Label = get_node_or_null(
	^"HUD/StatusPanel/StatusRow/FacingValue"
) as Label


func _ready() -> void:
	if _compact_rig == null or _locomotion_value == null or _facing_value == null:
		push_error("DirectionalRigComparisonLab requires its compact rig and HUD labels.")
		return
	_compact_rig.facing_changed.connect(_on_facing_changed)
	_compact_rig.locomotion_changed.connect(_on_locomotion_changed)
	_on_facing_changed(_compact_rig.call(&"get_facing") as StringName)
	_on_locomotion_changed(_compact_rig.call(&"get_locomotion_state") as StringName)


func _on_facing_changed(facing: StringName) -> void:
	_facing_value.text = String(facing).to_upper()


func _on_locomotion_changed(state: StringName) -> void:
	_locomotion_value.text = String(state).to_upper()
