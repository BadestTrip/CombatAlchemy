# PauseMenu.gd
# Shared pause menu for combat and overworld scenes. It reuses the existing
# Settings.tscn audio controls and owns the paused state.
extends Control

@export_enum("combat", "overworld") var pause_context: String = "combat"
@export var combat_ui_path: NodePath

@onready var combat_ui: CombatUIController = _resolve_combat_ui()
@onready var pause_buttons: Control = $CenterContainer
@onready var resume_btn: Button = $CenterContainer/VBoxContainer/Resume
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/Restart
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/Settings
@onready var menu_btn: Button = $CenterContainer/VBoxContainer/MainMenu
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/Quit
@onready var settings_menu: Control = $SettingsMenu

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	visible = false
	settings_menu.visible = false
	_configure_for_context()
	resume_btn.pressed.connect(_on_resume)
	restart_btn.pressed.connect(_on_restart)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	menu_btn.pressed.connect(_on_menu)
	if settings_menu.has_signal("close_requested"):
		# SettingsMenu is intentionally typed as Control because this scene
		# reuses the existing packed settings UI without a new global class.
		settings_menu.connect("close_requested", _on_settings_closed)

# ui_cancel is Godot's built-in Escape action.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	if visible:
		if settings_menu.visible:
			_on_settings_closed()
		else:
			_on_resume()
	else:
		_open()

func _open() -> void:
	visible = true
	pause_buttons.visible = true
	settings_menu.visible = false
	get_tree().paused = true
	_set_combat_pause_state(true)
	resume_btn.grab_focus()

func _on_resume() -> void:
	visible = false
	settings_menu.visible = false
	get_tree().paused = false
	_set_combat_pause_state(false)

func _on_restart() -> void:
	get_tree().paused = false
	visible = false
	_set_combat_pause_state(false)
	if pause_context == "combat":
		GameManager.restart_combat()
	else:
		GameManager.start_new_game()

func _on_menu() -> void:
	get_tree().paused = false
	visible = false
	_set_combat_pause_state(false)
	GameManager.go_to_main_menu()

func _on_quit() -> void:
	get_tree().paused = false
	_set_combat_pause_state(false)
	GameManager.quit_game()


# Existing Settings.tscn contains Music and SFX sliders backed by Settings.gd.
func _on_settings() -> void:
	pause_buttons.visible = false
	settings_menu.visible = true


func _on_settings_closed() -> void:
	settings_menu.visible = false
	pause_buttons.visible = true
	settings_btn.grab_focus()


func _configure_for_context() -> void:
	restart_btn.visible = pause_context == "combat"
	restart_btn.disabled = pause_context != "combat"


func _set_combat_pause_state(is_open: bool) -> void:
	if combat_ui != null:
		combat_ui.set_pause_menu_open(is_open)


func _resolve_combat_ui() -> CombatUIController:
	if String(combat_ui_path).is_empty():
		return null
	return get_node_or_null(combat_ui_path) as CombatUIController
