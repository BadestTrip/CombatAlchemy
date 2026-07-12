extends CharacterBody2D
class_name PlayerCombatController

@export var move_speed: float = 220.0
@export var rotate_visual_to_aim: bool = true
@export var visual_path: NodePath = NodePath("PlayerVisual")

@onready var visual_node := get_node_or_null(visual_path) as Node2D


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()


func _process(_delta: float) -> void:
	if rotate_visual_to_aim and visual_node != null:
		visual_node.rotation = get_aim_direction().angle()


func get_cast_origin() -> Vector2:
	return global_position


func get_aim_position() -> Vector2:
	return get_global_mouse_position()


func get_aim_direction() -> Vector2:
	var aim_direction := get_aim_position() - get_cast_origin()
	if aim_direction.length() <= 0.001:
		return Vector2.RIGHT
	return aim_direction.normalized()
