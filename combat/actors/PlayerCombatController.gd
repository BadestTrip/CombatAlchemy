class_name PlayerCombatController
extends CharacterBody2D

# Responsibility: Move the player actor and provide world-space potion throw vectors.

## Movement speed in pixels per second.
@export_range(0.0, 1000.0, 1.0) var speed: float = 220.0


func _physics_process(_delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = movement * speed
	move_and_slide()


## Returns the world-space point where potion projectiles should spawn.
func get_throw_origin() -> Vector2:
	return global_position


## Returns a normalized direction toward the global mouse, or right when it overlaps the origin.
func get_throw_direction() -> Vector2:
	var direction := get_global_mouse_position() - get_throw_origin()
	if direction.length_squared() <= 0.000001:
		return Vector2.RIGHT
	return direction.normalized()
