extends Node
class_name RuneCombatController

@export var state_machine_path: NodePath
@export var combat_input_path: NodePath
@export var rune_wheel_path: NodePath
@export var chant_builder_path: NodePath
@export var spell_resolver_path: NodePath
@export var spell_executor_path: NodePath
@export var spellbook_recorder_path: NodePath
@export var player_unit_path: NodePath
@export var enemy_unit_path: NodePath
@export var chant_slots_container_path: NodePath
@export var preview_path: NodePath
@export var log_text_path: NodePath
@export var player_status_label_path: NodePath
@export var enemy_status_label_path: NodePath
@export var state_label_path: NodePath
@export var effects_parent_path: NodePath
@export var battlefield_dimmer_path: NodePath
@export var prepared_label_path: NodePath
@export var floating_wheel_offset: Vector2 = Vector2(0.0, -90.0)

@onready var state_machine := get_node(state_machine_path) as RuneCombatStateMachine
@onready var combat_input := get_node(combat_input_path) as RuneCombatInput
@onready var rune_wheel := get_node(rune_wheel_path) as ExperimentalRuneWheelController
@onready var chant_builder := get_node(chant_builder_path) as ChantBuilder
@onready var spell_resolver := get_node(spell_resolver_path) as SpellResolver
@onready var spell_executor := get_node(spell_executor_path) as SpellExecutor
@onready var spellbook_recorder := get_node(spellbook_recorder_path) as SpellbookRecorder
@onready var player_unit := get_node(player_unit_path) as CombatUnit
@onready var enemy_unit := get_node(enemy_unit_path) as CombatUnit
@onready var chant_slots_container := get_node(chant_slots_container_path) as HBoxContainer
@onready var preview := get_node(preview_path) as ChantPreviewController
@onready var log_text := get_node(log_text_path) as RichTextLabel
@onready var player_status_label := get_node(player_status_label_path) as Label
@onready var enemy_status_label := get_node(enemy_status_label_path) as Label
@onready var state_label := get_node(state_label_path) as Label
@onready var effects_parent := get_node(effects_parent_path) as Node
@onready var battlefield_dimmer := get_node(battlefield_dimmer_path) as ColorRect
@onready var prepared_label := get_node(prepared_label_path) as Label

var prepared_spell_result: SpellResultData = null
var prepared_sequence: Array[String] = []


func _ready() -> void:
	rune_wheel.rune_selected.connect(_on_rune_selected)
	combat_input.rune_index_selected.connect(_on_rune_index_selected)
	combat_input.wheel_hold_started.connect(_on_wheel_hold_started)
	combat_input.wheel_hold_ended.connect(_on_wheel_hold_ended)
	combat_input.chant_prepare_requested.connect(_on_chant_prepare_requested)
	combat_input.shoot_requested.connect(_on_shoot_requested)
	combat_input.clear_requested.connect(_on_clear_requested)
	combat_input.remove_last_requested.connect(_on_remove_last_requested)
	chant_builder.chant_changed.connect(_on_chant_changed)
	state_machine.state_changed.connect(_on_state_changed)
	player_unit.changed.connect(_update_unit_status)
	enemy_unit.changed.connect(_update_unit_status)
	enemy_unit.defeated.connect(_on_enemy_defeated)
	player_unit.defeated.connect(_on_player_defeated)

	_update_chant_slots(chant_builder.get_sequence())
	_update_preview(chant_builder.get_sequence())
	_update_unit_status()
	_update_prepared_label()
	_on_state_changed(state_machine.current_state)
	_set_wheel_focus(false)
	_log_line("Rune combat prototype ready. Hold Tab to build a chant, Space to prepare, then aim and shoot.")


func _process(_delta: float) -> void:
	if state_machine.current_state == RuneCombatStateMachine.State.WHEEL_OPEN:
		_update_floating_wheel_position()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_rune_selected(rune_id: String) -> void:
	if not state_machine.can_accept_chant_input():
		return
	if not chant_builder.add_rune(rune_id):
		_log_line("Chant is full. Cast, clear, or remove the last rune.")


func _on_rune_index_selected(index: int) -> void:
	if not state_machine.can_accept_chant_input():
		return
	rune_wheel.select_rune_by_index(index)


func _on_wheel_hold_started() -> void:
	if state_machine.current_state == RuneCombatStateMachine.State.ENDED:
		return
	state_machine.open_wheel()
	combat_input.set_wheel_open(true)
	_set_wheel_focus(true)


func _on_wheel_hold_ended() -> void:
	if state_machine.current_state != RuneCombatStateMachine.State.WHEEL_OPEN:
		return
	var has_prepared_chant := prepared_spell_result != null
	state_machine.close_wheel(has_prepared_chant)
	combat_input.set_wheel_open(false)
	_set_wheel_focus(false)
	if not has_prepared_chant:
		chant_builder.clear()


func _on_chant_prepare_requested() -> void:
	if state_machine.current_state != RuneCombatStateMachine.State.WHEEL_OPEN:
		return

	var sequence := chant_builder.get_sequence()
	if sequence.is_empty():
		_log_line("No runes selected.")
		return

	prepared_sequence = sequence
	prepared_spell_result = spell_resolver.resolve(sequence)
	state_machine.prepare_chant()
	chant_builder.clear()
	combat_input.set_wheel_open(false)
	_set_wheel_focus(false)
	_update_prepared_label()

	_log_line("Prepared chant: %s / %s" % [_sequence_to_text(prepared_sequence), prepared_spell_result.display_name])
	_log_line("Aim with mouse and press Space or Left Mouse Button to shoot.")


