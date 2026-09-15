@tool
class_name MainMenuCommandButton
extends Control

# Responsibility: Present one reusable text command with keyboard focus,
# hover feedback, and a two-pixel pressed displacement.

signal activated

## Text displayed by the command button.
@export var command_text: String = "Command":
	set(value):
		command_text = value
		_sync_text()

@onready var _focus_rule: ColorRect = get_node_or_null("FocusRule") as ColorRect
@onready var _button: Button = get_node_or_null("Button") as Button


func _ready() -> void:
	if not _validate_dependencies():
		return
	_sync_text()
	_button.pressed.connect(_on_pressed)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.focus_entered.connect(_refresh_focus_rule)
	_button.focus_exited.connect(_refresh_focus_rule)
	_button.mouse_entered.connect(_refresh_focus_rule)
	_button.mouse_exited.connect(_refresh_focus_rule)
	_refresh_focus_rule()


## Enables or disables this command without changing its visibility.
func set_interaction_enabled(enabled: bool) -> void:
	if _button == null:
		return
	_button.disabled = not enabled
	if not enabled:
		_button.position.y = 0.0
	_refresh_focus_rule()


## Gives keyboard focus to the underlying Button.
func grab_button_focus() -> void:
	if _button != null and not _button.disabled:
		_button.grab_focus()


## Returns the native Button for navigation and automated checks.
func get_button() -> Button:
	return _button


func _sync_text() -> void:
	if _button != null:
		_button.text = command_text


func _on_pressed() -> void:
	activated.emit()


func _on_button_down() -> void:
	_button.position.y = 2.0


func _on_button_up() -> void:
	_button.position.y = 0.0


func _refresh_focus_rule() -> void:
	if _focus_rule == null or _button == null:
		return
	_focus_rule.visible = (
		not _button.disabled
		and (_button.has_focus() or _button.is_hovered())
	)


func _validate_dependencies() -> bool:
	if _focus_rule == null:
		push_error("MainMenuCommandButton requires FocusRule.")
		return false
	if _button == null:
		push_error("MainMenuCommandButton requires Button.")
		return false
	return true
