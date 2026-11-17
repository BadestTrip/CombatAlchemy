class_name ActorStatusIcon
extends Node2D

# Responsibility: Draw one reusable world-space status icon from a status snapshot.

var _color := Color.WHITE
var _remaining_ratio := 0.0


func _ready() -> void:
	visible = false
	queue_redraw()


## Displays one status snapshot, where remaining_ratio controls the draining ring.
func set_status(status: Dictionary) -> void:
	_color = status.get("color", Color.WHITE) as Color
	_remaining_ratio = clampf(status.get("remaining_ratio", 0.0) as float, 0.0, 1.0)
	visible = true
	$Fill.color = _color
	$Outline.default_color = _color.darkened(0.55)
	queue_redraw()


## Hides this fixed slot when no active status occupies it.
func clear_status() -> void:
	visible = false
	_remaining_ratio = 0.0
	queue_redraw()


func _draw() -> void:
	if not visible or _remaining_ratio <= 0.0:
		return
	draw_arc(Vector2.ZERO, 11.0, -PI * 0.5, -PI * 0.5 + TAU * _remaining_ratio, 24, Color.WHITE, 2.0, true)
