class_name PotionCombatController
extends Node2D

# Responsibility: Coordinate potion input, mixing, player consumption, and projectile spawning.

## Path to the PotionInput node that emits mapped combat actions.
@export var potion_input_path: NodePath
## Path to the PotionMixer node that stores layers and prepared recipes.
@export var potion_mixer_path: NodePath
## Path to the PotionMixerUI control that reflects mixer state to the player.
@export var potion_mixer_ui_path: NodePath
## Path to the player movement controller that provides the current aiming direction.
@export var player_combat_controller_path: NodePath
## Path to the player's PotionTarget so self-thrown projectiles can ignore it and drinking can apply effects.
@export var player_potion_target_path: NodePath
## Path to the Node2D that should own spawned potion projectiles.
@export var projectiles_parent_path: NodePath
## Projectile scene instantiated when the player throws a prepared potion.
@export var projectile_scene: PackedScene = preload("res://combat/potions/PotionProjectile.tscn")

var _potion_input: PotionInput
var _potion_mixer: PotionMixer
var _potion_mixer_ui: PotionMixerUI
var _player_combat_controller: PlayerCombatController
var _player_potion_target: PotionTarget
var _projectiles_parent: Node2D
var _mixer_open := false


func _ready() -> void:
	_potion_input = get_node_or_null(potion_input_path) as PotionInput
	_potion_mixer = get_node_or_null(potion_mixer_path) as PotionMixer
	_potion_mixer_ui = get_node_or_null(potion_mixer_ui_path) as PotionMixerUI
	_player_combat_controller = get_node_or_null(player_combat_controller_path) as PlayerCombatController
	_player_potion_target = get_node_or_null(player_potion_target_path) as PotionTarget
	_projectiles_parent = get_node_or_null(projectiles_parent_path) as Node2D
	if not _has_valid_dependencies():
		_disable_controller()
		return

	_connect_signals()
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(false)


func _has_valid_dependencies() -> bool:
	var missing_dependencies: Array[String] = []
	if _potion_input == null:
		missing_dependencies.append("PotionInput")
	if _potion_mixer == null:
		missing_dependencies.append("PotionMixer")
	if _potion_mixer_ui == null:
		missing_dependencies.append("PotionMixerUI")
	if _player_combat_controller == null:
		missing_dependencies.append("PlayerCombatController")
	if _player_potion_target == null:
		missing_dependencies.append("player PotionTarget")
	if _projectiles_parent == null:
		missing_dependencies.append("projectiles parent")
	if projectile_scene == null:
		missing_dependencies.append("projectile scene")
	if missing_dependencies.is_empty():
		return true
	push_error("PotionCombatController requires: %s." % ", ".join(missing_dependencies))
	return false


func _disable_controller() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	if _potion_input != null:
		_potion_input.set_process_input(false)
		_potion_input.set_process_unhandled_input(false)


func _connect_signals() -> void:
	_potion_input.mixer_toggle_requested.connect(_on_mixer_toggle_requested)
	_potion_input.reagent_requested.connect(_on_reagent_requested)
	_potion_input.mix_requested.connect(_on_mix_requested)
	_potion_input.drink_requested.connect(_on_drink_requested)
	_potion_input.throw_requested.connect(_on_throw_requested)
	_potion_input.remove_reagent_requested.connect(_on_remove_reagent_requested)
	_potion_input.clear_mixture_requested.connect(_on_clear_mixture_requested)
	_potion_mixer_ui.reagent_selected.connect(_on_reagent_requested)
	_potion_mixer.layers_changed.connect(_on_layers_changed)
	_potion_mixer.potion_prepared.connect(_on_potion_prepared)
	_potion_mixer.mix_rejected.connect(_on_mix_rejected)
	_potion_mixer.mixture_cleared.connect(_on_mixture_cleared)


func _on_mixer_toggle_requested() -> void:
	if _potion_mixer.has_prepared_potion():
		return
	_mixer_open = not _mixer_open
	_potion_mixer_ui.set_open(_mixer_open)
	if _mixer_open:
		_potion_mixer_ui.show_mixing(_potion_mixer.get_layers())


func _on_reagent_requested(reagent: StringName) -> void:
	if not _mixer_open or _potion_mixer.has_prepared_potion():
		return
	_potion_mixer.add_reagent(reagent)


func _on_mix_requested() -> void:
	if not _mixer_open or _potion_mixer.has_prepared_potion():
		return
	_potion_mixer.mix()


func _on_drink_requested() -> void:
	if not _potion_mixer.has_prepared_potion():
		return
	var recipe := _potion_mixer.take_prepared_recipe()
	if recipe == null:
		return
	_close_mixer_after_use()
	if not _player_potion_target.receive_potion(recipe):
		push_warning("Player rejected the prepared drink recipe.")


func _on_throw_requested() -> void:
	if not _potion_mixer.has_prepared_potion() or projectile_scene == null:
		return
	if not is_instance_valid(_projectiles_parent) or not is_instance_valid(_player_combat_controller):
		return
	var projectile := projectile_scene.instantiate() as PotionProjectile
	if projectile == null:
		push_warning("Prepared throw could not instantiate PotionProjectile.")
		return
	var origin := _player_combat_controller.get_throw_origin()
	var direction := _player_combat_controller.get_throw_direction()
	var recipe := _potion_mixer.take_prepared_recipe()
	if recipe == null:
		projectile.free()
		return
	_close_mixer_after_use()
	_projectiles_parent.add_child(projectile)
	if not projectile.launch(recipe, origin, direction, _player_potion_target):
		push_warning("Prepared throw could not launch PotionProjectile.")


func _on_remove_reagent_requested() -> void:
	if not _mixer_open or _potion_mixer.has_prepared_potion():
		return
	_potion_mixer.remove_last()


func _on_clear_mixture_requested() -> void:
	var should_open_mixer := _mixer_open or _potion_mixer.has_prepared_potion()
	_potion_mixer.clear()
	_mixer_open = should_open_mixer
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(_mixer_open)


func _on_layers_changed(layers: Array[StringName]) -> void:
	if _mixer_open and not _potion_mixer.has_prepared_potion():
		_potion_mixer_ui.show_mixing(layers)


func _on_potion_prepared(recipe: PotionRecipeData) -> void:
	_mixer_open = true
	_potion_mixer_ui.set_open(true)
	_potion_mixer_ui.show_ready(recipe.mixed_color)


func _on_mix_rejected(_layers: Array[StringName]) -> void:
	if _mixer_open and not _potion_mixer.has_prepared_potion():
		_potion_mixer_ui.show_mix_failure()


func _on_mixture_cleared() -> void:
	if _mixer_open and not _potion_mixer.has_prepared_potion():
		_potion_mixer_ui.reset_view()


func _close_mixer_after_use() -> void:
	_mixer_open = false
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(false)
