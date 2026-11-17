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
@onready var _count_labels: Array[Label] = [$RedCount, $GreenCount, $BlueCount]

var _inventory: ReagentInventory
var _buttons_editable := true


func _ready() -> void:
	reset_view()

func configure_inventory(inventory: ReagentInventory) -> void:
	if _inventory != null and _inventory.availability_changed.is_connected(_on_availability_changed):
		_inventory.availability_changed.disconnect(_on_availability_changed)
	_inventory = inventory
	if _inventory != null:
		_inventory.availability_changed.connect(_on_availability_changed)
	_refresh_inventory()


## Opens or hides this bottom-center mixer control.
func set_open(is_open: bool) -> void:
	visible = is_open


## Shows the supplied reagent layers and enables further selection.
func show_mixing(layers: Array[StringName]) -> void:
	_flask_view.set_layers(layers)
	_set_reagent_buttons_visible(true)
	_set_reagent_buttons_enabled(true)


## Displays reaction progress and disables reagent edits while liquid is active.
func show_brewing(
	layers: Array[StringName],
	state: BrewingReaction.State,
	progress: float,
	energy: float,
	predicted_settled_progress: float,
	profile: BrewingProfileData = null
) -> void:
	_flask_view.show_brewing(
		layers,
		state,
		progress,
		energy,
		predicted_settled_progress,
		profile
	)
	_set_reagent_buttons_visible(true)
	_set_reagent_buttons_enabled(state == BrewingReaction.State.IDLE)


## Shows a completed potion color and hides reagent selection.
func show_ready(color: Color) -> void:
	_flask_view.show_mixed(color)
	_set_reagent_buttons_visible(false)


## Shows the mix failure animation while retaining reagent selection.
func show_mix_failure() -> void:
	_flask_view.show_failure()
	_set_reagent_buttons_visible(true)
	_set_reagent_buttons_enabled(true)


## Restores the empty mixer state with reagent selection enabled.
func reset_view() -> void:
	_flask_view.reset_view()
	_set_reagent_buttons_visible(true)
	_set_reagent_buttons_enabled(true)


## Reports whether every reagent control is currently editable.
func are_reagent_buttons_enabled() -> bool:
	for button in _reagent_buttons:
		if button.disabled:
			return false
	return true


func _set_reagent_buttons_visible(should_show: bool) -> void:
	for button in _reagent_buttons:
		button.visible = should_show


func _set_reagent_buttons_enabled(should_enable: bool) -> void:
	_buttons_editable = should_enable
	_refresh_inventory()

func _on_availability_changed(_reagent: StringName, _available: int) -> void:
	_refresh_inventory()

func _refresh_inventory() -> void:
	var reagents: Array[StringName] = [PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE]
	for index in _reagent_buttons.size():
		var count := _inventory.get_available_count(reagents[index]) if _inventory != null else 0
		_count_labels[index].text = _format_count(count)
		_count_labels[index].tooltip_text = "%d available" % count
		_reagent_buttons[index].tooltip_text = "%d available" % count
		_reagent_buttons[index].disabled = not _buttons_editable or count <= 0

func _format_count(count: int) -> String:
	if count < 1000:
		return str(count)
	return "%.1fK" % (float(count) / 1000.0)


func _on_red_button_pressed() -> void:
	reagent_selected.emit(PotionReagent.RED)


func _on_green_button_pressed() -> void:
	reagent_selected.emit(PotionReagent.GREEN)


func _on_blue_button_pressed() -> void:
	reagent_selected.emit(PotionReagent.BLUE)
