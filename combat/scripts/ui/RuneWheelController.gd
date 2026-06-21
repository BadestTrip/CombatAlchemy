extends Control
class_name RuneWheelController


signal rune_selected(rune_data: SymbolCardData)
signal wheel_expanded
signal wheel_retracted


@export_group("Data")
@export var symbol_library: SymbolLibraryData

@export_group("Node References")
@export var rune_button_container: Control
@export var toggle_button: Button

@export_group("Wheel Layout")
@export var wheel_radius: float = 500.0
@export var rune_button_size: Vector2 = Vector2(90.0, 90.0)
@export var start_angle_degrees: float = -90.0
@export var clockwise: bool = true

@export_group("Wheel Behavior")
@export var starts_expanded: bool = true
@export var auto_retract_after_rune_pick: bool = false
@export var tween_seconds: float = 0.2

@export_group("Performance")
@export var rebuild_buttons_on_ready_only: bool = true


var _buttons: Array[Button] = []
var _is_expanded: bool = true
var _input_locked: bool = false
var _tween: Tween


func _ready() -> void:
	set_process(false)
	_resolve_nodes()
	if toggle_button != null and not toggle_button.pressed.is_connected(toggle_wheel):
		toggle_button.pressed.connect(toggle_wheel)
	if symbol_library != null:
		build_rune_buttons()
	set_expanded(starts_expanded, false)


func initialize(library: SymbolLibraryData) -> void:
	symbol_library = library
	_resolve_nodes()
	build_rune_buttons()
	set_expanded(starts_expanded, false)


func build_rune_buttons() -> void:
	if rune_button_container == null:
		return
	if symbol_library == null or symbol_library.symbols.is_empty():
		return
	if rebuild_buttons_on_ready_only and not _buttons.is_empty():
		_refresh_button_states()
		return

	_clear_buttons()
	rune_button_container.custom_minimum_size = Vector2(
		(wheel_radius + rune_button_size.x) * 2.0,
		(wheel_radius + rune_button_size.y) * 2.0
	)

	for rune: SymbolCardData in symbol_library.symbols:
		if rune == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = rune_button_size
		button.size = rune_button_size
		button.text = _format_rune_text(rune)
		button.tooltip_text = "%s rune" % rune.spoken_word
		button.focus_mode = Control.FOCUS_NONE
		if rune.placeholder_icon != null:
			button.icon = rune.placeholder_icon
			button.expand_icon = true
		button.pressed.connect(_on_rune_button_pressed.bind(rune))
		rune_button_container.add_child(button)
		_buttons.append(button)

	_layout_buttons()
	_refresh_button_states()


func set_expanded(expanded: bool, animated: bool = true) -> void:
	_resolve_nodes()
	if rune_button_container == null:
		return

	_is_expanded = expanded
	if _tween != null:
		_tween.kill()
		_tween = null

	if expanded:
		rune_button_container.visible = true
		rune_button_container.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		rune_button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var target_alpha := 1.0 if expanded else 0.0
	var target_scale := Vector2.ONE if expanded else Vector2(0.86, 0.86)
	if animated and tween_seconds > 0.0:
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(rune_button_container, "modulate:a", target_alpha, tween_seconds)
		_tween.tween_property(rune_button_container, "scale", target_scale, tween_seconds)
		_tween.set_parallel(false)
		if not expanded:
			_tween.tween_callback(func() -> void:
				rune_button_container.visible = false
			)
	else:
		rune_button_container.modulate.a = target_alpha
		rune_button_container.scale = target_scale
		rune_button_container.visible = expanded

	if toggle_button != null:
		toggle_button.text = "Hide Runes" if expanded else "Show Runes"
	_refresh_button_states()

	if expanded:
		wheel_expanded.emit()
	else:
		wheel_retracted.emit()


func toggle_wheel() -> void:
	if _input_locked:
		return
	set_expanded(not _is_expanded)


func is_expanded() -> bool:
	return _is_expanded


func set_input_locked(is_locked: bool) -> void:
	_input_locked = is_locked
	_refresh_button_states()


func _resolve_nodes() -> void:
	if rune_button_container == null:
		rune_button_container = find_child("RunePalette", true, false) as Control
	if toggle_button == null:
		toggle_button = find_child("RuneWheelToggleButton", true, false) as Button


func _layout_buttons() -> void:
	if rune_button_container == null or _buttons.is_empty():
		return

	var center := rune_button_container.custom_minimum_size * 0.5
	var angle_step := TAU / float(_buttons.size())
	var direction := 1.0 if clockwise else -1.0
	var start_angle := deg_to_rad(start_angle_degrees)

	for index: int in range(_buttons.size()):
		var angle := start_angle + angle_step * float(index) * direction
		var offset := Vector2(cos(angle), sin(angle)) * wheel_radius
		var button := _buttons[index]
		button.position = center + offset - rune_button_size * 0.5
		button.size = rune_button_size


func _format_rune_text(rune: SymbolCardData) -> String:
	if rune.spoken_word.is_empty():
		return rune.symbol_id.to_upper()
	return rune.spoken_word


func _refresh_button_states() -> void:
	var disabled := _input_locked or not _is_expanded
	for button: Button in _buttons:
		button.disabled = disabled
	if toggle_button != null:
		toggle_button.disabled = _input_locked


func _on_rune_button_pressed(rune: SymbolCardData) -> void:
	if _input_locked or rune == null:
		return
	rune_selected.emit(rune)
	if auto_retract_after_rune_pick:
		set_expanded(false)


func _clear_buttons() -> void:
	for button: Button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()
