extends Control
class_name RuneWheelController


signal rune_selected(rune_data: SymbolCardData)
signal wheel_expanded
signal wheel_retracted


@export_group("Node References")
@export var rune_button_container: Control
@export var toggle_button: Button


var _buttons: Array[Button] = []
var _is_expanded: bool = true
var _input_locked: bool = false
var symbol_library: SymbolLibraryData
var balance: CombatBalanceData
var wheel_radius: float = 220.0
var rune_button_size: Vector2 = Vector2(145.0, 72.0)
var start_angle_degrees: float = -90.0
var clockwise: bool = true
var starts_expanded: bool = true
var auto_retract_after_rune_pick: bool = false
var tween_seconds: float = 0.2


func _ready() -> void:
	set_process(false)
	_resolve_nodes()
	if toggle_button != null and not toggle_button.pressed.is_connected(toggle_wheel):
		toggle_button.pressed.connect(toggle_wheel)
	if symbol_library != null:
		build_rune_buttons()
	set_expanded(starts_expanded, false)


func initialize(
	library: SymbolLibraryData,
	balance_ref: CombatBalanceData = null
) -> void:
	symbol_library = library
	balance = balance_ref
	_apply_balance_settings()
	_resolve_nodes()
	build_rune_buttons()
	set_expanded(starts_expanded, false)


func build_rune_buttons() -> void:
	if rune_button_container == null:
		return
	if symbol_library == null or symbol_library.symbols.is_empty():
		return
	if not _buttons.is_empty():
		_update_existing_buttons()
		layout_rune_buttons()
		_refresh_button_states()
		return

	_apply_balance_settings()
	rune_button_container.custom_minimum_size = _container_size()
	for rune: SymbolCardData in symbol_library.symbols:
		if rune == null:
			continue
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_rune_button_pressed.bind(rune))
		rune_button_container.add_child(button)
		_buttons.append(button)
		_apply_rune_button_data(button, rune)

	layout_rune_buttons()
	_refresh_button_states()


func layout_rune_buttons() -> void:
	if rune_button_container == null or _buttons.is_empty():
		return

	_apply_balance_settings()
	rune_button_container.custom_minimum_size = _container_size()
	var center := rune_button_container.custom_minimum_size * 0.5
	var angle_step := TAU / float(_buttons.size())
	var direction := 1.0 if clockwise else -1.0
	var start_angle := deg_to_rad(start_angle_degrees)

	for index: int in range(_buttons.size()):
		var button := _buttons[index]
		button.custom_minimum_size = rune_button_size
		button.size = rune_button_size
		var angle := start_angle + angle_step * float(index) * direction
		var offset := Vector2(cos(angle), sin(angle)) * wheel_radius
		button.position = center + offset - rune_button_size * 0.5


func set_expanded(expanded: bool, animated: bool = true) -> void:
	_resolve_nodes()
	if rune_button_container == null:
		return

	_is_expanded = expanded
	rune_button_container.visible = expanded
	rune_button_container.modulate.a = 1.0
	rune_button_container.scale = Vector2.ONE
	rune_button_container.mouse_filter = (
		Control.MOUSE_FILTER_STOP if expanded else Control.MOUSE_FILTER_IGNORE
	)

	if animated and tween_seconds > 0.0:
		var tween := create_tween()
		var start_scale := Vector2(0.92, 0.92) if expanded else Vector2.ONE
		var end_scale := Vector2.ONE if expanded else Vector2(0.92, 0.92)
		rune_button_container.scale = start_scale
		rune_button_container.visible = true
		tween.tween_property(rune_button_container, "scale", end_scale, tween_seconds)
		if not expanded:
			tween.parallel().tween_property(
				rune_button_container,
				"modulate:a",
				0.0,
				tween_seconds
			)
			tween.tween_callback(func() -> void:
				rune_button_container.visible = false
				rune_button_container.modulate.a = 1.0
				rune_button_container.scale = Vector2.ONE
			)

	if toggle_button != null:
		toggle_button.text = "Hide Runes" if expanded else "Runes"
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


func _apply_balance_settings() -> void:
	if balance == null:
		return
	wheel_radius = maxf(1.0, balance.rune_wheel_radius)
	start_angle_degrees = balance.rune_wheel_start_angle_degrees
	clockwise = balance.rune_wheel_clockwise
	starts_expanded = balance.rune_wheel_starts_expanded
	auto_retract_after_rune_pick = balance.auto_retract_wheel_after_rune_pick
	tween_seconds = maxf(0.0, balance.rune_wheel_tween_seconds)
	rune_button_size = Vector2(_button_width(), _button_height())


func _update_existing_buttons() -> void:
	_apply_balance_settings()
	for index: int in range(mini(_buttons.size(), symbol_library.symbols.size())):
		var rune: SymbolCardData = symbol_library.symbols[index]
		if rune != null:
			_apply_rune_button_data(_buttons[index], rune)


func _apply_rune_button_data(button: Button, rune: SymbolCardData) -> void:
	button.custom_minimum_size = rune_button_size
	button.size = rune_button_size
	#button.text = _format_rune_text(rune)
	button.tooltip_text = _format_rune_tooltip(rune)
	button.icon = rune.placeholder_icon
	button.expand_icon = rune.placeholder_icon != null


#func _format_rune_text(rune: SymbolCardData) -> String:
	#var lines: PackedStringArray = []
	#if _show_visual_hints() and not rune.visual_hint.is_empty():
		#lines.append(rune.visual_hint)
	#lines.append(rune.spoken_word if not rune.spoken_word.is_empty() else rune.symbol_id.to_upper())
	#if _show_display_names() and not rune.display_name.is_empty():
		#lines.append(rune.display_name)
	#return "\n".join(lines)


func _format_rune_tooltip(rune: SymbolCardData) -> String:
	var lines: PackedStringArray = []
	lines.append(rune.spoken_word if not rune.spoken_word.is_empty() else rune.symbol_id.to_upper())
	if not rune.display_name.is_empty():
		lines.append(rune.display_name)
	if not rune.visual_hint.is_empty():
		lines.append("Hint: %s" % rune.visual_hint)
	return "\n".join(lines)


func _button_width() -> float:
	if balance == null:
		return maxf(1.0, rune_button_size.x)
	return maxf(1.0, balance.rune_button_width)


func _button_height() -> float:
	if balance == null:
		return maxf(1.0, rune_button_size.y)
	return maxf(1.0, balance.rune_button_height)


func _show_display_names() -> bool:
	return balance == null or balance.show_card_display_names


func _show_visual_hints() -> bool:
	return balance == null or balance.show_card_visual_hints


func _container_size() -> Vector2:
	return Vector2(
		(wheel_radius + rune_button_size.x) * 2.0,
		(wheel_radius + rune_button_size.y) * 2.0
	)


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
