class_name PotionMixer
extends Node

# Responsibility: Match reagent layers, coordinate one reaction, and create completed potion instances.

## Emitted after a layer is added or removed, with a copy of the current layers.
signal layers_changed(layers: Array[StringName])
## Emitted after a valid mixture creates a unique runtime potion.
signal potion_prepared(potion: PotionInstance)
## Emitted when mixing cannot produce a valid recipe, with preserved layers.
signal mix_rejected(layers: Array[StringName])
## Emitted after the active layer mixture is cleared.
signal mixture_cleared
## Emitted whenever the reaction changes so presentation can reflect it.
signal brewing_changed(
	state: BrewingReaction.State,
	progress: float,
	energy: float,
	predicted_settled_progress: float
)
## Emitted when excessive reaction progress enters cooldown.
signal brewing_overreacted
## Emitted when cooldown restores the configured partial progress.
signal brewing_recovered

## The maximum number of reagent layers the mixer can hold.
@export_range(1, 3, 1) var max_layers: int = 3:
	set(value):
		max_layers = clampi(value, 1, 3)
## The recipes that can be prepared by this mixer.
@export var recipe_book: PotionRecipeBookData
## Scene-authored reaction component used by this mixer.
@export var brewing_reaction_path: NodePath = ^"BrewingReaction"

var _layers: Array[StringName] = []
var _active_recipe: PotionRecipeData
var _brewing_reaction: BrewingReaction


func _ready() -> void:
	_brewing_reaction = get_node_or_null(brewing_reaction_path) as BrewingReaction
	if _brewing_reaction == null:
		push_error("PotionMixer requires a BrewingReaction at brewing_reaction_path.")
		return
	_brewing_reaction.reaction_changed.connect(_on_reaction_changed)
	_brewing_reaction.overreacted.connect(_on_reaction_overreacted)
	_brewing_reaction.recovered.connect(_on_reaction_recovered)
	_brewing_reaction.completed.connect(_on_reaction_completed)
	_emit_brewing_changed()


## Adds reagent when it is valid and the mixer can accept another layer.
func add_reagent(reagent: StringName) -> bool:
	if (
		not _can_edit_layers()
		or not PotionReagent.is_valid(reagent)
		or _layers.size() >= max_layers
	):
		return false
	_reset_reaction_for_edit()
	_layers.append(reagent)
	layers_changed.emit(get_layers())
	return true


## Removes and reports whether the most recently added layer was removed.
func remove_last() -> bool:
	if not _can_edit_layers() or _layers.is_empty():
		return false
	_reset_reaction_for_edit()
	_layers.pop_back()
	layers_changed.emit(get_layers())
	return true


## Clears all unfinished layers.
func clear() -> void:
	var had_layers := not _layers.is_empty()
	_active_recipe = null
	if _brewing_reaction != null:
		_brewing_reaction.cancel()
	_layers.clear()
	if had_layers:
		layers_changed.emit(get_layers())
	mixture_cleared.emit()


## Starts or resumes agitation when the current layers match a valid recipe.
func start_brewing() -> bool:
	if recipe_book == null or _brewing_reaction == null:
		mix_rejected.emit(get_layers())
		return false
	if _brewing_reaction.get_state() == BrewingReaction.State.COOLDOWN:
		return false
	var matched_recipe := recipe_book.find_match(get_layers())
	if matched_recipe == null:
		mix_rejected.emit(get_layers())
		return false
	_active_recipe = matched_recipe
	return _brewing_reaction.start_agitation()


## Releases agitation while preserving residual energy and progress.
func release_brewing() -> void:
	if _brewing_reaction != null:
		_brewing_reaction.release_agitation()


func get_brewing_state() -> BrewingReaction.State:
	return (
		_brewing_reaction.get_state()
		if _brewing_reaction != null
		else BrewingReaction.State.IDLE
	)


func get_brewing_progress() -> float:
	return _brewing_reaction.get_progress() if _brewing_reaction != null else 0.0


func get_brewing_energy() -> float:
	return _brewing_reaction.get_energy() if _brewing_reaction != null else 0.0


func get_predicted_settled_progress() -> float:
	return (
		_brewing_reaction.get_predicted_settled_progress()
		if _brewing_reaction != null
		else 0.0
	)


func get_brewing_profile() -> BrewingProfileData:
	return _brewing_reaction.profile if _brewing_reaction != null else null


## Returns a copy of the current reagent layers in insertion order.
func get_layers() -> Array[StringName]:
	var layers_copy: Array[StringName] = []
	layers_copy.append_array(_layers)
	return layers_copy


func _on_reaction_completed() -> void:
	var creation_layers := get_layers()
	var potion := PotionInstance.create(_active_recipe, creation_layers)
	if potion == null:
		mix_rejected.emit(creation_layers)
		return
	_active_recipe = null
	_brewing_reaction.cancel()
	_layers.clear()
	layers_changed.emit(get_layers())
	mixture_cleared.emit()
	potion_prepared.emit(potion)


func _on_reaction_changed(
	_progress: float,
	_energy: float,
	_predicted_settled_progress: float
) -> void:
	_emit_brewing_changed()


func _on_reaction_overreacted() -> void:
	brewing_overreacted.emit()


func _on_reaction_recovered() -> void:
	brewing_recovered.emit()


func _emit_brewing_changed() -> void:
	if _brewing_reaction == null:
		return
	brewing_changed.emit(
		_brewing_reaction.get_state(),
		_brewing_reaction.get_progress(),
		_brewing_reaction.get_energy(),
		_brewing_reaction.get_predicted_settled_progress()
	)


func _can_edit_layers() -> bool:
	return _brewing_reaction == null or _brewing_reaction.is_editable()


func _reset_reaction_for_edit() -> void:
	_active_recipe = null
	if _brewing_reaction != null and _brewing_reaction.get_progress() > 0.0:
		_brewing_reaction.cancel()
