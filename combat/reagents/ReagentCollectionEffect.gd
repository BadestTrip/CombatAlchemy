class_name ReagentCollectionEffect
extends Node2D

# Cosmetic only: inventory is already durable before this effect begins.
func play(from: Vector2, to: Vector2, color: Color) -> void:
	global_position = from
	var travel := to - from
	var grains := get_children()
	for index in grains.size():
		var grain := grains[index] as Polygon2D
		if grain == null:
			continue
		grain.color = color
		var tween := create_tween()
		tween.set_parallel(false)
		tween.tween_interval(float(index) * 0.025)
		tween.tween_property(grain, "position", travel, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(grain, "modulate:a", 0.0, 0.08)
	get_tree().create_timer(0.55).timeout.connect(queue_free)
