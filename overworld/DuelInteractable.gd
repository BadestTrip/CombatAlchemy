extends Area2D
class_name DuelInteractable


@export var prompt_label_path: NodePath
@export var prompt_before_victory: String = "Press E to begin duel"
@export var prompt_after_victory: String = "Press E to duel again"
@export var use_game_manager_duel_flow: bool = true
@export var custom_combat_scene: PackedScene
@export var encounter_data: EncounterData
@export var requires_training_duel_won: bool = false
@export var locked_prompt: String = "Train first before entering the lair."


@onready var prompt_label: Label = get_node_or_null(prompt_label_path) as Label


var _player_in_range: bool = false
var _player_body: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_prompt_visible(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if not event.is_action_pressed("interact"):
		return

	get_viewport().set_input_as_handled()

	if _is_locked():
		_set_prompt_visible(true)
		return

	# Scene changes stay routed through GameManager so transitions and global
	# flow remain in one place as the overworld grows later.
	if use_game_manager_duel_flow or custom_combat_scene != null:
		_remember_player_return_position()
		GameManager.start_duel_from_overworld(encounter_data, custom_combat_scene)
	else:
		push_warning("DuelInteractable has no custom combat scene assigned.")


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("overworld_player"):
		return
	_player_in_range = true
	_player_body = body as Node2D
	_set_prompt_visible(true)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("overworld_player"):
		return
	if body == _player_body:
		_player_body = null
	_player_in_range = false
	_set_prompt_visible(false)


func _set_prompt_visible(is_visible: bool) -> void:
	if prompt_label != null:
		prompt_label.text = _get_prompt_text()
		prompt_label.visible = is_visible


func _get_prompt_text() -> String:
	if _is_locked():
		return locked_prompt
	return prompt_after_victory if _is_defeated() else prompt_before_victory


func _is_locked() -> bool:
	return requires_training_duel_won and not GameManager.training_duel_won


func _is_defeated() -> bool:
	if encounter_data != null and not encounter_data.encounter_id.is_empty():
		return GameManager.has_defeated_encounter(encounter_data.encounter_id)
	return GameManager.training_duel_won


func _remember_player_return_position() -> void:
	if _player_body != null:
		GameManager.remember_overworld_player_position(_player_body.global_position)
