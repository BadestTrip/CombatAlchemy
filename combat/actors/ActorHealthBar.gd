class_name ActorHealthBar
extends Control

# Responsibility: Display one actor's world-space health and active status icons.

## The name shown above the health progress bar.
@export var display_name: String = "Actor"
## Path to the HealthComponent whose state this bar displays.
@export var health_component_path: NodePath
## Path to the StatusEffectComponent whose active states this bar presents.
@export var status_component_path: NodePath = ^"../StatusEffects"

@onready var _name_label: Label = $NameLabel
@onready var _progress_bar: ProgressBar = $ProgressBar
@onready var _hp_label: Label = $HPLabel
@onready var _status_bar: Node = $StatusBar

var _health_component: HealthComponent
var _status_component: Node


func _ready() -> void:
	_health_component = get_node_or_null(health_component_path) as HealthComponent
	if _health_component == null:
		push_error("ActorHealthBar requires a valid HealthComponent path.")
		return
	_health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(_health_component.current_health, _health_component.max_health)
	_status_component = get_node_or_null(status_component_path)
	if _status_component != null and _status_component.has_signal(&"statuses_changed"):
		_status_component.connect(&"statuses_changed", _on_statuses_changed)
		_on_statuses_changed(_status_component.call(&"get_active_statuses") as Array[Dictionary])


func _on_statuses_changed(active_statuses: Array[Dictionary]) -> void:
	if _status_bar != null and _status_bar.has_method(&"set_statuses"):
		_status_bar.call(&"set_statuses", active_statuses)


func _on_health_changed(current_health: int, max_health: int) -> void:
	_name_label.text = display_name
	_progress_bar.max_value = max_health
	_progress_bar.value = current_health
	_hp_label.text = "%d/%d" % [current_health, max_health]
