class_name PotionCombatController
extends Node2D

# Responsibility: Coordinate potion input, unfinished mixing, held ownership, and entity delivery.

## Path to the PotionInput node that emits mapped combat actions.
@export var potion_input_path: NodePath
## Path to the PotionMixer node that stores unfinished reagent layers.
@export var potion_mixer_path: NodePath
## Path to the HeldPotionSlot that owns the currently held potion and entity references.
@export var held_potion_slot_path: NodePath
## Path to the PotionMixerUI control that reflects mixer state to the player.
@export var potion_mixer_ui_path: NodePath
## Path to the player movement controller that provides holder and delivery geometry.
@export var player_combat_controller_path: NodePath
## Path to the Node2D that owns flying and placed potion entities.
@export var potion_entities_parent_path: NodePath
## Entity scene instantiated once when a potion mixture succeeds.
@export var potion_entity_scene: PackedScene = preload("res://combat/potions/PotionEntity.tscn")

var _potion_input: PotionInput
var _potion_mixer: PotionMixer
var _held_potion_slot: HeldPotionSlot
var _potion_mixer_ui: PotionMixerUI
var _player_combat_controller: PlayerCombatController
var _potion_entities_parent: Node2D
var _mixer_open := false


func _ready() -> void:
	_potion_input = get_node_or_null(potion_input_path) as PotionInput
	_potion_mixer = get_node_or_null(potion_mixer_path) as PotionMixer
	_held_potion_slot = get_node_or_null(held_potion_slot_path) as HeldPotionSlot
	_potion_mixer_ui = get_node_or_null(potion_mixer_ui_path) as PotionMixerUI
	_player_combat_controller = get_node_or_null(player_combat_controller_path) as PlayerCombatController
	_potion_entities_parent = get_node_or_null(potion_entities_parent_path) as Node2D
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
	if _held_potion_slot == null:
		missing_dependencies.append("HeldPotionSlot")
	if _potion_mixer_ui == null:
		missing_dependencies.append("PotionMixerUI")
	if _player_combat_controller == null:
		missing_dependencies.append("PlayerCombatController")
	if _potion_entities_parent == null:
		missing_dependencies.append("potion entities parent")
	if potion_entity_scene == null:
		missing_dependencies.append("potion entity scene")
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
	_potion_input.potion_use_requested.connect(_on_potion_use_requested)
	_potion_input.remove_reagent_requested.connect(_on_remove_reagent_requested)
	_potion_input.clear_mixture_requested.connect(_on_clear_mixture_requested)
	_potion_mixer_ui.reagent_selected.connect(_on_reagent_requested)
	_potion_mixer.layers_changed.connect(_on_layers_changed)
	_potion_mixer.potion_prepared.connect(_on_potion_prepared)
	_potion_mixer.mix_rejected.connect(_on_mix_rejected)
	_potion_mixer.mixture_cleared.connect(_on_mixture_cleared)


func _on_mixer_toggle_requested() -> void:
	if _held_potion_slot.has_potion():
		return
	_mixer_open = not _mixer_open
	_potion_mixer_ui.set_open(_mixer_open)
	if _mixer_open:
		_potion_mixer_ui.show_mixing(_potion_mixer.get_layers())


func _on_reagent_requested(reagent: StringName) -> void:
	if not _mixer_open or _held_potion_slot.has_potion():
		return
	_potion_mixer.add_reagent(reagent)


func _on_mix_requested() -> void:
	if not _mixer_open or _held_potion_slot.has_potion():
		return
	_potion_mixer.mix()


func _on_potion_use_requested(delivery_method: StringName) -> void:
	if not _held_potion_slot.has_potion():
		return
	var entity := _held_potion_slot.get_entity()
	if entity == null or not is_instance_valid(entity):
		return
	var succeeded := false
	match delivery_method:
		PotionDelivery.DRINK:
			succeeded = entity.drink(_player_combat_controller)
		PotionDelivery.THROW:
			succeeded = entity.throw_into(
				_potion_entities_parent,
				_player_combat_controller.get_throw_origin(),
				_player_combat_controller.get_throw_direction()
			)
		PotionDelivery.PLACE:
			succeeded = entity.place_into(
				_potion_entities_parent,
				_player_combat_controller.get_place_position()
			)
		_:
			return
	if succeeded:
		_held_potion_slot.clear()
		_close_mixer_after_use()


func _on_remove_reagent_requested() -> void:
	if not _mixer_open or _held_potion_slot.has_potion():
		return
	_potion_mixer.remove_last()


func _on_clear_mixture_requested() -> void:
	var should_open_mixer := _mixer_open or _held_potion_slot.has_potion()
	if _held_potion_slot.has_potion():
		var entity := _held_potion_slot.get_entity()
		if entity != null and is_instance_valid(entity):
			entity.discard()
		_held_potion_slot.clear()
	_potion_mixer.clear()
	_mixer_open = should_open_mixer
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(_mixer_open)


func _on_layers_changed(layers: Array[StringName]) -> void:
	if _mixer_open and not _held_potion_slot.has_potion():
		_potion_mixer_ui.show_mixing(layers)


func _on_potion_prepared(potion: PotionInstance) -> void:
	if potion == null or not potion.is_valid() or potion.is_consumed():
		_reject_prepared_potion(potion, null, "Prepared potion instance was invalid.")
		return
	var candidate := potion_entity_scene.instantiate()
	if not candidate is PotionEntity:
		if candidate != null:
			candidate.free()
		_reject_prepared_potion(potion, null, "Prepared potion could not instantiate PotionEntity.")
		return
	var entity := candidate as PotionEntity
	_potion_entities_parent.add_child(entity)
	if not entity.initialize(potion, _player_combat_controller):
		_reject_prepared_potion(potion, entity, "Prepared PotionEntity could not initialize.")
		return
	var holder := _player_combat_controller.get_potion_holder()
	if holder == null or not entity.attach_to(holder):
		_reject_prepared_potion(potion, entity, "Prepared PotionEntity could not attach to the player holder.")
		return
	if not _held_potion_slot.hold(potion, entity):
		_reject_prepared_potion(potion, entity, "Prepared PotionEntity could not enter HeldPotionSlot.")
		return
	_mixer_open = true
	_potion_mixer_ui.set_open(true)
	_potion_mixer_ui.show_ready(potion.get_color())


func _reject_prepared_potion(
	potion: PotionInstance,
	entity: PotionEntity,
	message: String
) -> void:
	if entity != null and is_instance_valid(entity):
		if entity.get_potion() == potion and entity.get_state() == PotionEntity.State.HELD:
			entity.discard()
		else:
			entity.queue_free()
	if potion != null and not potion.is_consumed():
		potion.discard()
	push_warning(message)
	_mixer_open = true
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(true)


func _on_mix_rejected(_layers: Array[StringName]) -> void:
	if _mixer_open and not _held_potion_slot.has_potion():
		_potion_mixer_ui.show_mix_failure()


func _on_mixture_cleared() -> void:
	if _mixer_open and not _held_potion_slot.has_potion():
		_potion_mixer_ui.reset_view()


func _close_mixer_after_use() -> void:
	_mixer_open = false
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(false)
