extends Node
class_name TestCombatController


const FIRE_PROJECTILE_SCENE: PackedScene = preload("res://test/combat/spells/TestFireProjectile.tscn")
const FIREBALL_KEY := "flame|forward|flame"

@export var player_path: NodePath = NodePath("../../Player")
@export var rune_menu_path: NodePath = NodePath("../RuneMenu")
@export var dummy_path: NodePath = NodePath("../TestDummy")
@export var spawn_offset: Vector2 = Vector2(0.0, -40.0)

@onready var player: Node2D = get_node_or_null(player_path) as Node2D
@onready var rune_menu: RuneMenu = get_node_or_null(rune_menu_path) as RuneMenu
@onready var dummy: Node2D = get_node_or_null(dummy_path) as Node2D


func _ready() -> void:
	if rune_menu != null and not rune_menu.spell_cast_requested.is_connected(_on_spell_cast_requested):
		rune_menu.spell_cast_requested.connect(_on_spell_cast_requested)


func _on_spell_cast_requested(combination_key: String, _spell_name: String) -> void:
	if combination_key != FIREBALL_KEY:
		return

	_spawn_fire_projectile()


func _spawn_fire_projectile() -> void:
	var projectile := FIRE_PROJECTILE_SCENE.instantiate() as TestFireProjectile
	if projectile == null:
		return

	var spawn_position := _get_spawn_position()
	var target_position := _get_target_position(spawn_position)
	var direction := (target_position - spawn_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_position
	projectile.initialize(direction)


func _get_spawn_position() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return player.global_position + spawn_offset


func _get_target_position(fallback_position: Vector2) -> Vector2:
	if dummy == null:
		return fallback_position + Vector2.RIGHT
	return dummy.global_position + Vector2(0.0, -45.0)
