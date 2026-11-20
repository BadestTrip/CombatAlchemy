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
var _profile: PlayerProfile
var _profile_error_dialog: AcceptDialog
var _application_focused := true
var _heat_power_setting := 0.5
var _fire_active := false
var _brew_fire_restore_state := false
var _brew_fire_policy_active := false
var _brew_fire_manually_overridden := false


func _ready() -> void:
	_potion_input = get_node_or_null(potion_input_path) as PotionInput
	_potion_mixer = get_node_or_null(potion_mixer_path) as PotionMixer
	_held_potion_slot = get_node_or_null(held_potion_slot_path) as HeldPotionSlot
	_potion_mixer_ui = get_node_or_null(potion_mixer_ui_path) as PotionMixerUI
	_player_combat_controller = get_node_or_null(player_combat_controller_path) as PlayerCombatController
	_potion_entities_parent = get_node_or_null(potion_entities_parent_path) as Node2D
	_profile_error_dialog = get_node_or_null("UI/ProfileErrorDialog") as AcceptDialog
	if not _has_valid_dependencies():
		_disable_controller()
		return
	_profile = GameManager.get_player_profile()
	if _profile == null:
		push_error("Potion combat requires a loaded player profile.")
		_disable_controller()
		return
	_potion_mixer.configure_inventory(_profile.inventory)
	_potion_mixer_ui.configure_inventory(_profile.inventory)
	var collector := _player_combat_controller.get_node_or_null("ReagentCollector") as PlayerReagentCollector
	if collector != null:
		collector.configure(_profile)
		collector.collection_failed.connect(_show_profile_error)

	_connect_signals()
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(false)
	_heat_power_setting = _potion_input.presentation_profile.default_heat_power
	_potion_mixer.set_heat_power(_heat_power_setting)
	_set_fire_active(false, false)
	_update_brewing_suspension()
	_restore_saved_potion()


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
	_potion_input.mix_pressed.connect(_on_mix_pressed)
	_potion_input.heat_adjust_requested.connect(_on_heat_adjust_requested)
	_potion_input.focus_changed.connect(_on_focus_changed)
	_potion_input.potion_use_requested.connect(_on_potion_use_requested)
	_potion_input.remove_reagent_requested.connect(_on_remove_reagent_requested)
	_potion_input.clear_mixture_requested.connect(_on_clear_mixture_requested)
	_potion_mixer_ui.reagent_selected.connect(_on_reagent_requested)
	_potion_mixer_ui.heat_power_changed.connect(_on_heat_power_changed)
	_potion_mixer_ui.fire_toggle_requested.connect(_on_fire_toggle_requested)
	_potion_mixer.check_completed.connect(_potion_mixer_ui.show_check_result)
	_potion_mixer.layers_changed.connect(_on_layers_changed)
	_potion_mixer.preparation_requested.connect(_on_preparation_requested)
	_potion_mixer.potion_prepared.connect(_on_potion_prepared)
	_potion_mixer.mix_rejected.connect(_on_mix_rejected)
	_potion_mixer.mixture_cleared.connect(_on_mixture_cleared)
	_potion_mixer.brewing_changed.connect(_on_brewing_changed)


func _on_mixer_toggle_requested() -> void:
	if _held_potion_slot.has_potion():
		return
	_mixer_open = not _mixer_open
	_potion_mixer_ui.set_open(_mixer_open)
	_update_brewing_suspension()
	if _mixer_open:
		_show_current_mixer_state()


func _on_reagent_requested(reagent: StringName) -> void:
	if not _mixer_open or _held_potion_slot.has_potion():
		return
	_potion_mixer.add_reagent(reagent)


func _on_mix_pressed() -> void:
	if not _mixer_open or _held_potion_slot.has_potion():
		return
	if _potion_mixer.get_brewing_state() == BrewingReaction.State.IDLE:
		if _potion_mixer.start_brewing():
			_begin_brew_fire_policy()
	else:
		_potion_mixer.release_brewing()


