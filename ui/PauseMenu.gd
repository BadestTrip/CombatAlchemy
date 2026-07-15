## Owns pause-state input and navigation while the scene tree is paused.
extends Control


const CLOSE_REQUESTED_SIGNAL: StringName = &"close_requested"
const GO_TO_MAIN_MENU_METHOD: StringName = &"go_to_main_menu"
const QUIT_GAME_METHOD: StringName = &"quit_game"


@onready var _pause_controls: CenterContainer = (
	get_node_or_null("CenterContainer") as CenterContainer
)
@onready var _resume_button: Button = (
	get_node_or_null("CenterContainer/VBoxContainer/Resume") as Button
)
@onready var _settings_button: Button = (
	get_node_or_null("CenterContainer/VBoxContainer/Settings") as Button
)
@onready var _main_menu_button: Button = (
	get_node_or_null("CenterContainer/VBoxContainer/MainMenu") as Button
)
@onready var _quit_button: Button = (
	get_node_or_null("CenterContainer/VBoxContainer/Quit") as Button
)
@onready var _settings_menu: Control = get_node_or_null("SettingsMenu") as Control
@onready var _game_manager: Node = get_node_or_null("/root/GameManager")


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	visible = false
	if not _validate_dependencies():
		set_process_unhandled_input(false)
		return

	_settings_menu.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_menu.connect(
		CLOSE_REQUESTED_SIGNAL,
		Callable(self, "_on_settings_closed")
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()


func _toggle_pause_menu() -> void:
	if not visible:
		_open_pause_menu()
	elif _settings_menu.visible:
		_on_settings_closed()
	else:
		_on_resume_pressed()


func _open_pause_menu() -> void:
	visible = true
	_pause_controls.visible = true
	_settings_menu.visible = false
	get_tree().paused = true
	_resume_button.grab_focus()


func _on_resume_pressed() -> void:
	visible = false
	_settings_menu.visible = false
	get_tree().paused = false


func _on_settings_pressed() -> void:
	_pause_controls.visible = false
	_settings_menu.visible = true


func _on_settings_closed() -> void:
	_settings_menu.visible = false
	_pause_controls.visible = true
	_settings_button.grab_focus()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	_game_manager.call(GO_TO_MAIN_MENU_METHOD)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	_game_manager.call(QUIT_GAME_METHOD)


func _validate_dependencies() -> bool:
	var valid: bool = true
	valid = _require_node(_pause_controls, "CenterContainer") and valid
	valid = _require_node(_resume_button, "Resume button") and valid
	valid = _require_node(_settings_button, "Settings button") and valid
	valid = _require_node(_main_menu_button, "MainMenu button") and valid
	valid = _require_node(_quit_button, "Quit button") and valid
	valid = _require_node(_settings_menu, "SettingsMenu") and valid
	valid = _require_method(_game_manager, GO_TO_MAIN_MENU_METHOD) and valid
	valid = _require_method(_game_manager, QUIT_GAME_METHOD) and valid

	if _settings_menu != null and not _settings_menu.has_signal(CLOSE_REQUESTED_SIGNAL):
		push_error("PauseMenu requires SettingsMenu.close_requested.")
		valid = false

	return valid


func _require_node(node: Node, description: String) -> bool:
	if node != null:
		return true
	push_error("PauseMenu is missing %s." % description)
	return false


func _require_method(node: Node, method: StringName) -> bool:
	if node != null and node.has_method(method):
		return true
	push_error("PauseMenu requires GameManager.%s()." % method)
	return false
