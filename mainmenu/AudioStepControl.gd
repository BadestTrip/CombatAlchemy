@tool
class_name AudioStepControl
extends VBoxContainer

# Responsibility: Edit one integer audio level and render its ten discrete
# scene-authored segments. Decibel conversion belongs to the settings view.

signal step_changed(step: int)

const MIN_STEP: int = 0
const MAX_STEP: int = 10
const ACTIVE_COLOR: Color = Color("d8d8d8")
const INACTIVE_COLOR: Color = Color("404040")

## Label shown above the stepped control.
@export var label_text: String = "Audio":
	set(value):
		label_text = value
		_sync_label()
## Step used before persisted settings are synchronized.
@export_range(MIN_STEP, MAX_STEP, 1) var initial_step: int = 7

@onready var _label: Label = get_node_or_null("Label") as Label
@onready var _minus_button: Button = get_node_or_null("ControlRow/Minus") as Button
@onready var _segments: HBoxContainer = get_node_or_null("ControlRow/Segments") as HBoxContainer
@onready var _plus_button: Button = get_node_or_null("ControlRow/Plus") as Button

var _step: int = initial_step


func _ready() -> void:
	if not _validate_dependencies():
		return
	_sync_label()
	_minus_button.pressed.connect(_on_minus_pressed)
	_plus_button.pressed.connect(_on_plus_pressed)
	set_step(initial_step)


## Sets a clamped 0-10 step and optionally reports the resulting value.
func set_step(step: int, emit_change: bool = false) -> void:
	_step = clampi(step, MIN_STEP, MAX_STEP)
	_refresh_segments()
	if emit_change:
		step_changed.emit(_step)


## Returns the current clamped audio step.
func get_step() -> int:
	return _step


## Enables or disables both step buttons.
func set_interaction_enabled(enabled: bool) -> void:
	if _minus_button != null:
		_minus_button.disabled = not enabled
	if _plus_button != null:
		_plus_button.disabled = not enabled


## Focuses the decrement button used as the control's default target.
func focus_default() -> void:
	if _minus_button != null and not _minus_button.disabled:
		_minus_button.grab_focus()


func _on_minus_pressed() -> void:
	set_step(_step - 1, true)


func _on_plus_pressed() -> void:
	set_step(_step + 1, true)


func _sync_label() -> void:
	if _label != null:
		_label.text = label_text


func _refresh_segments() -> void:
	if _segments == null:
		return
	for index in _segments.get_child_count():
		var segment := _segments.get_child(index) as ColorRect
		if segment != null:
			segment.color = ACTIVE_COLOR if index < _step else INACTIVE_COLOR


func _validate_dependencies() -> bool:
	if _label == null or _minus_button == null or _segments == null or _plus_button == null:
		push_error("AudioStepControl requires Label, Minus, Segments, and Plus nodes.")
		return false
	if _segments.get_child_count() != MAX_STEP:
		push_error("AudioStepControl requires exactly ten segment nodes.")
		return false
	return true
