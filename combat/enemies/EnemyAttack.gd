class_name EnemyAttack
extends Node2D

# Responsibility: Own cancellable windup/recovery timing and animate authored attack indicators.

enum Phase { IDLE, WINDUP, RECOVERY }

## Reports action execution, including a melee miss, exactly once per accepted windup.
signal executed

var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
var _actor: Node2D
var _profile: EnemyProfileData
var _target: Node2D
var _target_health: HealthComponent
var _direction := Vector2.RIGHT
var _telegraph: Node2D
var _impact_flash: Node2D


## Validates and binds the owner, tuning and scene-authored feedback.
func configure(actor: Node2D, profile: EnemyProfileData) -> bool:
	_actor = actor
	_profile = profile
	_telegraph = get_node_or_null(^"Telegraph") as Node2D
	_impact_flash = get_node_or_null(^"ImpactFlash") as Node2D
	if _telegraph == null or _impact_flash == null:
		push_error("EnemyAttack requires scene-authored Telegraph and ImpactFlash nodes.")
		return false
	cancel()
	return true


## Captures one living target and aim direction; busy actions cannot be restarted.
func try_start(target: Node2D) -> bool:
	if is_busy() or not is_instance_valid(_actor) or not is_instance_valid(target) or _profile == null:
		return false
	_target_health = null
	for child in target.get_children():
		if child is HealthComponent:
			_target_health = child
			break
	if _target_health == null or _target_health.current_health <= 0:
		return false
	_target = target
	_direction = _actor.global_position.direction_to(target.global_position)
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	rotation = _direction.angle()
	_phase = Phase.WINDUP
	_elapsed = 0.0
	_update_feedback()
	return true


## Advances the real action timeline, retaining remainder when a frame crosses a boundary.
func advance(delta: float) -> void:
	if not is_busy():
		return
	if not is_instance_valid(_target) or not is_instance_valid(_target_health) or _target_health.current_health <= 0:
		cancel()
		return
	_elapsed += maxf(0.0, delta)
	if _phase == Phase.WINDUP and _elapsed + 0.000001 >= _profile.windup_time:
		_elapsed = maxf(0.0, _elapsed - _profile.windup_time)
		# Enter recovery before execution, so callbacks cannot commit this action twice.
		_phase = Phase.RECOVERY
		_execute()
		executed.emit()
	if _phase == Phase.RECOVERY and _elapsed + 0.000001 >= _profile.recovery_time:
		cancel()
	_update_feedback()


## True throughout windup and recovery.
func is_busy() -> bool:
	return _phase != Phase.IDLE


## Cancels an uncommitted action and clears its presentation; released projectiles are independent.
func cancel() -> void:
	_phase = Phase.IDLE
	_elapsed = 0.0
	_target = null
	_target_health = null
	if is_instance_valid(_telegraph):
		_telegraph.hide()
	if is_instance_valid(_impact_flash):
		_impact_flash.hide()


func _execute() -> void:
	pass


func _update_feedback() -> void:
	_telegraph.visible = _phase == Phase.WINDUP
	if _phase == Phase.WINDUP:
		_telegraph.modulate.a = lerpf(0.3, 0.95, clampf(_elapsed / _profile.windup_time, 0.0, 1.0))
	_impact_flash.visible = _phase == Phase.RECOVERY and _elapsed < 0.12
