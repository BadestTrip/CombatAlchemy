extends Node
class_name RuneCombatInput

signal wheel_open_requested
signal wheel_close_requested
signal rune_index_selected(index: int)
signal chant_prepare_requested
signal shoot_requested
signal clear_requested
signal remove_last_requested

var _wheel_is_open: bool = false


func _ready() -> void:
	set_process_unhandled_input(true)


func set_wheel_open(is_open: bool) -> void:
	_wheel_is_open = is_open


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_TAB:
			if not event.pressed:
				return
			_wheel_is_open = not _wheel_is_open
			if _wheel_is_open:
				wheel_open_requested.emit()
			else:
				wheel_close_requested.emit()
			return

		if not event.pressed:
			return

		match event.keycode:
			KEY_1:
				_emit_rune_index_if_open(0)
			KEY_2:
				_emit_rune_index_if_open(1)
			KEY_3:
				_emit_rune_index_if_open(2)
			KEY_4:
				_emit_rune_index_if_open(3)
			KEY_5:
				_emit_rune_index_if_open(4)
			KEY_SPACE:
				if _wheel_is_open:
					chant_prepare_requested.emit()
				else:
					shoot_requested.emit()
			KEY_C:
				clear_requested.emit()
			KEY_BACKSPACE:
				if _wheel_is_open:
					remove_last_requested.emit()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _wheel_is_open:
			shoot_requested.emit()


func _emit_rune_index_if_open(index: int) -> void:
	if _wheel_is_open:
		rune_index_selected.emit(index)
