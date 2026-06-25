extends Area2D
class_name DuelInteractable


@export var prompt_label_path: NodePath


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
	GameManager.start_duel_from_overworld()


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
		prompt_label.visible = is_visible
