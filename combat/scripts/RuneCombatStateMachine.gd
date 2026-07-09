extends Node
class_name RuneCombatStateMachine

signal state_changed(new_state: int)

enum State {
	IDLE,
	WHEEL_OPEN,
	CHANT_PREPARED,
	SHOOTING,
	RECOVERING,
	ENDED,
}

var current_state: int = State.IDLE


func set_state(new_state: int) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(current_state)


func open_wheel() -> void:
	if current_state == State.ENDED:
		return
	set_state(State.WHEEL_OPEN)


func close_wheel(has_prepared_chant: bool = false) -> void:
	if current_state == State.WHEEL_OPEN:
		set_state(State.CHANT_PREPARED if has_prepared_chant else State.IDLE)


func prepare_chant() -> void:
	if current_state == State.WHEEL_OPEN:
		set_state(State.CHANT_PREPARED)


func begin_shoot(has_prepared_chant: bool) -> bool:
	if current_state == State.ENDED or not has_prepared_chant:
		return false
	set_state(State.SHOOTING)
	return true


func finish_recovery() -> void:
	if current_state == State.ENDED:
		return
	set_state(State.IDLE)


func end_combat() -> void:
	set_state(State.ENDED)


func can_accept_chant_input() -> bool:
	return current_state == State.WHEEL_OPEN


func get_state_name(state: int) -> String:
	match state:
		State.IDLE:
			return "IDLE"
		State.WHEEL_OPEN:
			return "WHEEL_OPEN"
		State.CHANT_PREPARED:
			return "CHANT_PREPARED"
		State.SHOOTING:
			return "SHOOTING"
		State.RECOVERING:
			return "RECOVERING"
		State.ENDED:
			return "ENDED"
	return "UNKNOWN"
