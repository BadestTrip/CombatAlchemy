extends CharacterBody2D

## Moves the isolated lab actor and forwards actual velocity to the directional rig.

@export_range(0.0, 1000.0, 1.0) var movement_speed := 220.0

@onready var _rig := get_node_or_null(^"DirectionalHumanoidRig")


func _ready() -> void:
	if _rig == null or not _rig.has_method(&"set_motion"):
		push_error("DirectionalLabActor requires a DirectionalHumanoidRig child.")
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	velocity = input_direction * movement_speed
	move_and_slide()
	_rig.call(&"set_motion", velocity)
