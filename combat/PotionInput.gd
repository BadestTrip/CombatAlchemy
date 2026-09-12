class_name PotionInput
extends Node

# Responsibility: Translate named Input Map actions into potion-combat requests.

## Emitted when the mixer visibility should toggle.
signal mixer_toggle_requested
## Emitted when a configured reagent should be added to the mixture.
signal reagent_requested(reagent: StringName)
## Emitted once when the mix action begins being held.
signal agitation_started
## Emitted once when held agitation is released or forcibly interrupted.
signal agitation_released
## Emitted when the held potion should use one delivery method.
signal potion_use_requested(delivery_method: StringName)
## Emitted when the newest reagent layer should be removed.
signal remove_reagent_requested
## Emitted when the active mixture or prepared potion should be cleared.
signal clear_mixture_requested

var _agitation_held := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_agitation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_release_agitation()
		return
	if event.is_action(&"mix_potion"):
		if event.is_pressed():
			_start_agitation()
		else:
			_release_agitation()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_mixer"):
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
		clear_mixture_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _start_agitation() -> void:
	if _agitation_held:
		return
	_agitation_held = true
	agitation_started.emit()


func _release_agitation() -> void:
	if not _agitation_held:
		return
	_agitation_held = false
	agitation_released.emit()
