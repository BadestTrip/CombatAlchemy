class_name BrewingReaction
extends Node

# Responsibility: Simulate small-flask reaction progress and energy without recipe or UI knowledge.

enum State { IDLE, AGITATING, SETTLING, COOLDOWN, COMPLETED }

signal state_changed(state: State)
signal reaction_changed(progress: float, energy: float, predicted_settled_progress: float)
signal completed
signal overreacted
signal recovered

## Timing and threshold values for this vessel.
@export var profile: BrewingProfileData

const COMPARISON_EPSILON := 0.00001

var _state := State.IDLE
var _progress := 0.0
var _energy := 0.0
var _cooldown_remaining := 0.0


func _ready() -> void:
	if not _has_valid_profile():
		push_error("BrewingReaction requires a valid BrewingProfileData resource.")
		set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_agitation()


## Starts or resumes agitation from an idle or settling reaction.
func start_agitation() -> bool:
	if not _has_valid_profile() or _state not in [State.IDLE, State.SETTLING]:
		return false
	_set_state(State.AGITATING)
	_emit_reaction_changed()
	return true


## Stops adding energy while preserving the reaction's residual motion.
func release_agitation() -> void:
	if _state != State.AGITATING:
		return
	if _energy <= COMPARISON_EPSILON:
		_energy = 0.0
		_set_state(State.IDLE)
	else:
		_set_state(State.SETTLING)
	_emit_reaction_changed()


## Advances simulation using exact linear integration for energy changes.
func advance(delta: float) -> void:
	if delta <= 0.0 or not _has_valid_profile():
		return
	var remaining := delta
	var transition_guard := 0
	while remaining > COMPARISON_EPSILON and transition_guard < 8:
		var previous_state := _state
		var consumed := 0.0
		match _state:
			State.AGITATING:
				consumed = _advance_agitation(remaining)
			State.SETTLING:
				consumed = _advance_settling(remaining)
			State.COOLDOWN:
				consumed = _advance_cooldown(remaining)
			_:
				break
		remaining -= consumed
		transition_guard += 1
		if consumed <= COMPARISON_EPSILON and _state == previous_state:
			break


## Clears all unfinished reaction state.
func cancel() -> void:
	_progress = 0.0
	_energy = 0.0
	_cooldown_remaining = 0.0
	_set_state(State.IDLE)
	_emit_reaction_changed()


func get_state() -> State:
	return _state


func get_progress() -> float:
	return _progress


func get_energy() -> float:
	return _energy


## Predicts the settled progress from current energy using the same linear model as advance().
func get_predicted_settled_progress() -> float:
	if not _has_valid_profile():
		return _progress
	var remaining_progress := (
		profile.progress_rate
		* _energy
		* _energy
		* profile.energy_dissipation_time
		* 0.5
	)
	return _progress + remaining_progress


func is_editable() -> bool:
	return _state == State.IDLE


func _advance_agitation(delta: float) -> float:
	var remaining := delta
	var consumed := 0.0
	if _energy < 1.0:
		var ramp_duration := minf(remaining, (1.0 - _energy) * profile.energy_ramp_time)
		var ramp_gain := _get_ramp_up_progress(ramp_duration)
		if _would_overreact(ramp_gain):
			var crossing_time := _get_ramp_up_time_to_progress(_overreaction_progress_remaining())
			_progress += _get_ramp_up_progress(crossing_time)
			_energy = minf(1.0, _energy + crossing_time / profile.energy_ramp_time)
			_begin_overreaction()
			return crossing_time
		_progress += ramp_gain
		_energy = minf(1.0, _energy + ramp_duration / profile.energy_ramp_time)
		remaining -= ramp_duration
		consumed += ramp_duration
	if remaining > 0.0:
		var steady_gain := profile.progress_rate * _energy * remaining
		if _would_overreact(steady_gain):
			var crossing_time := _overreaction_progress_remaining() / (profile.progress_rate * _energy)
			_progress += profile.progress_rate * _energy * crossing_time
			_begin_overreaction()
			return consumed + crossing_time
		_progress += steady_gain
		consumed += remaining
	_emit_reaction_changed()
	return consumed