func _on_shoot_requested() -> void:
	if state_machine.current_state == RuneCombatStateMachine.State.WHEEL_OPEN:
		return
	if prepared_spell_result == null:
		_log_line("No prepared chant.")
		return
	if not state_machine.begin_shoot(true):
		return

	var result := prepared_spell_result
	var sequence := _copy_sequence(prepared_sequence)
	var player_node := player_unit.get_parent() as PlayerCombatController
	var enemy_node := enemy_unit.get_parent() as Node2D
	var context := {
		"player_unit": player_unit,
		"enemy_unit": enemy_unit,
		"player_node": player_node,
		"caster_node": player_node,
		"enemy_node": enemy_node,
		"cast_origin": player_node.get_cast_origin() if player_node != null else Vector2.ZERO,
		"aim_position": player_node.get_aim_position() if player_node != null else Vector2.ZERO,
		"target_position": player_node.get_aim_position() if player_node != null else Vector2.ZERO,
		"aim_direction": player_node.get_aim_direction() if player_node != null else Vector2.RIGHT,
		"effects_parent": effects_parent,
		"log_callback": Callable(self, "_log_line")
	}
	var lines := spell_executor.execute(result, context)
	spellbook_recorder.record_cast(result)

	_log_line("[b]%s[/b]  %s  Stability %s (%d)" % [
		result.display_name,
		_sequence_to_text(sequence),
		result.instability_label,
		result.instability_score,
	])
	_log_line(result.description)
	for line in lines:
		_log_line(line)

	prepared_spell_result = null
	prepared_sequence.clear()
	_update_prepared_label()
	state_machine.finish_recovery()
	_update_unit_status()


func _on_clear_requested() -> void:
	if state_machine.current_state == RuneCombatStateMachine.State.WHEEL_OPEN:
		chant_builder.clear()
		_log_line("Chant cleared.")
		return

	if prepared_spell_result != null:
		prepared_spell_result = null
		prepared_sequence.clear()
		_update_prepared_label()
		if state_machine.current_state == RuneCombatStateMachine.State.CHANT_PREPARED:
			state_machine.finish_recovery()
		_log_line("Prepared chant cleared.")


func _on_remove_last_requested() -> void:
	if state_machine.current_state != RuneCombatStateMachine.State.WHEEL_OPEN:
		return
	chant_builder.remove_last()


func _on_chant_changed(sequence: Array[String]) -> void:
	_update_chant_slots(sequence)
	_update_preview(sequence)


func _on_state_changed(new_state: int) -> void:
	state_label.text = "State: %s" % state_machine.get_state_name(new_state)


func _on_enemy_defeated() -> void:
	_log_line("[color=lime]Dummy defeated. Prototype victory is reachable.[/color]")
	_set_wheel_focus(false)
	state_machine.end_combat()


func _on_player_defeated() -> void:
	_log_line("[color=red]Player defeated by instability. Prototype defeat is reachable.[/color]")
	_set_wheel_focus(false)
	state_machine.end_combat()


func _update_chant_slots(sequence: Array[String]) -> void:
	var children := chant_slots_container.get_children()
	for index in range(children.size()):
		var label := children[index] as Label
		if label == null:
			continue
		label.text = sequence[index] if index < sequence.size() else "_"


func _update_preview(sequence: Array[String]) -> void:
	preview.update_preview(spell_resolver.preview(sequence))


func _update_unit_status() -> void:
	player_status_label.text = player_unit.get_status_text()
	enemy_status_label.text = enemy_unit.get_status_text()


func _update_prepared_label() -> void:
	if prepared_spell_result == null:
		prepared_label.text = "Prepared: None"
		return
	prepared_label.text = "Prepared: %s %s\nShoot: Space / Left Mouse Button" % [
		prepared_spell_result.display_name,
		_sequence_to_text(prepared_sequence)
	]


func _set_wheel_focus(is_open: bool) -> void:
	rune_wheel.visible = is_open
	battlefield_dimmer.visible = is_open
	Engine.time_scale = 0.25 if is_open else 1.0
	if is_open:
		_update_floating_wheel_position()


func _update_floating_wheel_position() -> void:
	var player_node := player_unit.get_parent() as Node2D
	if player_node == null:
		return

	var wheel_size := rune_wheel.size
	if wheel_size.x <= 0.0 or wheel_size.y <= 0.0:
		wheel_size = rune_wheel.custom_minimum_size
	rune_wheel.global_position = player_node.global_position + floating_wheel_offset - wheel_size * 0.5


func _log_line(line: String) -> void:
	log_text.append_text(line + "\n")
	var line_count := log_text.get_line_count()
	if line_count > 0:
		log_text.scroll_to_line(line_count - 1)


func _sequence_to_text(sequence: Array[String]) -> String:
	var parts := PackedStringArray()
	for rune_id in sequence:
		parts.append(rune_id)
	return "[" + " -> ".join(parts) + "]"


func _copy_sequence(sequence: Array[String]) -> Array[String]:
	var copy: Array[String] = []
	for rune_id in sequence:
		copy.append(rune_id)
	return copy
