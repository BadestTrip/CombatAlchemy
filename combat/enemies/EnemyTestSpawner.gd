class_name EnemyTestSpawner
extends Node

# Responsibility: Spawn disposable test enemies from explicit markers during the combat sandbox.

@export var player_path: NodePath
@export var enemies_parent_path: NodePath
@export var projectiles_parent_path: NodePath
@export var skirmisher_spawn_path: NodePath
@export var pursuer_spawn_path: NodePath
@export var skirmisher_scene: PackedScene
@export var pursuer_scene: PackedScene
@export_range(1.0, 500.0, 1.0) var spawn_clearance: float = 70.0

@onready var _player := get_node_or_null(player_path) as Node2D
@onready var _enemies_parent := get_node_or_null(enemies_parent_path) as Node2D
@onready var _projectiles_parent := get_node_or_null(projectiles_parent_path) as Node2D
@onready var _skirmisher_spawn := get_node_or_null(skirmisher_spawn_path) as Node2D
@onready var _pursuer_spawn := get_node_or_null(pursuer_spawn_path) as Node2D

var _enabled := false


func _ready() -> void:
	_enabled = _validate_dependencies()


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or get_tree().paused:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(&"spawn_skirmisher"):
		_try_spawn(skirmisher_scene, _skirmisher_spawn)
	elif event.is_action_pressed(&"spawn_pursuer"):
		_try_spawn(pursuer_scene, _pursuer_spawn)
	else:
		return
	get_viewport().set_input_as_handled()


func _validate_dependencies() -> bool:
	if (
		_player == null or _enemies_parent == null or _projectiles_parent == null
		or _skirmisher_spawn == null or _pursuer_spawn == null
		or skirmisher_scene == null or pursuer_scene == null
	):
		push_error("EnemyTestSpawner requires Player, enemy/projectile parents, two spawn markers, and two scenes.")
		return false
	return true


func _try_spawn(scene: PackedScene, marker: Node2D) -> void:
	if scene == null or marker == null or _spawn_is_occupied(marker.global_position):
		_flash_marker(marker)
		return
	var enemy := scene.instantiate() as EnemyActor
	if enemy == null:
		push_error("EnemyTestSpawner can only spawn EnemyActor scenes.")
		return
	enemy.global_position = marker.global_position
	enemy.projectiles_parent = _projectiles_parent
	_enemies_parent.add_child(enemy)
	enemy.set_target(_player)


func _spawn_is_occupied(spawn_position: Vector2) -> bool:
	for child in _enemies_parent.get_children():
		var enemy := child as Node2D
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if enemy.global_position.distance_to(spawn_position) < spawn_clearance:
				return true
	return false


func _flash_marker(marker: Node2D) -> void:
	var ring := marker.get_node_or_null(^"MarkerRing") as Line2D
	if ring == null:
		return
	var tween := create_tween()
	ring.default_color = Color(1.0, 0.3, 0.3, 1.0)
	tween.tween_property(ring, "default_color", Color(1.0, 0.78, 0.35, 0.85), 0.14)
