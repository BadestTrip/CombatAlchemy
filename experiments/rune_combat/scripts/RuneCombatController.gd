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

@onready var state_machine := get_node(state_machine_path) as RuneCombatStateMachine
@onready var combat_input := get_node(combat_input_path) as RuneCombatInput
@onready var rune_wheel := get_node(rune_wheel_path) as RuneWheelController
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


func _ready() -> void:
	rune_wheel.rune_selected.connect(_on_rune_selected)
	combat_input.rune_index_selected.connect(_on_rune_index_selected)
	combat_input.cast_requested.connect(_on_cast_requested)
	combat_input.clear_requested.connect(_on_clear_requested)
	combat_input.remove_last_requested.connect(_on_remove_last_requested)
	combat_input.wheel_toggle_requested.connect(_on_wheel_toggle_requested)
	chant_builder.chant_changed.connect(_on_chant_changed)
	state_machine.state_changed.connect(_on_state_changed)
	player_unit.changed.connect(_update_unit_status)
	enemy_unit.changed.connect(_update_unit_status)
	enemy_unit.defeated.connect(_on_enemy_defeated)
	player_unit.defeated.connect(_on_player_defeated)

	_update_chant_slots(chant_builder.get_sequence())
	_update_preview(chant_builder.get_sequence())
	_update_unit_status()
	_on_state_changed(state_machine.current_state)
	_log_line("Rune combat prototype ready. Click runes or press 1-5, Space to cast, C to clear.")


func _on_rune_selected(rune_id: String) -> void:
	if not state_machine.can_accept_chant_input():
		return
	state_machine.begin_chant()
	if not chant_builder.add_rune(rune_id):
		_log_line("Chant is full. Cast, clear, or remove the last rune.")


func _on_rune_index_selected(index: int) -> void:
	rune_wheel.select_rune_by_index(index)


func _on_cast_requested() -> void:
	var sequence := chant_builder.get_sequence()
	if sequence.is_empty():
		_log_line("No runes selected.")
		return

	state_machine.begin_cast()
	var context := {
		"player_unit": player_unit,
		"enemy_unit": enemy_unit,
	}
	var result := spell_resolver.resolve(sequence, context)
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

	chant_builder.clear()
	state_machine.finish_recovery()
	_update_unit_status()


func _on_clear_requested() -> void:
	chant_builder.clear()
	_log_line("Chant cleared.")


func _on_remove_last_requested() -> void:
	chant_builder.remove_last()


func _on_wheel_toggle_requested() -> void:
	if state_machine.current_state == RuneCombatStateMachine.State.WHEEL_OPEN:
		state_machine.close_wheel()
	else:
		state_machine.open_wheel()


func _on_chant_changed(sequence: Array[String]) -> void:
	_update_chant_slots(sequence)
	_update_preview(sequence)


func _on_state_changed(new_state: int) -> void:
	state_label.text = "State: %s" % state_machine.get_state_name(new_state)


func _on_enemy_defeated() -> void:
	_log_line("[color=lime]Dummy defeated. Prototype victory is reachable.[/color]")
	state_machine.end_combat()


func _on_player_defeated() -> void:
	_log_line("[color=red]Player defeated by instability. Prototype defeat is reachable.[/color]")
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
