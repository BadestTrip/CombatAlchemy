extends Control

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
	restart_btn.visible = false
	restart_btn.disabled = true
	resume_btn.pressed.connect(_on_resume)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	menu_btn.pressed.connect(_on_menu)
	if settings_menu.has_signal("close_requested"):
		settings_menu.connect("close_requested", _on_settings_closed)


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
	resume_btn.grab_focus()


func _on_resume() -> void:
	visible = false
	settings_menu.visible = false
	get_tree().paused = false


func _on_menu() -> void:
	get_tree().paused = false
	visible = false
	GameManager.go_to_main_menu()


func _on_quit() -> void:
	get_tree().paused = false
	GameManager.quit_game()


func _on_settings() -> void:
	pause_buttons.visible = false
	settings_menu.visible = true


func _on_settings_closed() -> void:
	settings_menu.visible = false
	pause_buttons.visible = true
	settings_btn.grab_focus()
