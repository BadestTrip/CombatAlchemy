class_name PotionMixer
extends Node

## Owns ingredients/reservations and preparation; reaction owns timing.
signal layers_changed(layers: Array[StringName])
signal potion_prepared(potion: PotionInstance)
signal preparation_requested(potion: PotionInstance)
signal mix_rejected(layers: Array[StringName])
signal mixture_cleared
signal brewing_changed(state: BrewingReaction.State, height: float, power: float, blend: float)
signal check_completed(index: int, score: int)

@export_range(1, 3, 1) var max_layers: int = 3:
	set(value): max_layers = clampi(value, 1, 3)
@export var recipe_book: PotionRecipeBookData
@export var brewing_reaction_path: NodePath = ^"BrewingReaction"
@export var quality_profile: PotionQualityProfileData = preload("res://combat/potions/resources/PotionQualityProfile_Default.tres")

var _layers: Array[StringName] = []
var _active_recipe: PotionRecipeData
var _brewing_reaction: BrewingReaction
var _inventory: ReagentInventory
var _pending_potion: PotionInstance

func _ready() -> void:
	if quality_profile == null or not quality_profile.is_valid():
		push_error("PotionMixer requires a valid PotionQualityProfileData.")
	_brewing_reaction = get_node_or_null(brewing_reaction_path) as BrewingReaction
	if _brewing_reaction == null:
		push_error("PotionMixer requires BrewingReaction.")
		return
	_brewing_reaction.reaction_changed.connect(func(_h: float, _p: float, _b: float): _emit_brewing_changed())
	_brewing_reaction.check_completed.connect(func(index: int, score: int): check_completed.emit(index, score))
	_brewing_reaction.completed.connect(_on_reaction_completed)

func configure_inventory(inventory: ReagentInventory) -> void:
	if _inventory != inventory and not _layers.is_empty():
		clear()
	_inventory = inventory

func _exit_tree() -> void:
	_release_layer_reservations()
	_layers.clear()
	_pending_potion = null

func add_reagent(reagent: StringName) -> bool:
	if not _can_edit_layers() or _inventory == null or not PotionReagent.is_valid(reagent) or _layers.size() >= max_layers:
		return false
	if not _inventory.reserve(reagent):
		return false
	_layers.append(reagent)
	layers_changed.emit(get_layers())
	return true

func remove_last() -> bool:
	if not _can_edit_layers() or _layers.is_empty():
		return false
	var reagent: StringName = _layers.pop_back()
	_inventory.release(reagent)
	layers_changed.emit(get_layers())
	return true

func clear() -> void:
	var had_layers := not _layers.is_empty()
	_pending_potion = null
	_active_recipe = null
	_release_layer_reservations()
	_layers.clear()
	if _brewing_reaction != null:
		_brewing_reaction.cancel()
	if had_layers:
		layers_changed.emit(get_layers())
	mixture_cleared.emit()

func start_brewing() -> bool:
	if not _can_edit_layers() or recipe_book == null or quality_profile == null or not quality_profile.is_valid():
		return false
	_active_recipe = recipe_book.find_match(get_layers())
	if _active_recipe == null:
		mix_rejected.emit(get_layers())
		return false
	return _brewing_reaction.start()

## Manual pressure release, not a key-up event.
func release_brewing() -> void:
	if _brewing_reaction != null and _pending_potion == null:
		_brewing_reaction.release_pressure()

func set_heat_power(power: float) -> void:
	if _brewing_reaction != null:
		_brewing_reaction.set_heat_power(power)

func set_heat_enabled(enabled: bool) -> void:
	if _brewing_reaction != null:
		_brewing_reaction.set_heat_enabled(enabled)

func is_heat_enabled() -> bool:
	return _brewing_reaction != null and _brewing_reaction.is_heat_enabled()

func set_suspended(suspended: bool) -> void:
	if _brewing_reaction != null:
		_brewing_reaction.set_suspended(suspended)

func get_brewing_state() -> BrewingReaction.State:
	return _brewing_reaction.get_state() if _brewing_reaction != null else BrewingReaction.State.IDLE

func get_brewing_progress() -> float:
	return _brewing_reaction.get_progress() if _brewing_reaction != null else 0.0

func get_brewing_power() -> float:
	return _brewing_reaction.get_heat_power() if _brewing_reaction != null else 0.5

func get_blend_progress() -> float:
	return _brewing_reaction.get_blend_progress() if _brewing_reaction != null else 0.0

func get_brewing_profile() -> BrewingProfileData:
	return _brewing_reaction.profile if _brewing_reaction != null else null

func get_mixed_color() -> Color:
	return _active_recipe.mixed_color if _active_recipe != null else Color.WHITE

func get_layers() -> Array[StringName]:
	return _layers.duplicate()

func _on_reaction_completed(score: int) -> void:
	if _pending_potion != null or _active_recipe == null:
		return
	var potion := PotionInstance.create(_active_recipe, get_layers(), score, quality_profile.get_multiplier(score))
	if potion == null:
		mix_rejected.emit(get_layers())
		return
	_pending_potion = potion
	preparation_requested.emit(potion)

func acknowledge_preparation(potion: PotionInstance, committed: bool) -> bool:
	if potion == null or potion != _pending_potion:
		return false
	_pending_potion = null
	_active_recipe = null
	if not committed:
		_release_layer_reservations()
	_layers.clear()
	_brewing_reaction.cancel()
	layers_changed.emit(get_layers())
	mixture_cleared.emit()
	if committed:
		potion_prepared.emit(potion)
	return true

func _emit_brewing_changed() -> void:
	brewing_changed.emit(get_brewing_state(), get_brewing_progress(), get_brewing_power(), get_blend_progress())

func _can_edit_layers() -> bool:
	return _pending_potion == null and _brewing_reaction != null and _brewing_reaction.is_editable()

func _release_layer_reservations() -> void:
	if _inventory != null:
		for reagent in _layers:
			_inventory.release(reagent)
