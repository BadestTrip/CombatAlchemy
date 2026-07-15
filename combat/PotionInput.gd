class_name PotionInput
extends Node

# Responsibility: Translate named Input Map actions into potion-combat requests.

## Emitted when the mixer visibility should toggle.
signal mixer_toggle_requested
## Emitted when a configured reagent should be added to the mixture.
signal reagent_requested(reagent: StringName)
## Emitted when the current mixture should be prepared.
signal mix_requested
## Emitted when the prepared potion should be consumed by the player.
signal drink_requested
## Emitted when the prepared potion should be thrown.
signal throw_requested
## Emitted when the newest reagent layer should be removed.
signal remove_reagent_requested
## Emitted when the active mixture or prepared potion should be cleared.
signal clear_mixture_requested


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(&"toggle_mixer"):
		mixer_toggle_requested.emit()
	elif event.is_action_pressed(&"add_red_reagent"):
		reagent_requested.emit(PotionReagent.RED)
	elif event.is_action_pressed(&"add_green_reagent"):
		reagent_requested.emit(PotionReagent.GREEN)
	elif event.is_action_pressed(&"add_blue_reagent"):
		reagent_requested.emit(PotionReagent.BLUE)
	elif event.is_action_pressed(&"mix_potion"):
		mix_requested.emit()
	elif event.is_action_pressed(&"drink_potion"):
		drink_requested.emit()
	elif event.is_action_pressed(&"throw_potion"):
		throw_requested.emit()
	elif event.is_action_pressed(&"remove_reagent"):
		remove_reagent_requested.emit()
	elif event.is_action_pressed(&"clear_mixture"):
		clear_mixture_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()
