class_name PotionCombatController
extends Node2D

# Responsibility: Coordinate potion input, mixing, player consumption, and projectile spawning.

const ACTION_DRINK := &"drink"
const ACTION_THROW := &"throw"
const EVENT_DRINK_COMMIT := &"drink_commit"
const EVENT_THROW_RELEASE := &"throw_release"

## Path to the PotionInput node that emits mapped combat actions.
@export var potion_input_path: NodePath
## Path to the PotionMixer node that stores layers and prepared recipes.
@export var potion_mixer_path: NodePath
## Path to the PotionMixerUI control that reflects mixer state to the player.
@export var potion_mixer_ui_path: NodePath
## Path to the player movement controller that provides the current aiming direction.
@export var player_combat_controller_path: NodePath
## Path to the player animation adapter that owns action timing and hand position.
@export var player_animation_controller_path: NodePath
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
var _player_animation_controller: Node
var _player_potion_target: PotionTarget
var _projectiles_parent: Node2D
var _mixer_open := false
var _pending_recipe: PotionRecipeData
var _pending_action: StringName = &""


func _ready() -> void:
	_potion_input = get_node_or_null(potion_input_path) as PotionInput
	_potion_mixer = get_node_or_null(potion_mixer_path) as PotionMixer
	_potion_mixer_ui = get_node_or_null(potion_mixer_ui_path) as PotionMixerUI
	_player_combat_controller = get_node_or_null(player_combat_controller_path) as PlayerCombatController
	_player_animation_controller = get_node_or_null(player_animation_controller_path)
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
	if _player_animation_controller == null:
		missing_dependencies.append("PlayerAnimationController")
	elif not _has_player_animation_api():
		missing_dependencies.append("PlayerAnimationController public API")
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


func _has_player_animation_api() -> bool:
	var required_methods: Array[StringName] = [
		&"request_potion_action",
		&"is_busy",
		&"get_action_origin",
	]
	for method_name in required_methods:
		if not _player_animation_controller.has_method(method_name):
			return false

	var required_signals: Array[StringName] = [
		&"action_event",
		&"action_interrupted",
		&"action_finished",
	]
	for signal_name in required_signals:
		if not _player_animation_controller.has_signal(signal_name):
			return false
	return true


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
	_player_animation_controller.connect(&"action_event", _on_player_action_event)
	_player_animation_controller.connect(&"action_interrupted", _on_player_action_interrupted)
	_player_animation_controller.connect(&"action_finished", _on_player_action_finished)


func _on_mixer_toggle_requested() -> void:
	if _is_player_action_busy() or _potion_mixer.has_prepared_potion():
		return
	_mixer_open = not _mixer_open
	_potion_mixer_ui.set_open(_mixer_open)
	if _mixer_open:
		_potion_mixer_ui.show_mixing(_potion_mixer.get_layers())


func _on_reagent_requested(reagent: StringName) -> void:
	if _is_player_action_busy() or not _mixer_open or _potion_mixer.has_prepared_potion():
		return
	_potion_mixer.add_reagent(reagent)


func _on_mix_requested() -> void:
	if _is_player_action_busy() or not _mixer_open or _potion_mixer.has_prepared_potion():
		return
	_potion_mixer.mix()


func _on_drink_requested() -> void:
	if _is_player_action_busy() or _pending_recipe != null or not _potion_mixer.has_prepared_potion():
		return
	var recipe := _potion_mixer.get_prepared_recipe()
	if recipe == null:
		return
	if not (_player_animation_controller.call(
		&"request_potion_action",
		ACTION_DRINK,
		Vector2.ZERO,
		recipe.mixed_color
	) as bool):
		return
	_pending_recipe = _potion_mixer.take_prepared_recipe()
	_pending_action = ACTION_DRINK
	_close_mixer_for_action()


func _on_throw_requested() -> void:
	if (
		_is_player_action_busy()
		or _pending_recipe != null
		or not _potion_mixer.has_prepared_potion()
		or projectile_scene == null
	):
		return
	if (
		not is_instance_valid(_projectiles_parent)
		or not is_instance_valid(_player_combat_controller)
		or not is_instance_valid(_player_animation_controller)
	):
		return
	var recipe := _potion_mixer.get_prepared_recipe()
	if recipe == null:
		return
	var direction := _player_combat_controller.get_throw_direction()
	if not (_player_animation_controller.call(
		&"request_potion_action",
		ACTION_THROW,
		direction,
		recipe.mixed_color
	) as bool):
		return
	_pending_recipe = _potion_mixer.take_prepared_recipe()
	_pending_action = ACTION_THROW
	_close_mixer_for_action()


func _on_remove_reagent_requested() -> void:
	if _is_player_action_busy() or not _mixer_open or _potion_mixer.has_prepared_potion():
		return
	_potion_mixer.remove_last()


func _on_clear_mixture_requested() -> void:
	if _is_player_action_busy():
		return
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


func _on_player_action_event(event_name: StringName, committed_direction: Vector2) -> void:
	if _pending_recipe == null:
		return
	if (
		(_pending_action == ACTION_DRINK and event_name != EVENT_DRINK_COMMIT)
		or (_pending_action == ACTION_THROW and event_name != EVENT_THROW_RELEASE)
	):
		return

	var recipe := _pending_recipe
	var action := _pending_action
	_clear_pending_action()
	if action == ACTION_DRINK:
		if not _player_potion_target.receive_potion(recipe):
			push_warning("Player rejected the committed drink recipe.")
		return

	var projectile := projectile_scene.instantiate() as PotionProjectile
	if projectile == null:
		push_warning("Committed throw could not instantiate PotionProjectile.")
		return
	_projectiles_parent.add_child(projectile)
	if not projectile.launch(
		recipe,
		_player_animation_controller.call(&"get_action_origin") as Vector2,
		committed_direction,
		_player_potion_target
	):
		push_warning("Committed throw could not launch PotionProjectile.")


func _on_player_action_interrupted(action: StringName) -> void:
	if action != _pending_action:
		return
	_clear_pending_action()


func _on_player_action_finished(action: StringName) -> void:
	if action != _pending_action or _pending_recipe == null:
		return
	push_warning("Player action '%s' finished without its authored potion event; discarding recipe." % action)
	_clear_pending_action()


func _is_player_action_busy() -> bool:
	return (
		_player_animation_controller != null
		and (_player_animation_controller.call(&"is_busy") as bool)
	)


func _close_mixer_for_action() -> void:
	_mixer_open = false
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(false)


func _clear_pending_action() -> void:
	_pending_recipe = null
	_pending_action = &""
