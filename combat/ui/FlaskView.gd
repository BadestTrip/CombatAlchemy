class_name FlaskView
extends Control

# Responsibility: Render scene-authored ingredient, reaction, recovery, and prepared-potion geometry.

@onready var _glass_outline: Sprite2D = $GlassOutline
@onready var _mixed_liquid: Polygon2D = $MixedLiquid
@onready var _layers: Array[Polygon2D] = [$Layer1, $Layer2, $Layer3]
@onready var _success_window: Line2D = $SuccessWindow
@onready var _current_marker: Polygon2D = $CurrentProgressMarker
@onready var _predicted_marker: Polygon2D = $PredictedSettleMarker
@onready var _grains: Node2D = $Grains
@onready var _foam: Node2D = $Foam

var _rest_position := Vector2.ZERO
var _active_tween: Tween
var _animation_serial := 0
var _layer_rest_positions: Array[Vector2] = []
var _grain_rest_positions: Array[Vector2] = []
var _visual_time := 0.0
var _display_energy := 0.0
var _brewing_state := BrewingReaction.State.IDLE

const LIQUID_TOP_Y := 55.0
const LIQUID_BOTTOM_Y := 155.0


func _ready() -> void:
	_rest_position = position
	for layer in _layers:
		_layer_rest_positions.append(layer.position)
	for grain in _grains.get_children():
		if grain is Node2D:
			_grain_rest_positions.append((grain as Node2D).position)
	reset_view()


func _process(delta: float) -> void:
	_visual_time += delta
	_update_liquid_motion()
	_update_grain_motion()


## Shows reagent layers from bottom to top in their insertion order.
func set_layers(layers: Array[StringName]) -> void:
	_stop_animation()
	position = _rest_position
	_glass_outline.modulate = Color.WHITE
	_mixed_liquid.visible = false
	_hide_brewing_feedback()
	for index in _layers.size():
		var layer := _layers[index]
		layer.visible = index < layers.size()
		layer.color = PotionReagent.get_color(layers[index]) if index < layers.size() else Color.WHITE
	_reset_moving_geometry()


## Shows reaction motion and both current and predicted settled progress.
func show_brewing(
	layers: Array[StringName],
	state: BrewingReaction.State,
	progress: float,
	energy: float,
	predicted_settled_progress: float,
	profile: BrewingProfileData = null
) -> void:
	_stop_animation()
	position = _rest_position
	_glass_outline.modulate = Color.WHITE
	_mixed_liquid.visible = false
	for index in _layers.size():
		var layer := _layers[index]
		layer.visible = index < layers.size()
		layer.color = PotionReagent.get_color(layers[index]) if index < layers.size() else Color.WHITE
	_brewing_state = state
	_display_energy = clampf(energy, 0.0, 1.0)
	var success_min := profile.success_min_progress if profile != null else 0.7
	var success_max := profile.success_max_progress if profile != null else 0.9
	_set_success_window(success_min, success_max)
	_success_window.visible = true
	_current_marker.position.y = _progress_to_y(progress)
	_predicted_marker.position.y = _progress_to_y(predicted_settled_progress)
	_current_marker.visible = true
	_predicted_marker.visible = true
	_grains.visible = state in [BrewingReaction.State.AGITATING, BrewingReaction.State.SETTLING]
	_foam.visible = state == BrewingReaction.State.COOLDOWN
	set_process(_display_energy > 0.0 or _foam.visible)
	if not is_processing():
		_reset_moving_geometry()


## Animates the visible layers into a single liquid of the supplied color.
func show_mixed(color: Color) -> void:
	_stop_animation()
	position = _rest_position
	_hide_brewing_feedback()
	_reset_moving_geometry()
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


## Plays a brief failed-mix shake without changing the displayed potion state.
func show_failure() -> void:
	_stop_animation()
	position = _rest_position
	_glass_outline.modulate = Color.WHITE
	_hide_brewing_feedback()
	var tween := create_tween()
	_active_tween = tween
	tween.tween_callback(func() -> void: position.x = _rest_position.x - 5.0)
	tween.tween_interval(0.05)
	tween.tween_callback(func() -> void: position.x = _rest_position.x + 5.0)
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void: position.x = _rest_position.x)


## Restores the empty neutral flask state.
func reset_view() -> void:
	_stop_animation()
	position = _rest_position
	_glass_outline.modulate = Color.WHITE
	_mixed_liquid.visible = false
	_mixed_liquid.scale = Vector2.ONE
	_hide_brewing_feedback()
	for layer in _layers:
		layer.visible = false
		layer.color = Color.WHITE
	_reset_moving_geometry()


func _stop_animation() -> void:
	_animation_serial += 1
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null


func _hide_brewing_feedback() -> void:
	_success_window.visible = false
	_current_marker.visible = false
	_predicted_marker.visible = false
	_grains.visible = false
	_foam.visible = false
	_display_energy = 0.0
	_brewing_state = BrewingReaction.State.IDLE
	set_process(false)


func _set_success_window(min_progress: float, max_progress: float) -> void:
	var top_y := _progress_to_y(max_progress)
	var bottom_y := _progress_to_y(min_progress)
	_success_window.points = PackedVector2Array([
		Vector2(138.0, top_y),
		Vector2(130.0, top_y),
		Vector2(130.0, bottom_y),
		Vector2(138.0, bottom_y),
	])


func _progress_to_y(progress: float) -> float:
	return snappedf(lerpf(LIQUID_BOTTOM_Y, LIQUID_TOP_Y, clampf(progress, 0.0, 1.0)), 5.0)


func _update_liquid_motion() -> void:
	for index in _layers.size():
		var layer := _layers[index]
		var material := layer.material as ShaderMaterial
		if material != null:
			var step := roundf(sin(_visual_time * 15.0 + float(index)) * _display_energy)
			material.set_shader_parameter("surface_step", step)
			var bottom_step := roundf(sin(_visual_time * 15.0 + float(index - 1)) * _display_energy) if index > 0 else 0.0
			material.set_shader_parameter("bottom_step", bottom_step)


func _update_grain_motion() -> void:
	var grains := _grains.get_children()
	for index in mini(grains.size(), _grain_rest_positions.size()):
		var grain := grains[index] as Node2D
		if grain == null:
			continue
		var phase := _visual_time * (8.0 + float(index)) + float(index)
		grain.position = _grain_rest_positions[index] + Vector2(
			snappedf(sin(phase) * 5.0 * _display_energy, 5.0),
			snappedf(-cos(phase * 0.65) * 5.0 * _display_energy, 5.0)
		)
	if _foam.visible:
		_foam.position.y = snappedf(sin(_visual_time * 12.0) * 5.0, 5.0)


func _reset_moving_geometry() -> void:
	for index in _layers.size():
		if index < _layer_rest_positions.size():
			_layers[index].position = _layer_rest_positions[index]
			_layers[index].rotation = 0.0
			(_layers[index].material as ShaderMaterial).set_shader_parameter("surface_step", 0.0)
			(_layers[index].material as ShaderMaterial).set_shader_parameter("bottom_step", 0.0)
	var grains := _grains.get_children()
	for index in mini(grains.size(), _grain_rest_positions.size()):
		var grain := grains[index] as Node2D
		if grain != null:
			grain.position = _grain_rest_positions[index]
	_foam.position = Vector2.ZERO
