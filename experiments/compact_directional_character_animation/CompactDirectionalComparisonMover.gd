extends CharacterBody2D

## Moves one comparison body and forwards the same actual motion to both isolated rigs.

@export_range(0.0, 1000.0, 1.0) var movement_speed := 220.0

@onready var _original_rig := get_node_or_null(^"OriginalRigMount/DirectionalHumanoidRig")
@onready var _compact_rig := get_node_or_null(^"CompactRigMount/CompactDirectionalHumanoidRig")


func _ready() -> void:
	if not _is_valid_rig(_original_rig) or not _is_valid_rig(_compact_rig):
		push_error("CompactDirectionalComparisonMover requires both directional rig children.")
		set_physics_process(false)
		return
	_original_rig.call(&"set_debug_bones_visible", true)
	_compact_rig.call(&"set_debug_bones_visible", true)


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	velocity = (
		input_direction.normalized() * movement_speed
		if not input_direction.is_zero_approx()
		else Vector2.ZERO
	)
	move_and_slide()
	_original_rig.call(&"set_motion", velocity)
	_compact_rig.call(&"set_motion", velocity)


func _is_valid_rig(candidate: Node) -> bool:
	return (
		candidate != null
		and candidate.has_method(&"set_motion")
		and candidate.has_method(&"set_debug_bones_visible")
	)
