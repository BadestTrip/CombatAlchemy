extends Control

@onready var resume_btn:  TextureButton = $CenterContainer/VBoxContainer/Resume
@onready var restart_btn: TextureButton = $CenterContainer/VBoxContainer/Restart
@onready var menu_btn: TextureButton = $CenterContainer/VBoxContainer/Menu
@onready var quit_btn:    TextureButton = $CenterContainer/VBoxContainer/Quit
var _prev_camera: Camera2D = null

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(_on_resume)
	restart_btn.pressed.connect(_on_restart)
	quit_btn.pressed.connect(_on_quit)
	menu_btn.pressed.connect(_on_menu)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()

func _toggle() -> void:
	if visible: _on_resume()
	else: _open()

func _open() -> void:
	_prev_camera = get_viewport().get_camera_2d()
	GameManager.make_player_camera_current()
	await get_tree().create_timer(0.4).timeout
	await get_tree().process_frame
	visible = true
	get_tree().paused = true
	resume_btn.grab_focus()

func _on_resume() -> void:
	visible = false
	get_tree().paused = false
	call_deferred("_restore_prev_camera")

func _restore_prev_camera() -> void:
	if _prev_camera and is_instance_valid(_prev_camera):
		_prev_camera.make_current()
	_prev_camera = null

func _on_restart() -> void:
	get_tree().paused = false
	await GameManager.restart_level()
	visible = false

func _on_menu() -> void:
	get_tree().paused = false
	GameManager.return_to_main_menu()
	visible = false

func _on_quit() -> void:
	get_tree().quit()
