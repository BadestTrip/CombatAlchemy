class_name PotionInput
extends Node

## Converts physical input into intents; no recipe, inventory or reaction rules.
signal mixer_toggle_requested
signal reagent_requested(reagent: StringName)
signal mix_pressed
signal heat_adjust_requested(direction: int)
signal focus_changed(focused: bool)
signal potion_use_requested(delivery_method: StringName)
signal remove_reagent_requested
signal clear_mixture_requested

@export var presentation_profile: BrewingPresentationProfileData = preload("res://combat/potions/brewing/BrewingPresentationProfile_Default.tres")
var _decrease_held := false
var _increase_held := false
var _repeat_remaining := 0.0
var _focused := true
var _mix_held := false

func _ready() -> void:
	if presentation_profile == null or not presentation_profile.is_valid():
		push_error("PotionInput requires a valid BrewingPresentationProfileData.")
		set_process(false)
		set_process_unhandled_input(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		clear_held_controls()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		clear_held_controls()
		focus_changed.emit(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		clear_held_controls()
		focus_changed.emit(true)

func clear_held_controls() -> void:
	_mix_held = false
	_decrease_held = false
	_increase_held = false
	_repeat_remaining = presentation_profile.repeat_delay if presentation_profile != null else 0.3

func _process(delta: float) -> void:
	if not _focused or get_tree().paused or _decrease_held == _increase_held:
		return
	_repeat_remaining -= delta
	while _repeat_remaining <= 0.0:
		heat_adjust_requested.emit(1 if _increase_held else -1)
		_repeat_remaining += presentation_profile.repeat_interval

func _unhandled_input(event: InputEvent) -> void:
	if not _focused or get_tree().paused or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed(&"ui_cancel"):
		clear_held_controls()
		return
	if event.is_action(&"decrease_brewing_heat") or event.is_action(&"increase_brewing_heat"):
		if event.is_action(&"decrease_brewing_heat"):
			_decrease_held = event.is_pressed()
		else:
			_increase_held = event.is_pressed()
		_repeat_remaining = presentation_profile.repeat_delay
		if event.is_pressed() and _decrease_held != _increase_held:
			heat_adjust_requested.emit(1 if _increase_held else -1)
	elif event.is_action(&"mix_potion"):
		if event.is_pressed() and not _mix_held:
			_mix_held = true
			mix_pressed.emit()
		elif not event.is_pressed():
			_mix_held = false
	elif event.is_action_pressed(&"toggle_mixer"):
		clear_held_controls()
		mixer_toggle_requested.emit()
	elif event.is_action_pressed(&"add_red_reagent"):
		reagent_requested.emit(PotionReagent.RED)
	elif event.is_action_pressed(&"add_green_reagent"):
		reagent_requested.emit(PotionReagent.GREEN)
	elif event.is_action_pressed(&"add_blue_reagent"):
		reagent_requested.emit(PotionReagent.BLUE)
	elif event.is_action_pressed(&"drink_potion"):
		potion_use_requested.emit(PotionDelivery.DRINK)
	elif event.is_action_pressed(&"throw_potion"):
		potion_use_requested.emit(PotionDelivery.THROW)
	elif event.is_action_pressed(&"place_potion"):
		potion_use_requested.emit(PotionDelivery.PLACE)
	elif event.is_action_pressed(&"remove_reagent"):
		remove_reagent_requested.emit()
	elif event.is_action_pressed(&"clear_mixture"):
		clear_held_controls()
		clear_mixture_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()
