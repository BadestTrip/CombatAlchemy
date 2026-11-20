class_name BrewingReaction
extends Node

# Responsibility: Simulate two boiling checks independently of recipes, input and UI.

enum State { IDLE, HEATING, RESETTING, COMPLETED }

signal state_changed(state: State)
signal reaction_changed(height: float, power: float, blend: float)
signal check_completed(index: int, score: int)
signal completed(score: int)

@export var profile: BrewingProfileData

const CHECK_COUNT := 2
const TIME_EPSILON := 0.000000000001
const BLEND_HEIGHT := 0.7
const UNFINISHED_BLEND_MAX := 0.999999

var _state := State.IDLE
var _progress := 0.0
var _heat_power := 0.5
var _heat_enabled := true
var _suspended := false
var _cycle_index := 0
var _quality_score := 0
var _blend_progress := 0.0
var _results: Array[int] = []
var _reset_elapsed := 0.0
var _reset_start_height := 0.0
var _reset_start_blend := 0.0


func _ready() -> void:
	if not _has_valid_profile():
		push_error("BrewingReaction requires a valid BrewingProfileData resource.")
		set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func start() -> bool:
	if _suspended or _state != State.IDLE or not _has_valid_profile():
		return false
	_set_state(State.HEATING)
	_emit_reaction_changed()
	return true


func release_pressure() -> bool:
	if _suspended or _state != State.HEATING or not _has_valid_profile():
		return false
	_finish_check(_score_height())
	return true


func set_heat_power(power: float) -> void:
	if not is_finite(power):
		return
	var normalized := clampf(power, 0.0, 1.0)
	if _heat_power == normalized:
		return
	_heat_power = normalized
	_emit_reaction_changed()


func set_heat_enabled(enabled: bool) -> void:
	if _heat_enabled == enabled:
		return
	_heat_enabled = enabled
	_emit_reaction_changed()


func is_heat_enabled() -> bool:
	return _heat_enabled


func set_suspended(suspended: bool) -> void:
	_suspended = suspended


## Consume time up to each transition, then carry the remainder into the next state.
func advance(delta: float) -> void:
	if _suspended or not is_finite(delta) or delta <= 0.0 or not _has_valid_profile():
		return
	var remaining := delta
	while remaining > 0.0 and not _suspended:
		match _state:
			State.HEATING:
				if not _heat_enabled or _heat_power == 0.0:
					break
				var rate := profile.rise_rate * _heat_power
				var until_overflow := (1.0 - _progress) / rate
				var consumed := minf(remaining, until_overflow)
				_progress = minf(1.0, _progress + rate * consumed)
				remaining = maxf(0.0, remaining - consumed)
				_update_heating_blend()
				if consumed + TIME_EPSILON >= until_overflow:
					_progress = 1.0
					_finish_check(-1)
				else:
					_emit_reaction_changed()
			State.RESETTING:
				var until_reset := maxf(0.0, profile.reset_duration - _reset_elapsed)
				var consumed := minf(remaining, until_reset)
				_reset_elapsed += consumed
				remaining = maxf(0.0, remaining - consumed)
				if consumed + TIME_EPSILON >= until_reset:
					_finish_reset()
				else:
					var fraction := _reset_elapsed / profile.reset_duration
					var eased := fraction * fraction * (3.0 - 2.0 * fraction)
					_progress = _reset_start_height * (1.0 - eased)
					var target_blend := float(_cycle_index + 1) / CHECK_COUNT
					_raise_blend(lerpf(_reset_start_blend, target_blend, eased))
					_emit_reaction_changed()
			_:
				break


## Clear this brew, retaining the user's power setting and external suspension state.
func cancel() -> void:
	_progress = 0.0
	_cycle_index = 0
	_quality_score = 0
	_blend_progress = 0.0
	_results.clear()
	_reset_elapsed = 0.0
	_reset_start_height = 0.0
	_reset_start_blend = 0.0
	_set_state(State.IDLE)
	_emit_reaction_changed()


func get_state() -> State:
	return _state


func get_progress() -> float:
	return _progress


func get_heat_power() -> float:
	return _heat_power


func get_cycle_index() -> int:
	return _cycle_index


func get_quality_score() -> int:
	return _quality_score


func get_blend_progress() -> float:
	return _blend_progress


func get_results() -> Array[int]:
	return _results.duplicate()


func is_editable() -> bool:
	return _state == State.IDLE


func _score_height() -> int:
	return profile.score_height(_progress)


func _finish_check(score: int) -> void:
	var index := _cycle_index
	_results.append(score)
	_quality_score += score
	_reset_elapsed = 0.0
	_reset_start_height = _progress
	_reset_start_blend = _blend_progress
	_set_state(State.RESETTING)
	_emit_reaction_changed()
	check_completed.emit(index, score)
	if _state == State.RESETTING and profile.reset_duration == 0.0:
		_finish_reset()


func _finish_reset() -> void:
	_progress = 0.0
	_reset_elapsed = 0.0
	_cycle_index += 1
	if _cycle_index == CHECK_COUNT:
		_blend_progress = 1.0
		_set_state(State.COMPLETED)
		_emit_reaction_changed()
		completed.emit(_quality_score)
	else:
		_raise_blend(float(_cycle_index) / CHECK_COUNT)
		_set_state(State.HEATING)
		_emit_reaction_changed()


func _update_heating_blend() -> void:
	_raise_blend((float(_cycle_index) + minf(_progress / BLEND_HEIGHT, 1.0)) / CHECK_COUNT)


func _raise_blend(value: float) -> void:
	_blend_progress = maxf(_blend_progress, minf(value, UNFINISHED_BLEND_MAX))


func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	_state = next_state
	state_changed.emit(_state)


func _emit_reaction_changed() -> void:
	reaction_changed.emit(_progress, _heat_power, _blend_progress)


func _has_valid_profile() -> bool:
	return profile != null and profile.is_valid()