func _on_heat_adjust_requested(direction: int) -> void:
	_on_heat_power_changed(_heat_power_setting + direction * _potion_input.presentation_profile.heat_step)


func _on_heat_power_changed(power: float) -> void:
	if not _mixer_open or _held_potion_slot.has_potion() or not _application_focused or get_tree().paused:
		return
	_heat_power_setting = clampf(power, 0.0, 1.0)
	_potion_mixer.set_heat_power(_heat_power_setting)
	_potion_mixer_ui.set_heat_power(_heat_power_setting)


func _on_fire_toggle_requested() -> void:
	if not _mixer_open or not _application_focused or get_tree().paused:
		return
	_set_fire_active(not _fire_active, true)


func _set_fire_active(active: bool, manual_change: bool) -> void:
	_fire_active = active
	if manual_change and _brew_fire_policy_active:
		_brew_fire_manually_overridden = true
	_potion_mixer.set_heat_enabled(active)
	_potion_mixer_ui.set_fire_active(active)
	_potion_mixer_ui.set_heat_power(_heat_power_setting)


func _begin_brew_fire_policy() -> void:
	_brew_fire_restore_state = _fire_active
	_brew_fire_policy_active = true
	_brew_fire_manually_overridden = false
	if not _fire_active:
		_set_fire_active(true, false)


func _finish_brew_fire_policy() -> void:
	if not _brew_fire_policy_active:
		return
	if not _brew_fire_manually_overridden:
		_set_fire_active(_brew_fire_restore_state, false)
	_brew_fire_policy_active = false
	_brew_fire_manually_overridden = false


func _on_focus_changed(focused: bool) -> void:
	_application_focused = focused
	_update_brewing_suspension()


func _update_brewing_suspension() -> void:
	var suspended := not _mixer_open or not _application_focused
	_potion_mixer.set_suspended(suspended)
	_potion_mixer_ui.set_animation_suspended(suspended)


func _on_potion_use_requested(delivery_method: StringName) -> void:
	if not _held_potion_slot.has_potion():
		return
	var entity := _held_potion_slot.get_entity()
	if entity == null or not is_instance_valid(entity):
		return
	if delivery_method not in [PotionDelivery.DRINK, PotionDelivery.THROW, PotionDelivery.PLACE]:
		return
	var held_record := _profile.get_held_record()
	if not _profile.clear_held_potion():
		_show_profile_error(_profile.last_error)
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
	else:
		if not _profile.restore_held_potion(held_record):
			_show_profile_error(_profile.last_error)


func _on_remove_reagent_requested() -> void:
	if not _mixer_open or _held_potion_slot.has_potion():
		return
	_potion_mixer.remove_last()


func _on_clear_mixture_requested() -> void:
	var should_open_mixer := _mixer_open or _held_potion_slot.has_potion()
	if _held_potion_slot.has_potion():
		if not _profile.clear_held_potion():
			_show_profile_error(_profile.last_error)
			return
		var entity := _held_potion_slot.get_entity()
		if entity != null and is_instance_valid(entity):
			entity.discard()
		_held_potion_slot.clear()
	_potion_mixer.clear()
	_finish_brew_fire_policy()
	_mixer_open = should_open_mixer
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(_mixer_open)
	_update_brewing_suspension()


func _on_layers_changed(layers: Array[StringName]) -> void:
	if _mixer_open and not _held_potion_slot.has_potion():
		_potion_mixer_ui.show_mixing(layers)


func _on_preparation_requested(potion: PotionInstance) -> void:
	_finish_brew_fire_policy()
	if potion == null or not potion.is_valid() or potion.is_consumed():
		_potion_mixer.acknowledge_preparation(potion, false)
		return
	var candidate := potion_entity_scene.instantiate()
	if not candidate is PotionEntity:
		if candidate != null:
			candidate.free()
		_potion_mixer.acknowledge_preparation(potion, false)
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
	if not _profile.commit_prepared_potion(potion.get_recipe().recipe_id, potion.get_created_layers(), potion.get_quality_score(), potion.get_potency_multiplier()):
		_reject_prepared_potion(potion, entity, _profile.last_error)
		return
	_potion_mixer.acknowledge_preparation(potion, true)

