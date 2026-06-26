extends Area2D
class_name DuelInteractable


@export var prompt_label_path: NodePath
@export var prompt_before_victory: String = "Press E to begin duel"
@export var prompt_after_victory: String = "Press E to duel again"
@export var use_game_manager_duel_flow: bool = true
@export var custom_combat_scene: PackedScene
@export var encounter_data: EncounterData


@onready var prompt_label: Label = get_node_or_null(prompt_label_path) as Label


var _player_in_range: bool = false


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

	# Scene changes stay routed through GameManager so transitions and global
	# flow remain in one place as the overworld grows later.
	if use_game_manager_duel_flow or custom_combat_scene != null:
		GameManager.start_duel_from_overworld(encounter_data, custom_combat_scene)
	else:
		push_warning("DuelInteractable has no custom combat scene assigned.")


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("overworld_player"):
		return
	_player_in_range = true
	_set_prompt_visible(true)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("overworld_player"):
		return
	_player_in_range = false
	_set_prompt_visible(false)


func _set_prompt_visible(is_visible: bool) -> void:
	if prompt_label != null:
		prompt_label.text = (
			prompt_after_victory
			if _is_defeated()
			else prompt_before_victory
		)
		prompt_label.visible = is_visible


func _is_defeated() -> bool:
	if encounter_data != null and not encounter_data.encounter_id.is_empty():
		return GameManager.has_defeated_encounter(encounter_data.encounter_id)
	return GameManager.training_duel_won
