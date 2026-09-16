class_name EnemySenses
extends Node

# Responsibility: Track one assigned living target using distance hysteresis, not global scans.

var distance_to_target: float = INF
var direction_to_target: Vector2 = Vector2.RIGHT
var _target: Node2D
var _health: HealthComponent
var _engaged := false


## Replaces this enemy's target and forgets previous engagement.
func set_target(target: Node2D) -> void:
	_target = target
	_health = null
	_engaged = false
	if is_instance_valid(target):
		for child in target.get_children():
			if child is HealthComponent:
				_health = child
				break


## Refreshes sensing once per actor physics update.
func refresh(origin: Vector2, profile: EnemyProfileData) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_health) or _health.current_health <= 0:
		_engaged = false
		distance_to_target = INF
		return
	var offset := _target.global_position - origin
	distance_to_target = offset.length()
	if not offset.is_zero_approx():
		direction_to_target = offset.normalized()
	if _engaged:
		_engaged = distance_to_target <= profile.disengage_distance
	else:
		_engaged = distance_to_target <= profile.notice_distance


## Returns only an acquired, living target.
func get_target() -> Node2D:
	return _target if _engaged and is_instance_valid(_target) else null