func _restore_saved_potion() -> void:
	if not _profile.has_held_potion():
		return
	var record := _profile.get_held_record()
	var recipe := _potion_mixer.recipe_book.find_by_id(StringName(record.get("recipe_id", ""))) if _potion_mixer.recipe_book != null else null
	var layers: Array[StringName] = []
	for layer in record.get("layers", []):
		layers.append(StringName(layer))
	var potion := PotionInstance.create(recipe, layers, int(record.get("quality_score", 0)), float(record.get("potency_multiplier", 1.0)))
	if potion == null or not _create_and_hold_entity(potion):
		push_warning("Saved held potion could not be restored.")
		return

func _create_and_hold_entity(potion: PotionInstance) -> bool:
	var candidate := potion_entity_scene.instantiate()
	if not candidate is PotionEntity:
		if candidate != null:
			candidate.free()
		return false
	var entity := candidate as PotionEntity
	_potion_entities_parent.add_child(entity)
	if not entity.initialize(potion, _player_combat_controller):
		entity.queue_free()
		return false
	var holder := _player_combat_controller.get_potion_holder()
	if holder == null or not entity.attach_to(holder) or not _held_potion_slot.hold(potion, entity):
		entity.discard()
		return false
	return true

func _on_potion_prepared(potion: PotionInstance) -> void:
	_potion_mixer_ui.set_open(_mixer_open)
	_potion_mixer_ui.show_ready(potion.get_color(), potion.get_quality_score())


func _reject_prepared_potion(
	potion: PotionInstance,
	entity: PotionEntity,
	message: String
) -> void:
	if _held_potion_slot.get_potion() == potion:
		_held_potion_slot.clear()
	if entity != null and is_instance_valid(entity):
		if entity.get_potion() == potion and entity.get_state() == PotionEntity.State.HELD:
			entity.discard()
		else:
			entity.queue_free()
	if potion != null and not potion.is_consumed():
		potion.discard()
	_potion_mixer.acknowledge_preparation(potion, false)
	_show_profile_error(message)
	_mixer_open = true
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(true)
	_update_brewing_suspension()

func _show_profile_error(message: String) -> void:
	if _profile_error_dialog != null:
		_profile_error_dialog.dialog_text = message
		_profile_error_dialog.popup_centered()
	else:
		push_error(message)


func _on_mix_rejected(_layers: Array[StringName]) -> void:
	if _mixer_open and not _held_potion_slot.has_potion():
		_potion_mixer_ui.show_mix_failure()


func _on_mixture_cleared() -> void:
	if _mixer_open and not _held_potion_slot.has_potion():
		_potion_mixer_ui.reset_view()


func _on_brewing_changed(
	state: BrewingReaction.State,
	progress: float,
	_power: float,
	blend: float
) -> void:
	if not _mixer_open or _held_potion_slot.has_potion():
		return
	_potion_mixer_ui.show_brewing(
		_potion_mixer.get_layers(),
		state,
		progress,
		_heat_power_setting,
		blend,
		_potion_mixer.get_brewing_profile(),
		_potion_mixer.get_mixed_color()
	)


func _show_current_mixer_state() -> void:
	var state := _potion_mixer.get_brewing_state()
	if state == BrewingReaction.State.IDLE and is_zero_approx(_potion_mixer.get_brewing_progress()):
		_potion_mixer_ui.show_mixing(_potion_mixer.get_layers())
		return
	_on_brewing_changed(
		state,
		_potion_mixer.get_brewing_progress(),
		_potion_mixer.get_brewing_power(),
		_potion_mixer.get_blend_progress()
	)


func _close_mixer_after_use() -> void:
	_mixer_open = false
	_potion_mixer_ui.reset_view()
	_potion_mixer_ui.set_open(false)
	_update_brewing_suspension()
