extends Control

@onready var play_btn: TextureButton = $UI/FlowContainer/HFlowContainer/NewGame
@onready var settings_btn: TextureButton = $UI/FlowContainer/HFlowContainer/Options
@onready var quit_btn: TextureButton = $UI/FlowContainer/HFlowContainer/Quit
@onready var settings_menu: Control = $"../SettingsMenu"
@onready var UI: CenterContainer = $UI

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	
func _on_play() -> void:
	play_btn.disabled = true
	settings_btn.disabled = true
	quit_btn.disabled = true
	GameManager.start_new_game()
	queue_free()

func _on_settings() -> void:
	UI.visible = false
	settings_menu.visible = true

func _on_main_menu() -> void:
	GameManager.go_to_main_menu()

func _on_quit() -> void:
	GameManager.quit_game()
