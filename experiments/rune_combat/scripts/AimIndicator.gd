extends Node2D
class_name AimIndicator

@export var player_path: NodePath
@export var line_length: float = 180.0
@export var use_mouse_position: bool = false

@onready var player := get_node_or_null(player_path) as PlayerCombatController


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return

	var origin := to_local(player.get_cast_origin())
	var end := to_local(player.get_aim_position()) if use_mouse_position else origin + player.get_aim_direction() * line_length
	var aim_color := Color(0.8, 0.9, 1.0, 0.55)
	var reticle_color := Color(0.8, 0.9, 1.0, 0.75)

	draw_line(origin, end, aim_color, 2.0)
	draw_arc(end, 8.0, 0.0, TAU, 32, reticle_color, 2.0)
	draw_line(end + Vector2(-12.0, 0.0), end + Vector2(-4.0, 0.0), reticle_color, 1.5)
	draw_line(end + Vector2(4.0, 0.0), end + Vector2(12.0, 0.0), reticle_color, 1.5)
	draw_line(end + Vector2(0.0, -12.0), end + Vector2(0.0, -4.0), reticle_color, 1.5)
	draw_line(end + Vector2(0.0, 4.0), end + Vector2(0.0, 12.0), reticle_color, 1.5)
