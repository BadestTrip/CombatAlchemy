extends Control

# Responsibility: Switch between the main command list and inline settings,
# preserve focus, and forward New Game/Quit to existing global services.

const START_NEW_GAME_METHOD: StringName = &"start_new_game"
const QUIT_GAME_METHOD: StringName = &"quit_game"
const SET_TRANSITION_DURATION_METHOD: StringName = &"set_transition_duration"
const IS_TRANSITION_BUSY_METHOD: StringName = &"is_busy"

## Duration forwarded to SceneTransition before starting a new game.
@export_range(0.1, 3.0, 0.05) var transition_duration: float = 2.0

@onready var _main_commands: VBoxContainer = get_node_or_null("CommandPanel/MainCommands") as VBoxContainer
@onready var _settings_view: MainMenuSettingsView = get_node_or_null("CommandPanel/SettingsView") as MainMenuSettingsView
@onready var _new_game_command: MainMenuCommandButton = get_node_or_null("CommandPanel/MainCommands/NewGame") as MainMenuCommandButton
@onready var _settings_command: MainMenuCommandButton = get_node_or_null("CommandPanel/MainCommands/Settings") as MainMenuCommandButton
@onready var _quit_command: MainMenuCommandButton = get_node_or_null("CommandPanel/MainCommands/Quit") as MainMenuCommandButton
@onready var _game_manager: Node = get_node_or_null("/root/GameManager")
@onready var _scene_transition: Node = get_node_or_null("/root/SceneTransition")

var _transition_started: bool = false


func _ready() -> void:
	if not _validate_dependencies():
		return
	_new_game_command.activated.connect(_on_new_game_pressed)
	_settings_command.activated.connect(_on_settings_pressed)
	_quit_command.activated.connect(_on_quit_pressed)
	_settings_view.close_requested.connect(_on_settings_closed)
	_show_main_commands(false)
	_new_game_command.grab_button_focus.call_deferred()


## Enables or disables every main-menu and settings interaction.
func set_interaction_enabled(enabled: bool) -> void:
	_new_game_command.set_interaction_enabled(enabled)
	_settings_command.set_interaction_enabled(enabled)
	_quit_command.set_interaction_enabled(enabled)
	_settings_view.set_interaction_enabled(enabled)


func _on_new_game_pressed() -> void:
	if _transition_started or _is_scene_transition_busy():
		return
	_transition_started = true
	set_interaction_enabled(false)
	_scene_transition.call(SET_TRANSITION_DURATION_METHOD, transition_duration)
	_game_manager.call(START_NEW_GAME_METHOD)


func _on_settings_pressed() -> void:
	if _transition_started:
		return
	_main_commands.visible = false
	_settings_view.open()


func _on_quit_pressed() -> void:
	if _transition_started:
		return
	_game_manager.call(QUIT_GAME_METHOD)


func _on_settings_closed() -> void:
	_show_main_commands(true)


func _show_main_commands(restore_settings_focus: bool) -> void:
	_settings_view.close()
	_main_commands.visible = true
	if restore_settings_focus:
		_settings_command.grab_button_focus.call_deferred()


func _is_scene_transition_busy() -> bool:
	return bool(_scene_transition.call(IS_TRANSITION_BUSY_METHOD))


func _validate_dependencies() -> bool:
	var valid := true
	valid = _require_node(_main_commands, "MainCommands") and valid
	valid = _require_node(_settings_view, "SettingsView") and valid
	valid = _require_node(_new_game_command, "NewGame command") and valid
	valid = _require_node(_settings_command, "Settings command") and valid
	valid = _require_node(_quit_command, "Quit command") and valid
	valid = _require_method(_game_manager, START_NEW_GAME_METHOD, "GameManager") and valid
	valid = _require_method(_game_manager, QUIT_GAME_METHOD, "GameManager") and valid
	valid = _require_method(_scene_transition, SET_TRANSITION_DURATION_METHOD, "SceneTransition") and valid
	valid = _require_method(_scene_transition, IS_TRANSITION_BUSY_METHOD, "SceneTransition") and valid
	return valid


func _require_node(node: Node, description: String) -> bool:
	if node != null:
		return true
	push_error("MainMenu is missing %s." % description)
	return false


func _require_method(node: Node, method: StringName, owner_name: String) -> bool:
	if node != null and node.has_method(method):
		return true
	push_error("MainMenu requires %s.%s()." % [owner_name, method])
	return false
