# MainMenu.gd
# Purpose:
#   Own the main menu button behavior and connect scene-changing buttons to the
#   existing ink-wash transition flow.
#
# Node assumptions:
#   - This script is attached to mainmenu/MainMenu.tscn's root Control.
#   - The UI buttons keep their current paths under UI/FlowContainer.
#   - StartMenu.tscn still instantiates SettingsMenu as a sibling node.
#   - SceneTransition is the existing autoload defined in project.godot.
#
# Inspector tuning notes:
#   - transition_duration controls how long the ink reveal takes after pressing
#     New Game. A value between 0.6 and 1.0 seconds keeps it quick.
#   - menu_style owns high-level menu visuals so the scene is less hardcoded.
extends Control


# Duration forwarded into globals/InkwashTransition.gd before scene changes.
@export_range(0.1, 3.0, 0.05) var transition_duration: float = 2
@export var menu_style: MainMenuStyleData


@onready var background: TextureRect = $Background
@onready var shader_layer: ColorRect = $Shader
@onready var rune_circle: RuneCircle = $RuneCircle as RuneCircle
@onready var continue_btn: TextureButton = $UI/FlowContainer/HFlowContainer/Continue
@onready var play_btn: TextureButton = $UI/FlowContainer/HFlowContainer/NewGame
@onready var settings_btn: TextureButton = $UI/FlowContainer/HFlowContainer/Options
@onready var quit_btn: TextureButton = $UI/FlowContainer/HFlowContainer/Quit
@onready var settings_menu: Control = $"../SettingsMenu"
@onready var UI: CenterContainer = $UI


# This local lock prevents repeated clicks while GameManager starts a transition.
var _transition_started: bool = false


# Godot calls this when the main menu enters the scene.
func _ready() -> void:
	_apply_menu_style()
	play_btn.pressed.connect(_on_play)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	if settings_menu.has_signal("close_requested"):
		settings_menu.connect("close_requested", _on_settings_closed)


# New Game uses GameManager so existing scene loading and autoload state stay intact.
func _on_play() -> void:
	if _transition_started or _is_scene_transition_busy():
		return

	_transition_started = true
	_set_menu_buttons_disabled(true)
	_apply_transition_duration()
	GameManager.start_new_game()


# Settings is not a scene change, so it keeps the current sibling settings flow.
func _on_settings() -> void:
	if _transition_started:
		return
	UI.visible = false
	settings_menu.visible = true


# Kept for compatibility with any older signal wiring.
func _on_main_menu() -> void:
	GameManager.go_to_main_menu()


# Quit remains immediate and does not need the ink transition.
func _on_quit() -> void:
	if _transition_started:
		return
	GameManager.quit_game()


func _on_settings_closed() -> void:
	settings_menu.visible = false
	UI.visible = true
	settings_btn.grab_focus()


func _apply_menu_style() -> void:
	if menu_style == null:
		return
	if background != null and menu_style.background_texture != null:
		background.texture = menu_style.background_texture
	if rune_circle != null:
		rune_circle.rune_opacity = menu_style.rune_circle_opacity
		rune_circle.rotation_speed_degrees = menu_style.rune_circle_rotation_speed
	if shader_layer != null:
		shader_layer.visible = menu_style.shader_enabled
		var shader_material := shader_layer.material as ShaderMaterial
		if shader_material != null:
			shader_material.set_shader_parameter(
				"effect_strength",
				menu_style.shader_effect_strength
			)
			shader_material.set_shader_parameter(
				"vignette_strength",
				menu_style.vignette_strength
			)
			shader_material.set_shader_parameter("pulse_speed", menu_style.pulse_speed)


# Disable every main-menu button that could be clicked during a transition.
func _set_menu_buttons_disabled(disabled: bool) -> void:
	continue_btn.disabled = disabled
	play_btn.disabled = disabled
	settings_btn.disabled = disabled
	quit_btn.disabled = disabled


# Forward the exported duration into the existing SceneTransition autoload.
func _apply_transition_duration() -> void:
	var transition_node := get_node_or_null(GameManager.SCENE_TRANSITION_NODE_PATH)
	if transition_node == null:
		return
	if transition_node.has_method("set_transition_duration"):
		transition_node.call("set_transition_duration", transition_duration)


# Ask the autoload whether it is already busy before accepting another click.
func _is_scene_transition_busy() -> bool:
	var transition_node := get_node_or_null(GameManager.SCENE_TRANSITION_NODE_PATH)
	if transition_node == null or not transition_node.has_method("is_busy"):
		return false
	return bool(transition_node.call("is_busy"))
