class_name StatusEffectComponent
extends Node

# Responsibility: Own timed actor statuses and expose their current gameplay values.

signal statuses_changed(active_statuses: Array[Dictionary])

const SLOW_STATUS_ID: StringName = &"slow"
const SLOW_COLOR := Color("a855f7")
const MAX_SLOW_REDUCTION := 0.80

var _slow_start_reduction := 0.0
var _slow_duration := 0.0
var _slow_elapsed := 0.0


func _process(delta: float) -> void:
	advance(delta)


## Adds slow to the current reduction, clamps it, and refreshes its decay duration.
func apply_slow(reduction: float, duration: float) -> bool:
	if reduction <= 0.0 or duration <= 0.0:
		return false
	_slow_start_reduction = clampf(get_slow_reduction() + reduction, 0.0, MAX_SLOW_REDUCTION)
	_slow_duration = duration
	_slow_elapsed = 0.0
	_emit_statuses_changed()
	return true


## Advances status timers deterministically for tests and regular process updates.
func advance(delta: float) -> void:
	if _slow_duration <= 0.0:
		return
	var previous_reduction := get_slow_reduction()
	_slow_elapsed = minf(_slow_elapsed + maxf(0.0, delta), _slow_duration)
	if is_zero_approx(get_slow_reduction()):
		_slow_start_reduction = 0.0
		_slow_duration = 0.0
		_slow_elapsed = 0.0
	if not is_equal_approx(previous_reduction, get_slow_reduction()) or is_zero_approx(get_slow_reduction()):
		_emit_statuses_changed()


## Returns movement speed as a multiplier after all current status effects.
func get_speed_multiplier() -> float:
	return 1.0 - get_slow_reduction()


## Returns the current movement reduction from zero through the configured cap.
func get_slow_reduction() -> float:
	if _slow_duration <= 0.0:
		return 0.0
	return _slow_start_reduction * get_remaining_ratio()


## Returns remaining slow duration from zero through one.
func get_remaining_ratio() -> float:
	if _slow_duration <= 0.0:
		return 0.0
	return clampf(1.0 - _slow_elapsed / _slow_duration, 0.0, 1.0)


## Returns display-ready snapshots without exposing mutable runtime state.
func get_active_statuses() -> Array[Dictionary]:
	var reduction := get_slow_reduction()
	if reduction <= 0.0:
		return []
	return [{
		"status_id": SLOW_STATUS_ID,
		"color": SLOW_COLOR,
		"remaining_ratio": get_remaining_ratio(),
		"strength_ratio": reduction / MAX_SLOW_REDUCTION,
	}]


func _emit_statuses_changed() -> void:
	statuses_changed.emit(get_active_statuses())
