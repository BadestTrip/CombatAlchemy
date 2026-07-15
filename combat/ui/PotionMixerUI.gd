class_name PotionMixerUI
extends Control

# Responsibility: Present reagent selection controls and reflect potion mixing states.

## Emitted when the player selects one of the three reagent buttons.
signal reagent_selected(reagent: StringName)

@onready var _flask_view: FlaskView = $FlaskView
@onready var _reagent_buttons: Array[Button] = [
	$ReagentButtons/RedButton,
	$ReagentButtons/GreenButton,
	$ReagentButtons/BlueButton,
]


func _ready() -> void:
	reset_view()


## Opens or hides this bottom-center mixer control.
func set_open(is_open: bool) -> void:
	visible = is_open


## Shows the supplied reagent layers and enables further selection.
func show_mixing(layers: Array[StringName]) -> void:
	_flask_view.set_layers(layers)
	_set_reagent_buttons_visible(true)


## Shows a completed potion color and hides reagent selection.
func show_ready(color: Color) -> void:
	_flask_view.show_mixed(color)
	_set_reagent_buttons_visible(false)


## Shows the mix failure animation while retaining reagent selection.
func show_mix_failure() -> void:
	_flask_view.show_failure()
	_set_reagent_buttons_visible(true)


## Restores the empty mixer state with reagent selection enabled.
func reset_view() -> void:
	_flask_view.reset_view()
	_set_reagent_buttons_visible(true)


func _set_reagent_buttons_visible(should_show: bool) -> void:
	for button in _reagent_buttons:
		button.visible = should_show


func _on_red_button_pressed() -> void:
	reagent_selected.emit(PotionReagent.RED)


func _on_green_button_pressed() -> void:
	reagent_selected.emit(PotionReagent.GREEN)


func _on_blue_button_pressed() -> void:
	reagent_selected.emit(PotionReagent.BLUE)
