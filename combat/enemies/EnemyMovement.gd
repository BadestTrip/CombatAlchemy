class_name EnemyMovement
extends Node

# Responsibility: Execute normalized movement requests with CharacterBody2D collision.

var desired_velocity := Vector2.ZERO
var _body: CharacterBody2D
var _speed: float


## Binds the actor body and shared profile speed without changing the Player controller.
func configure(body: CharacterBody2D, speed: float) -> void:
	_body = body
	_speed = maxf(0.0, speed)


## Requests world-space movement, with equal speed on every axis.
func move_in_direction(direction: Vector2) -> void:
	desired_velocity = direction.normalized() * _speed


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
