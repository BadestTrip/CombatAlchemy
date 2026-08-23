extends CharacterBody2D

@export_range(0.0, 1000.0, 1.0) var movement_speed := 220.0
@export var player_model_path: NodePath = ^"PlayerModel"

@onready var _player_model := get_node_or_null(player_model_path)


func _ready() -> void:
	if _player_model == null or not _player_model.has_method(&"set_motion"):
		push_error("PlayerModelWorkshopActor requires a PlayerModel with set_motion().")
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction.normalized() * movement_speed if not direction.is_zero_approx() else Vector2.ZERO
	move_and_slide()
	_player_model.call(&"set_motion", velocity)
