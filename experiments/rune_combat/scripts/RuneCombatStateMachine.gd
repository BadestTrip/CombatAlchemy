extends Node
class_name RuneCombatStateMachine

signal state_changed(new_state: int)

enum State {
	IDLE,
	WHEEL_OPEN,
	CHANTING,
	CASTING,
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


func close_wheel() -> void:
	if current_state == State.WHEEL_OPEN:
		set_state(State.IDLE)


func begin_chant() -> void:
	if can_accept_chant_input():
		set_state(State.CHANTING)


func begin_cast() -> void:
	if current_state == State.ENDED:
		return
	set_state(State.CASTING)


func finish_recovery() -> void:
	if current_state == State.ENDED:
		return
	set_state(State.IDLE)


func end_combat() -> void:
	set_state(State.ENDED)


func can_accept_chant_input() -> bool:
	return current_state == State.IDLE or current_state == State.WHEEL_OPEN or current_state == State.CHANTING


func get_state_name(state: int) -> String:
	match state:
		State.IDLE:
			return "IDLE"
		State.WHEEL_OPEN:
			return "WHEEL_OPEN"
		State.CHANTING:
			return "CHANTING"
		State.CASTING:
			return "CASTING"
		State.RECOVERING:
			return "RECOVERING"
		State.ENDED:
			return "ENDED"
	return "UNKNOWN"
