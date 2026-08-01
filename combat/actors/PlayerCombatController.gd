class_name PlayerCombatController
extends CharacterBody2D

# Responsibility: Move the player actor and provide world-space potion throw vectors.

## Emitted after each physics update with the velocity actually applied to the player.
signal movement_changed(current_velocity: Vector2)

## Movement speed in pixels per second.
@export_range(0.0, 1000.0, 1.0) var speed: float = 220.0

var _movement_locked := false


func _physics_process(_delta: float) -> void:
	var movement := (
		Vector2.ZERO
		if _movement_locked
		else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	)
	velocity = movement * speed
	move_and_slide()
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
	return global_position


## Returns a normalized direction toward the global mouse, or right when it overlaps the origin.
func get_throw_direction() -> Vector2:
	var direction := get_global_mouse_position() - get_throw_origin()
	if direction.length_squared() <= 0.000001:
		return Vector2.RIGHT
	return direction.normalized()
