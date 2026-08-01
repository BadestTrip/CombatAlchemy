class_name FlaskView
extends Control

# Responsibility: Render potion layers, a completed mixture, and a failed mix animation.

@onready var _glass_outline: Line2D = $GlassOutline
@onready var _mixed_liquid: Polygon2D = $MixedLiquid
@onready var _layers: Array[Polygon2D] = [$Layer1, $Layer2, $Layer3]

var _rest_position := Vector2.ZERO
var _active_tween: Tween
var _animation_serial := 0


func _ready() -> void:
	_rest_position = position
	reset_view()


## Shows reagent layers from bottom to top in their insertion order.
func set_layers(layers: Array[StringName]) -> void:
	_stop_animation()
	position = _rest_position
	_glass_outline.modulate = Color.WHITE
	_mixed_liquid.visible = false
	for index in _layers.size():
		var layer := _layers[index]
		layer.visible = index < layers.size()
		layer.color = PotionReagent.get_color(layers[index]) if index < layers.size() else Color.WHITE


## Animates the visible layers into a single liquid of the supplied color.
func show_mixed(color: Color) -> void:
	_stop_animation()
	var serial := _animation_serial
	_mixed_liquid.visible = false
	var visible_layers: Array[Polygon2D] = []
	for layer in _layers:
		if layer.visible:
			visible_layers.append(layer)
	if not visible_layers.is_empty():
		var tween := create_tween()
		_active_tween = tween
		for layer in visible_layers:
			tween.parallel().tween_property(layer, "color", color, 0.18)
		await tween.finished
		if serial != _animation_serial:
			return
	for layer in _layers:
		layer.visible = false
	_mixed_liquid.color = color
	_mixed_liquid.visible = true
	_mixed_liquid.scale = Vector2.ONE
	var pulse := create_tween()
	_active_tween = pulse
	pulse.tween_property(_mixed_liquid, "scale", Vector2(1.04, 1.04), 0.08)
	pulse.tween_property(_mixed_liquid, "scale", Vector2.ONE, 0.12)


## Plays a brief failed-mix shake without changing the displayed potion state.
func show_failure() -> void:
	_stop_animation()
	position = _rest_position
	_glass_outline.modulate = Color.WHITE
	var tween := create_tween()
	_active_tween = tween
	tween.tween_property(self, "position:x", _rest_position.x - 8.0, 0.05)
	tween.tween_property(self, "position:x", _rest_position.x + 8.0, 0.08)
	tween.tween_property(self, "position:x", _rest_position.x, 0.05)
	tween.parallel().tween_property(_glass_outline, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tween.tween_property(_glass_outline, "modulate", Color.WHITE, 0.12)


## Restores the empty neutral flask state.
func reset_view() -> void:
	_stop_animation()
	position = _rest_position
	_glass_outline.modulate = Color.WHITE
	_mixed_liquid.visible = false
	_mixed_liquid.scale = Vector2.ONE
	for layer in _layers:
		layer.visible = false
		layer.color = Color.WHITE


func _stop_animation() -> void:
	_animation_serial += 1
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null
