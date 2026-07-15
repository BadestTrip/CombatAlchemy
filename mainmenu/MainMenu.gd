## Coordinates main-menu controls, visual styling, and scene transitions.
extends Control


const CLOSE_REQUESTED_SIGNAL: StringName = &"close_requested"
const START_NEW_GAME_METHOD: StringName = &"start_new_game"
const QUIT_GAME_METHOD: StringName = &"quit_game"
const SET_TRANSITION_DURATION_METHOD: StringName = &"set_transition_duration"
const IS_TRANSITION_BUSY_METHOD: StringName = &"is_busy"


## Duration forwarded to SceneTransition before starting a new game.
@export_range(0.1, 3.0, 0.05) var transition_duration: float = 2.0

## Visual settings applied to the background, alchemy seal, and shader layer.
@export var menu_style: MainMenuStyleData


@onready var _background: TextureRect = get_node_or_null("Background") as TextureRect
@onready var _shader_layer: ColorRect = get_node_or_null("Shader") as ColorRect
@onready var _alchemy_seal: AlchemySeal = get_node_or_null("AlchemySeal") as AlchemySeal
@onready var _menu_controls: CenterContainer = get_node_or_null("UI") as CenterContainer
@onready var _new_game_button: TextureButton = (
	get_node_or_null("UI/FlowContainer/HFlowContainer/NewGame") as TextureButton
)
@onready var _settings_button: TextureButton = (
	get_node_or_null("UI/FlowContainer/HFlowContainer/Options") as TextureButton
)
@onready var _quit_button: TextureButton = (
	get_node_or_null("UI/FlowContainer/HFlowContainer/Quit") as TextureButton
)
@onready var _settings_menu: Control = get_node_or_null("../SettingsMenu") as Control
@onready var _game_manager: Node = get_node_or_null("/root/GameManager")
@onready var _scene_transition: Node = get_node_or_null("/root/SceneTransition")


var _transition_started: bool = false


func _ready() -> void:
	if not _validate_dependencies():
		return

	_apply_menu_style()
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_menu.connect(
		CLOSE_REQUESTED_SIGNAL,
		Callable(self, "_on_settings_closed")
	)


func _on_new_game_pressed() -> void:
	if _transition_started or _is_scene_transition_busy():
		return

	_transition_started = true
	_set_menu_buttons_disabled(true)
	_scene_transition.call(SET_TRANSITION_DURATION_METHOD, transition_duration)
	_game_manager.call(START_NEW_GAME_METHOD)


func _on_settings_pressed() -> void:
	if _transition_started:
		return
	_menu_controls.visible = false
	_settings_menu.visible = true


func _on_quit_pressed() -> void:
	if _transition_started:
		return
	_game_manager.call(QUIT_GAME_METHOD)


func _on_settings_closed() -> void:
	_settings_menu.visible = false
	_menu_controls.visible = true
	_settings_button.grab_focus()


func _apply_menu_style() -> void:
	if menu_style == null:
		push_warning("MainMenu has no MainMenuStyleData; scene defaults remain active.")
		return

	if menu_style.background_texture != null:
		_background.texture = menu_style.background_texture

	_alchemy_seal.seal_opacity = menu_style.alchemy_seal_opacity
	_alchemy_seal.rotation_speed_degrees = menu_style.alchemy_seal_rotation_speed
	_shader_layer.visible = menu_style.shader_enabled

	var shader_material: ShaderMaterial = _shader_layer.material as ShaderMaterial
	if shader_material == null:
		push_error("MainMenu Shader must use a ShaderMaterial.")
		return

	shader_material.set_shader_parameter(
		"effect_strength",
		menu_style.shader_effect_strength
	)
	shader_material.set_shader_parameter(
		"vignette_strength",
		menu_style.vignette_strength
	)
	shader_material.set_shader_parameter("pulse_speed", menu_style.pulse_speed)


func _set_menu_buttons_disabled(disabled: bool) -> void:
	_new_game_button.disabled = disabled
	_settings_button.disabled = disabled
	_quit_button.disabled = disabled


func _is_scene_transition_busy() -> bool:
	return bool(_scene_transition.call(IS_TRANSITION_BUSY_METHOD))


func _validate_dependencies() -> bool:
	var valid: bool = true
	valid = _require_node(_background, "Background TextureRect") and valid
	valid = _require_node(_shader_layer, "Shader ColorRect") and valid
	valid = _require_node(_alchemy_seal, "AlchemySeal Control") and valid
	valid = _require_node(_menu_controls, "UI CenterContainer") and valid
	valid = _require_node(_new_game_button, "NewGame TextureButton") and valid
	valid = _require_node(_settings_button, "Options TextureButton") and valid
	valid = _require_node(_quit_button, "Quit TextureButton") and valid
	valid = _require_node(_settings_menu, "sibling SettingsMenu") and valid
	valid = _require_method(_game_manager, START_NEW_GAME_METHOD, "GameManager") and valid
	valid = _require_method(_game_manager, QUIT_GAME_METHOD, "GameManager") and valid
	valid = _require_method(
		_scene_transition,
		SET_TRANSITION_DURATION_METHOD,
		"SceneTransition"
	) and valid
	valid = _require_method(
		_scene_transition,
		IS_TRANSITION_BUSY_METHOD,
		"SceneTransition"
	) and valid

	if _settings_menu != null and not _settings_menu.has_signal(CLOSE_REQUESTED_SIGNAL):
		push_error("MainMenu requires SettingsMenu.close_requested.")
		valid = false

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
