class_name PlayerCombatController
extends CharacterBody2D

# Responsibility: Move the player actor and provide world-space potion throw vectors.

## Emitted after each physics update with the velocity actually applied to the player.
signal movement_changed(current_velocity: Vector2)

## Movement speed in pixels per second.
@export_range(0.0, 1000.0, 1.0) var speed: float = 220.0
@export var player_model_path: NodePath = ^"PlayerModel"
@export_range(0.0, 1000.0, 1.0) var place_distance: float = 64.0

@onready var _player_model := get_node_or_null(player_model_path)

var _movement_locked := false


func _ready() -> void:
	if _player_model == null or not _player_model.has_method(&"set_motion"):
		push_error("PlayerCombatController requires a PlayerModel with set_motion().")
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var movement := (
		Vector2.ZERO
		if _movement_locked
		else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	)
	velocity = movement * speed
	move_and_slide()
	if _player_model != null:
		_player_model.call(&"set_motion", velocity)
	movement_changed.emit(velocity)


## Enables or disables player-driven movement without changing process mode.
func set_movement_locked(is_locked: bool) -> void:
	_movement_locked = is_locked
	if _movement_locked:
		velocity = Vector2.ZERO


## Returns whether player-driven movement is currently blocked by an action.
func is_movement_locked() -> bool:
	return _movement_locked


## Returns the world-space point where potion projectiles should spawn.
func get_throw_origin() -> Vector2:
	var holder := get_potion_holder()
	if holder != null:
		return holder.global_position
	return global_position


func get_potion_holder() -> Marker2D:
	if _player_model != null and _player_model.has_method(&"get_socket"):
		return _player_model.call(&"get_socket", &"hand_right") as Marker2D
	return null


## Returns a normalized direction toward the global mouse, or right when it overlaps the origin.
func get_throw_direction() -> Vector2:
	var direction := get_global_mouse_position() - get_throw_origin()
	if direction.length_squared() <= 0.000001:
		return Vector2.RIGHT
	return direction.normalized()


func get_place_position() -> Vector2:
	return global_position + get_throw_direction() * place_distance
