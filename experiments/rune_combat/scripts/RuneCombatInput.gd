extends Node
class_name RuneCombatInput

signal rune_index_selected(index: int)
signal cast_requested
signal clear_requested
signal remove_last_requested
signal wheel_toggle_requested


func _ready() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				rune_index_selected.emit(0)
			KEY_2:
				rune_index_selected.emit(1)
			KEY_3:
				rune_index_selected.emit(2)
			KEY_4:
				rune_index_selected.emit(3)
			KEY_5:
				rune_index_selected.emit(4)
			KEY_SPACE:
				cast_requested.emit()
			KEY_C:
				clear_requested.emit()
			KEY_BACKSPACE:
				remove_last_requested.emit()
			KEY_TAB:
				wheel_toggle_requested.emit()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		wheel_toggle_requested.emit()
