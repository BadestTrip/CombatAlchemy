## Synchronizes audio controls with the persistent Settings autoload.
extends Control


const SET_MUSIC_DB_METHOD: StringName = &"set_music_db"
const SET_SFX_DB_METHOD: StringName = &"set_sfx_db"


## Emitted after Back hides the settings panel.
signal close_requested


@onready var _music_slider: HSlider = (
	get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer/MusicSlider") as HSlider
)
@onready var _sfx_slider: HSlider = (
	get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer2/SFXSlider") as HSlider
)
@onready var _back_button: TextureButton = (
	get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer3/BackButton") as TextureButton
)
@onready var _settings: Node = get_node_or_null("/root/Settings")


func _ready() -> void:
	if not _validate_dependencies():
		return

	_music_slider.set_value_no_signal(
		clampf(db_to_linear(float(_settings.get("music_db"))), 0.0, 1.0)
	)
	_sfx_slider.set_value_no_signal(
		clampf(db_to_linear(float(_settings.get("sfx_db"))), 0.0, 1.0)
	)

	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_back_button.pressed.connect(_on_back_pressed)


func _on_music_changed(value: float) -> void:
	_settings.call(SET_MUSIC_DB_METHOD, linear_to_db(maxf(0.001, value)))


func _on_sfx_changed(value: float) -> void:
	_settings.call(SET_SFX_DB_METHOD, linear_to_db(maxf(0.001, value)))


func _on_back_pressed() -> void:
	visible = false
	close_requested.emit()


func _validate_dependencies() -> bool:
	var valid: bool = true
	valid = _require_node(_music_slider, "MusicSlider HSlider") and valid
	valid = _require_node(_sfx_slider, "SFXSlider HSlider") and valid
	valid = _require_node(_back_button, "BackButton TextureButton") and valid
	valid = _require_method(_settings, SET_MUSIC_DB_METHOD) and valid
	valid = _require_method(_settings, SET_SFX_DB_METHOD) and valid
	return valid


func _require_node(node: Node, description: String) -> bool:
	if node != null:
		return true
	push_error("SettingsMenu is missing %s." % description)
	return false


func _require_method(node: Node, method: StringName) -> bool:
	if node != null and node.has_method(method):
		return true
	push_error("SettingsMenu requires Settings.%s()." % method)
	return false
