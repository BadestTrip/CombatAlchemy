extends Control
class_name SecondaryPanelController


signal panel_state_changed(panel_id: String, is_open: bool)


@export_group("Buttons")
@export var combat_log_button: Button
@export var cast_history_button: Button
@export var discovered_chants_button: Button

@export_group("Panels")
@export var combat_log_panel: Control
@export var cast_history_panel: Control
@export var discovered_chants_panel: Control

@export_group("Behavior")
@export var close_other_panels_when_opening: bool = true
@export var panels_start_closed: bool = true
@export var block_combat_input_when_panel_open: bool = false


func _ready() -> void:
	set_process(false)
	_resolve_nodes()
	_connect_buttons()
	if panels_start_closed:
		close_all_panels()


func configure(
	start_closed: bool,
	one_open_at_a_time: bool,
	block_input: bool
) -> void:
	panels_start_closed = start_closed
	close_other_panels_when_opening = one_open_at_a_time
	block_combat_input_when_panel_open = block_input
	_resolve_nodes()
	_connect_buttons()
	if panels_start_closed:
		close_all_panels()


func toggle_panel(panel_id: String) -> void:
	var panel := _panel_for_id(panel_id)
	if panel == null:
		return
	if panel.visible:
		panel.visible = false
		_update_button_states()
		panel_state_changed.emit(panel_id, false)
		return
	open_panel(panel_id)


func open_panel(panel_id: String) -> void:
	var panel := _panel_for_id(panel_id)
	if panel == null:
		return
	if close_other_panels_when_opening:
		close_all_panels()
	panel.visible = true
	_update_button_states()
	panel_state_changed.emit(panel_id, true)


func close_all_panels() -> void:
	for panel: Control in [combat_log_panel, cast_history_panel, discovered_chants_panel]:
		if panel != null:
			panel.visible = false
	_update_button_states()
	panel_state_changed.emit("", false)


func is_any_panel_open() -> bool:
	for panel: Control in [combat_log_panel, cast_history_panel, discovered_chants_panel]:
		if panel != null and panel.visible:
			return true
	return false


func _resolve_nodes() -> void:
	if combat_log_button == null:
		combat_log_button = _find_scene_node("CombatLogButton") as Button
	if cast_history_button == null:
		cast_history_button = _find_scene_node("CastHistoryButton") as Button
	if discovered_chants_button == null:
		discovered_chants_button = _find_scene_node("SpellbookButton") as Button
	if combat_log_panel == null:
		combat_log_panel = _find_scene_node("LogPanel") as Control
	if cast_history_panel == null:
		cast_history_panel = _find_scene_node("CastHistoryPanel") as Control
	if discovered_chants_panel == null:
		discovered_chants_panel = _find_scene_node("SpellbookPanel") as Control


func _connect_buttons() -> void:
	if combat_log_button != null and not combat_log_button.pressed.is_connected(_on_log_pressed):
		combat_log_button.toggle_mode = true
		combat_log_button.pressed.connect(_on_log_pressed)
	if cast_history_button != null and not cast_history_button.pressed.is_connected(_on_history_pressed):
		cast_history_button.toggle_mode = true
		cast_history_button.pressed.connect(_on_history_pressed)
	if discovered_chants_button != null and not discovered_chants_button.pressed.is_connected(_on_chants_pressed):
		discovered_chants_button.toggle_mode = true
		discovered_chants_button.pressed.connect(_on_chants_pressed)

	var history_close := _find_scene_node("CastHistoryCloseButton") as Button
	if history_close != null and not history_close.pressed.is_connected(_on_history_pressed):
		history_close.pressed.connect(_on_history_pressed)
	var chants_close := _find_scene_node("SpellbookCloseButton") as Button
	if chants_close != null and not chants_close.pressed.is_connected(_on_chants_pressed):
		chants_close.pressed.connect(_on_chants_pressed)


func _on_log_pressed() -> void:
	toggle_panel("log")


func _on_history_pressed() -> void:
	toggle_panel("history")


func _on_chants_pressed() -> void:
	toggle_panel("chants")


func _panel_for_id(panel_id: String) -> Control:
	match panel_id:
		"log":
			return combat_log_panel
		"history":
			return cast_history_panel
		"chants":
			return discovered_chants_panel
		_:
			return null


func _update_button_states() -> void:
	if combat_log_button != null:
		combat_log_button.button_pressed = combat_log_panel != null and combat_log_panel.visible
	if cast_history_button != null:
		cast_history_button.button_pressed = cast_history_panel != null and cast_history_panel.visible
	if discovered_chants_button != null:
		discovered_chants_button.button_pressed = discovered_chants_panel != null and discovered_chants_panel.visible


func _find_scene_node(node_name: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		scene = owner
	if scene == null:
		return null
	return scene.find_child(node_name, true, false)