func _advance_settling(delta: float) -> float:
	var active_duration := minf(delta, _energy * profile.energy_dissipation_time)
	if active_duration <= COMPARISON_EPSILON:
		_energy = 0.0
		_finish_settling()
		return 0.0
	var settling_gain := _get_settling_progress(active_duration)
	if _would_overreact(settling_gain):
		var crossing_time := _get_settling_time_to_progress(_overreaction_progress_remaining())
		_progress += _get_settling_progress(crossing_time)
		_energy = maxf(0.0, _energy - crossing_time / profile.energy_dissipation_time)
		_begin_overreaction()
		return crossing_time
	_progress += settling_gain
	_energy = maxf(0.0, _energy - active_duration / profile.energy_dissipation_time)
	if _energy <= COMPARISON_EPSILON:
		_energy = 0.0
		_finish_settling()
	else:
		_emit_reaction_changed()
	return active_duration


func _finish_settling() -> void:
	if (
		_progress >= profile.success_min_progress - COMPARISON_EPSILON
		and _progress <= profile.success_max_progress + COMPARISON_EPSILON
	):
		_set_state(State.COMPLETED)
		_emit_reaction_changed()
		completed.emit()
		return
	_set_state(State.IDLE)
	_emit_reaction_changed()


func _begin_overreaction() -> void:
	_energy = 0.0
	_cooldown_remaining = profile.overreaction_cooldown
	_set_state(State.COOLDOWN)
	_emit_reaction_changed()
	overreacted.emit()
	if _cooldown_remaining <= COMPARISON_EPSILON:
		_finish_recovery()


func _advance_cooldown(delta: float) -> float:
	var consumed := minf(delta, _cooldown_remaining)
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - consumed)
	if _cooldown_remaining <= COMPARISON_EPSILON:
		_finish_recovery()
	else:
		_emit_reaction_changed()
	return consumed


func _would_overreact(progress_gain: float) -> bool:
	return _progress + progress_gain > profile.success_max_progress + COMPARISON_EPSILON


func _overreaction_progress_remaining() -> float:
	return maxf(0.0, profile.success_max_progress + COMPARISON_EPSILON - _progress)


func _get_ramp_up_progress(duration: float) -> float:
	return profile.progress_rate * (
		_energy * duration
		+ duration * duration / (2.0 * profile.energy_ramp_time)
	)


func _get_ramp_up_time_to_progress(progress_gain: float) -> float:
	var ramp_time := profile.energy_ramp_time
	var square_root := sqrt(
		_energy * _energy * ramp_time * ramp_time
		+ 2.0 * ramp_time * progress_gain / profile.progress_rate
	)
	return maxf(0.0, square_root - _energy * ramp_time)


func _get_settling_progress(duration: float) -> float:
	return profile.progress_rate * (
		_energy * duration
		- duration * duration / (2.0 * profile.energy_dissipation_time)
	)


func _get_settling_time_to_progress(progress_gain: float) -> float:
	var dissipation_time := profile.energy_dissipation_time
	var energy_time := _energy * dissipation_time
	var discriminant := maxf(
		0.0,
		energy_time * energy_time
		- 2.0 * dissipation_time * progress_gain / profile.progress_rate
	)
	return maxf(0.0, energy_time - sqrt(discriminant))


func _finish_recovery() -> void:
	_progress = profile.recovery_progress
	_energy = 0.0
	_cooldown_remaining = 0.0
	_set_state(State.IDLE)
	_emit_reaction_changed()
	recovered.emit()


func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	_state = next_state
	state_changed.emit(_state)


func _emit_reaction_changed() -> void:
	reaction_changed.emit(_progress, _energy, get_predicted_settled_progress())


func _has_valid_profile() -> bool:
	return profile != null and profile.is_valid()
