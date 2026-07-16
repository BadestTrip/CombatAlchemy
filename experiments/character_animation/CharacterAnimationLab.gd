extends Control

## Thin controller for the isolated animation lab.
## It creates no rig or UI nodes; it only forwards authored controls to the rig API.

@onready var _rig: Node = %HumanoidCutoutRig
@onready var _idle_button: Button = %IdleButton
@onready var _walk_button: Button = %WalkButton
@onready var _drink_button: Button = %DrinkButton
@onready var _throw_button: Button = %ThrowButton
@onready var _hit_button: Button = %HitButton
@onready var _speed_slider: HSlider = %SpeedSlider
@onready var _speed_value: Label = %SpeedValue
@onready var _mirror_toggle: CheckButton = %MirrorToggle
@onready var _bones_toggle: CheckButton = %BonesToggle
@onready var _reset_button: Button = %ResetButton
@onready var _current_state_value: Label = %CurrentStateValue
@onready var _last_event_value: Label = %LastEventValue


func _ready() -> void:
	if not _validate_dependencies():
		return

	_idle_button.pressed.connect(_request_state.bind(&"idle"))
	_walk_button.pressed.connect(_request_state.bind(&"walk"))
	_drink_button.pressed.connect(_request_state.bind(&"drink"))
	_throw_button.pressed.connect(_request_state.bind(&"throw"))
	_hit_button.pressed.connect(_request_state.bind(&"hit"))
	_speed_slider.value_changed.connect(_on_speed_changed)
	_mirror_toggle.toggled.connect(_on_mirror_toggled)
	_bones_toggle.toggled.connect(_on_bones_toggled)
	_reset_button.pressed.connect(_on_reset_pressed)
	_rig.connect(&"state_changed", _on_rig_state_changed)
	_rig.connect(&"animation_event", _on_rig_animation_event)

	_rig.call(&"set_playback_speed", _speed_slider.value)
	_rig.call(&"set_mirrored", _mirror_toggle.button_pressed)
	_rig.call(&"set_debug_bones_visible", _bones_toggle.button_pressed)
	_update_speed_label(_speed_slider.value)
	_on_rig_state_changed(_rig.call(&"get_current_state") as StringName)


func _request_state(state: StringName) -> void:
	if not (_rig.call(&"play_state", state) as bool):
		push_warning("CharacterAnimationLab rejected unknown state '%s'." % state)


func _on_speed_changed(value: float) -> void:
	_rig.call(&"set_playback_speed", value)
	_update_speed_label(value)


func _on_mirror_toggled(is_enabled: bool) -> void:
	_rig.call(&"set_mirrored", is_enabled)


func _on_bones_toggled(is_enabled: bool) -> void:
	_rig.call(&"set_debug_bones_visible", is_enabled)


func _on_reset_pressed() -> void:
	_rig.call(&"reset_to_idle")
	_last_event_value.text = "None"


func _on_rig_state_changed(state: StringName) -> void:
	_current_state_value.text = state if not state.is_empty() else &"None"


func _on_rig_animation_event(event_name: StringName) -> void:
	_last_event_value.text = event_name


func _update_speed_label(value: float) -> void:
	_speed_value.text = "%.2fx" % value


func _validate_dependencies() -> bool:
	var required_nodes: Array[Node] = [
		_rig,
		_idle_button,
		_walk_button,
		_drink_button,
		_throw_button,
		_hit_button,
		_speed_slider,
		_speed_value,
		_mirror_toggle,
		_bones_toggle,
		_reset_button,
		_current_state_value,
		_last_event_value,
	]
	for required_node in required_nodes:
		if required_node == null:
			push_error("CharacterAnimationLab is missing a required authored node.")
			return false
	return true
