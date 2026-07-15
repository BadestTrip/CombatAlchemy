class_name ActorHealthBar
extends Control

# Responsibility: Display one actor's world-space name and exact health values.

## The name shown above the health progress bar.
@export var display_name: String = "Actor"
## Path to the HealthComponent whose state this bar displays.
@export var health_component_path: NodePath

@onready var _name_label: Label = $NameLabel
@onready var _progress_bar: ProgressBar = $ProgressBar
@onready var _hp_label: Label = $HPLabel

var _health_component: HealthComponent


func _ready() -> void:
	_health_component = get_node_or_null(health_component_path) as HealthComponent
	if _health_component == null:
		push_error("ActorHealthBar requires a valid HealthComponent path.")
		return
	_health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(_health_component.current_health, _health_component.max_health)


func _on_health_changed(current_health: int, max_health: int) -> void:
	_name_label.text = display_name
	_progress_bar.max_value = max_health
	_progress_bar.value = current_health
	_hp_label.text = "%d/%d" % [current_health, max_health]
