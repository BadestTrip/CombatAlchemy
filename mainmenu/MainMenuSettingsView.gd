class_name MainMenuSettingsView
extends VBoxContainer

# Responsibility: Adapt persisted Music/SFX decibels to the main menu's
# 0-10 stepped controls and report when the inline view should close.

signal close_requested

const MIN_VOLUME_DB: float = -80.0
const MAX_STEP: int = 10

@onready var _music_control: AudioStepControl = get_node_or_null("Music") as AudioStepControl
@onready var _sfx_control: AudioStepControl = get_node_or_null("SFX") as AudioStepControl
@onready var _back_command: MainMenuCommandButton = get_node_or_null("Back") as MainMenuCommandButton
@onready var _settings: Node = get_node_or_null("/root/Settings")


func _ready() -> void:
	if not _validate_dependencies():
		return
	_music_control.step_changed.connect(_on_music_step_changed)
	_sfx_control.step_changed.connect(_on_sfx_step_changed)
	_back_command.activated.connect(_request_close)
	_sync_from_settings()


## Shows the inline settings view and focuses its first audio control.
func open() -> void:
	_sync_from_settings()
	visible = true
	set_interaction_enabled(true)
	focus_default.call_deferred()


## Hides the inline settings view without unloading the menu backdrop.
func close() -> void:
	visible = false


## Focuses the first actionable settings control.
func focus_default() -> void:
	if _music_control != null:
		_music_control.focus_default()


## Enables or disables every interactive control in the view.
func set_interaction_enabled(enabled: bool) -> void:
	if _music_control != null:
		_music_control.set_interaction_enabled(enabled)
	if _sfx_control != null:
		_sfx_control.set_interaction_enabled(enabled)
	if _back_command != null:
		_back_command.set_interaction_enabled(enabled)


## Converts a UI step to the persisted decibel value.
static func step_to_db(step: int) -> float:
	var clamped_step := clampi(step, 0, MAX_STEP)
	if clamped_step == 0:
		return MIN_VOLUME_DB
	return linear_to_db(float(clamped_step) / float(MAX_STEP))


## Converts a persisted decibel value to the nearest UI step.
static func db_to_step(value_db: float) -> int:
	if value_db <= MIN_VOLUME_DB:
		return 0
	return clampi(roundi(db_to_linear(value_db) * float(MAX_STEP)), 1, MAX_STEP)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	_request_close()
	get_viewport().set_input_as_handled()


func _on_music_step_changed(step: int) -> void:
	if _settings != null and _settings.has_method(&"set_music_db"):
		_settings.call(&"set_music_db", step_to_db(step))


func _on_sfx_step_changed(step: int) -> void:
	if _settings != null and _settings.has_method(&"set_sfx_db"):
		_settings.call(&"set_sfx_db", step_to_db(step))


func _request_close() -> void:
	close_requested.emit()


func _sync_from_settings() -> void:
	if _settings == null:
		return
	_music_control.set_step(db_to_step(float(_settings.get("music_db"))))
	_sfx_control.set_step(db_to_step(float(_settings.get("sfx_db"))))


func _validate_dependencies() -> bool:
	if _music_control == null or _sfx_control == null or _back_command == null:
		push_error("MainMenuSettingsView requires Music, SFX, and Back components.")
		return false
	if _settings == null:
		push_error("MainMenuSettingsView requires the Settings autoload.")
		return false
	return true
