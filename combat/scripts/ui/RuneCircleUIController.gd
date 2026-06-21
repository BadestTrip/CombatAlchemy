extends Control
class_name RuneCircleUIController


@export_group("Node References")
@export var round_manager: RoundManager
@export var rune_wheel_controller: RuneWheelController
@export var slot_buttons: Array[Button] = []
@export var cast_button: Button
@export var clear_button: Button
@export var chant_preview_label: Label

@export_group("Visual Text")
@export var empty_slot_text: String = "---"
@export var selected_slot_prefix: String = "> "
@export var filled_slot_prefix: String = ""

@export_group("Behavior")
@export var auto_expand_wheel_on_empty_slot_click: bool = true


var _input_locked: bool = true
var _local_controls_connected: bool = false


func _ready() -> void:
	set_process(false)
	_resolve_nodes()
	_connect_local_controls()


func initialize(round_manager_ref: RoundManager, symbol_library: SymbolLibraryData) -> void:
	round_manager = round_manager_ref
	_resolve_nodes()
	_connect_local_controls()
	_connect_round_manager_signals()
	if rune_wheel_controller != null:
		rune_wheel_controller.initialize(symbol_library)
	refresh_all()


func refresh_all() -> void:
	refresh_slots()
	refresh_cast_button()


func refresh_slots() -> void:
	if round_manager == null:
		return

	var preview_words: PackedStringArray = []
	for index: int in range(slot_buttons.size()):
		var button := slot_buttons[index]
		if button == null:
			continue
		var rune: SymbolCardData = null
		if index < round_manager.selected_runes.size():
			rune = round_manager.selected_runes[index]

		var lines: PackedStringArray = []
		var prefix := selected_slot_prefix if index == round_manager.selected_slot_index else filled_slot_prefix
		lines.append("%sSlot %d" % [prefix, index + 1])
		if rune == null:
			lines.append(empty_slot_text)
			preview_words.append("...")
		else:
			if not rune.visual_hint.is_empty():
				lines.append(rune.visual_hint)
			lines.append(rune.spoken_word)
			preview_words.append(rune.spoken_word)

		button.text = "\n".join(lines)
		button.disabled = _input_locked or not _is_planning()

	if chant_preview_label != null:
		chant_preview_label.text = "Selected Chant:\n" + "  >  ".join(preview_words)


func refresh_cast_button() -> void:
	if round_manager == null:
		return

	var selected_count := 0
	for rune: SymbolCardData in round_manager.selected_runes:
		if rune != null:
			selected_count += 1

	if cast_button != null:
		cast_button.disabled = _input_locked or not round_manager.can_cast()
	if clear_button != null:
		clear_button.disabled = _input_locked or not _is_planning() or selected_count == 0
	if rune_wheel_controller != null:
		rune_wheel_controller.set_input_locked(_input_locked or not _is_planning())


func set_input_locked(is_locked: bool) -> void:
	_input_locked = is_locked
	refresh_all()


func _resolve_nodes() -> void:
	if slot_buttons.is_empty():
		for slot_name: String in ["ChantSlot1", "ChantSlot2", "ChantSlot3"]:
			var slot_button := _find_scene_node(slot_name) as Button
			if slot_button != null:
				slot_buttons.append(slot_button)
	if cast_button == null:
		cast_button = _find_scene_node("CastButton") as Button
	if clear_button == null:
		clear_button = _find_scene_node("ClearButton") as Button
	if chant_preview_label == null:
		chant_preview_label = _find_scene_node("ChantPreview") as Label
	if rune_wheel_controller == null:
		var wheel_node := _find_scene_node("RuneWheelRoot")
		if wheel_node == null:
			wheel_node = _find_scene_node("HandsPanel")
		rune_wheel_controller = wheel_node as RuneWheelController


func _connect_local_controls() -> void:
	if _local_controls_connected:
		return
	for index: int in range(slot_buttons.size()):
		var button := slot_buttons[index]
		if button != null:
			button.pressed.connect(_on_slot_pressed.bind(index))
	if cast_button != null:
		cast_button.pressed.connect(_on_cast_pressed)
	if clear_button != null:
		clear_button.pressed.connect(_on_clear_pressed)
	if rune_wheel_controller != null and not rune_wheel_controller.rune_selected.is_connected(_on_rune_selected):
		rune_wheel_controller.rune_selected.connect(_on_rune_selected)
	_local_controls_connected = true


func _connect_round_manager_signals() -> void:
	if round_manager == null:
		return
	if not round_manager.selected_slot_changed.is_connected(_on_selected_slot_changed):
		round_manager.selected_slot_changed.connect(_on_selected_slot_changed)
	if not round_manager.selected_runes_changed.is_connected(_on_selected_runes_changed):
		round_manager.selected_runes_changed.connect(_on_selected_runes_changed)
	if not round_manager.cast_availability_changed.is_connected(_on_cast_availability_changed):
		round_manager.cast_availability_changed.connect(_on_cast_availability_changed)
	if not round_manager.casting_started.is_connected(_on_casting_started):
		round_manager.casting_started.connect(_on_casting_started)
	if not round_manager.casting_finished.is_connected(_on_casting_finished):
		round_manager.casting_finished.connect(_on_casting_finished)


func _on_slot_pressed(slot_index: int) -> void:
	if _input_locked or round_manager == null:
		return
	round_manager.select_slot(slot_index)
	if (
		auto_expand_wheel_on_empty_slot_click
		and rune_wheel_controller != null
		and slot_index >= 0
		and slot_index < round_manager.selected_runes.size()
		and round_manager.selected_runes[slot_index] == null
	):
		rune_wheel_controller.set_expanded(true)


func _on_rune_selected(rune: SymbolCardData) -> void:
	if _input_locked or round_manager == null:
		return
	round_manager.place_rune_in_selected_slot(rune)


func _on_cast_pressed() -> void:
	if _input_locked or round_manager == null:
		return
	round_manager.cast_chant()


func _on_clear_pressed() -> void:
	if _input_locked or round_manager == null:
		return
	round_manager.clear_chant()


func _on_selected_slot_changed(_slot_index: int) -> void:
	refresh_slots()
	refresh_cast_button()


func _on_selected_runes_changed(_selected_runes: Array) -> void:
	refresh_all()


func _on_cast_availability_changed(_can_cast: bool) -> void:
	refresh_cast_button()


func _on_casting_started() -> void:
	set_input_locked(true)


func _on_casting_finished() -> void:
	set_input_locked(false)


func _is_planning() -> bool:
	return round_manager != null and round_manager.current_state == RoundManager.RoundState.PLANNING


func _find_scene_node(node_name: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		scene = owner
	if scene == null:
		return null
	return scene.find_child(node_name, true, false)
