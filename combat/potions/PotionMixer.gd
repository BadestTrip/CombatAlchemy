class_name PotionMixer
extends Node

# Responsibility: Collect unfinished potion layers and create runtime potion instances.

## Emitted after a layer is added or removed, with a copy of the current layers.
signal layers_changed(layers: Array[StringName])
## Emitted after a valid mixture creates a unique runtime potion.
signal potion_prepared(potion: PotionInstance)
## Emitted when mixing cannot produce a valid recipe, with preserved layers.
signal mix_rejected(layers: Array[StringName])
## Emitted after the active layer mixture is cleared.
signal mixture_cleared

## The maximum number of reagent layers the mixer can hold.
@export_range(1, 3, 1) var max_layers: int = 3:
	set(value):
		max_layers = clampi(value, 1, 3)
## The recipes that can be prepared by this mixer.
@export var recipe_book: PotionRecipeBookData

var _layers: Array[StringName] = []


## Adds reagent when it is valid and the mixer can accept another layer.
func add_reagent(reagent: StringName) -> bool:
	if not PotionReagent.is_valid(reagent) or _layers.size() >= max_layers:
		return false
	_layers.append(reagent)
	layers_changed.emit(get_layers())
	return true


## Removes and reports whether the most recently added layer was removed.
func remove_last() -> bool:
	if _layers.is_empty():
		return false
	_layers.pop_back()
	layers_changed.emit(get_layers())
	return true


## Clears all unfinished layers.
func clear() -> void:
	var had_layers := not _layers.is_empty()
	_layers.clear()
	if had_layers:
		layers_changed.emit(get_layers())
	mixture_cleared.emit()


## Attempts to prepare a recipe while preserving layers when no recipe matches.
func mix() -> bool:
	if recipe_book == null:
		mix_rejected.emit(get_layers())
		return false
	var creation_layers := get_layers()
	var recipe := recipe_book.find_match(creation_layers)
	if recipe == null:
		mix_rejected.emit(creation_layers)
		return false
	var potion := PotionInstance.create(recipe, creation_layers)
	if potion == null:
		mix_rejected.emit(creation_layers)
		return false
	_layers.clear()
	layers_changed.emit(get_layers())
	mixture_cleared.emit()
	potion_prepared.emit(potion)
	return true


## Returns a copy of the current reagent layers in insertion order.
func get_layers() -> Array[StringName]:
	var layers_copy: Array[StringName] = []
	layers_copy.append_array(_layers)
	return layers_copy
