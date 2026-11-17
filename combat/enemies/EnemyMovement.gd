class_name EnemyMovement
extends Node

# Responsibility: Execute normalized enemy movement with CharacterBody2D collision.

var desired_velocity := Vector2.ZERO
var _body: CharacterBody2D
var _speed := 0.0
var _status_effects: Node


## Binds the actor body, profile speed, and optional target-owned status capability.
func configure(body: CharacterBody2D, speed: float, status_effects: Node = null) -> void:
	_body = body
	_speed = maxf(0.0, speed)
	_status_effects = status_effects


## Requests world-space movement, with equal speed on every axis.
func move_in_direction(direction: Vector2) -> void:
	desired_velocity = direction.normalized() * _speed * _get_speed_multiplier()


## Stops both the pending request and current actor velocity.
func stop() -> void:
	desired_velocity = Vector2.ZERO
	if is_instance_valid(_body):
		_body.velocity = Vector2.ZERO


## Called exactly once by the actor during physics processing.
func advance() -> void:
	if not is_instance_valid(_body):
		return
	_body.velocity = desired_velocity
	_body.move_and_slide()


func _get_speed_multiplier() -> float:
	if _status_effects != null and _status_effects.has_method(&"get_speed_multiplier"):
		return _status_effects.call(&"get_speed_multiplier") as float
	return 1.0
