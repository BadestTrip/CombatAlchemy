extends Node
class_name OverworldStateController


const TRAINING_ENCOUNTER_ID: String = "training_adept"
const MINIBOSS_ENCOUNTER_ID: String = "miniboss_lair"

const COLOR_AVAILABLE: Color = Color(0.95, 0.82, 0.48, 1.0)
const COLOR_COMPLETE: Color = Color(0.58, 0.92, 0.62, 1.0)
const COLOR_LOCKED: Color = Color(0.72, 0.72, 0.72, 1.0)


@export var hint_label_path: NodePath = NodePath("HUD/Hint")
@export var training_label_path: NodePath = NodePath("TrainigCamp/ObjectLabel")
@export var miniboss_label_path: NodePath = NodePath("MiniBossLair/ObjectLabel")

@onready var hint_label: Label = get_node_or_null(hint_label_path) as Label
@onready var training_label: Label = get_node_or_null(training_label_path) as Label
@onready var miniboss_label: Label = get_node_or_null(miniboss_label_path) as Label


func _ready() -> void:
	refresh_state()


func refresh_state() -> void:
	var training_complete := _is_training_complete()
	var miniboss_complete := _is_miniboss_complete()

	_update_hint(training_complete, miniboss_complete)
	_update_training_label(training_complete)
	_update_miniboss_label(training_complete, miniboss_complete)


func _is_training_complete() -> bool:
	return (
		GameManager.training_duel_won
		or GameManager.has_defeated_encounter(TRAINING_ENCOUNTER_ID)
	)


func _is_miniboss_complete() -> bool:
	return (
		GameManager.miniboss_lair_defeated
		or GameManager.has_defeated_encounter(MINIBOSS_ENCOUNTER_ID)
	)


func _update_hint(training_complete: bool, miniboss_complete: bool) -> void:
	if hint_label == null:
		return

	if miniboss_complete:
		hint_label.text = "The lair is quiet. Prototype route complete."
	elif training_complete:
		hint_label.text = "Training complete. The miniboss lair is now open."
	else:
		hint_label.text = "Walk to the training camp. Complete your first rune duel."


func _update_training_label(training_complete: bool) -> void:
	if training_label == null:
		return

	training_label.text = "Training Complete" if training_complete else "Training Adept"
	training_label.add_theme_color_override(
		"font_color",
		COLOR_COMPLETE if training_complete else COLOR_AVAILABLE
	)


func _update_miniboss_label(training_complete: bool, miniboss_complete: bool) -> void:
	if miniboss_label == null:
		return

	if miniboss_complete:
		miniboss_label.text = "Lair Cleared"
		miniboss_label.add_theme_color_override("font_color", COLOR_COMPLETE)
	elif training_complete:
		miniboss_label.text = "MiniBoss Lair"
		miniboss_label.add_theme_color_override("font_color", COLOR_AVAILABLE)
	else:
		miniboss_label.text = "MiniBoss Lair - Locked"
		miniboss_label.add_theme_color_override("font_color", COLOR_LOCKED)
