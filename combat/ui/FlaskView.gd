class_name FlaskView
extends Control

@export var presentation_profile: BrewingPresentationProfileData = preload("res://combat/potions/brewing/BrewingPresentationProfile_Default.tres")

@onready var _glass_outline: Sprite2D = $GlassOutline
@onready var _mixed_liquid: Polygon2D = $MixedLiquid
@onready var _layers: Array[Polygon2D] = [$Layer1, $Layer2, $Layer3]
@onready var _success_window: Line2D = $SuccessWindow
@onready var _ideal_lower_mark: Line2D = $IdealLowerMark
@onready var _ideal_upper_mark: Line2D = $IdealUpperMark
@onready var _ideal_outline_glow: Sprite2D = $IdealOutlineGlow
@onready var _perfect_sparks = $PerfectSparks
@onready var _check_pulse: Line2D = $CheckPulse
@onready var _bad_turbulence: Line2D = $BadTurbulence

# Native mask rows [7, 28); all fill boundaries share this pixel grid.
const INNER_TOP := 7.0
const INNER_BOTTOM := 28.0
const NATIVE_HEIGHT := 32.0
const DISPLAY_SCALE := 5.0
const TEXTURE_TOP := 20.0
const IDEAL_GOLD := Color("ffd064")
const MARK_NEUTRAL := Color(0.76, 0.78, 0.72, 0.9)

var _rest_position := Vector2.ZERO
var _visual_time := 0.0
var _power := 0.0
var _blend := 0.0
var _heating := false
var _suspended := false
var _active_tween: Tween
var _check_feedback_tween: Tween
var _shown_layers: Array[StringName] = []
var _perfect_ready := false


func _ready() -> void:
	_rest_position = position
	visibility_changed.connect(_refresh_animation)
	reset_view()


func _process(delta: float) -> void:
	_visual_time += delta
	_update_liquid_motion()


## Shows reagent layers from bottom to top in insertion order.
func set_layers(layers: Array[StringName]) -> void:
	_stop_animation()
	if layers != _shown_layers:
		_blend = 0.0
	_shown_layers.assign(layers)
	_heating = false
	_power = 0.0
	_set_ideal_marks_visible(false)
	_set_perfect_ready(false)
	_draw_layers(layers, 0.0, Color.WHITE)
	_refresh_animation()


func show_mixing(layers: Array[StringName]) -> void:
	set_layers(layers)


## Blend survives pressure drops until the mixture is replaced or cleared.
func show_brewing(
	layers: Array[StringName], state: int, height: float, power: float,
	blend: float, profile: Resource = null, final_color: Color = Color.WHITE
) -> void:
	if layers != _shown_layers:
		_blend = 0.0
	_shown_layers.assign(layers)
	_blend = maxf(_blend, clampf(blend, 0.0, presentation_profile.blend_before_complete))
	_power = clampf(power, 0.0, 1.0)
	_heating = state == BrewingReaction.State.HEATING
	if state == BrewingReaction.State.COMPLETED:
		show_ready(final_color)
		return
	_draw_layers(layers, height, final_color)
	var brewing_profile := profile as BrewingProfileData
	if brewing_profile == null:
		brewing_profile = load("res://combat/potions/brewing/SmallFlaskBrewingProfile.tres") as BrewingProfileData
	_set_success_window(brewing_profile.perfect_min, brewing_profile.perfect_max)
	var can_release := state == BrewingReaction.State.HEATING and not layers.is_empty()
	_set_ideal_marks_visible(can_release)
	var ideal_active := can_release and brewing_profile.is_perfect_height(height)
	_success_window.visible = ideal_active
	var mark_color := IDEAL_GOLD if ideal_active else MARK_NEUTRAL
	_ideal_lower_mark.default_color = mark_color
	_ideal_upper_mark.default_color = mark_color
	_refresh_animation()


func _draw_layers(layers: Array[StringName], height: float, final_color: Color) -> void:
	_mixed_liquid.hide()
	_glass_outline.modulate = Color.WHITE
	var count := mini(layers.size(), _layers.size())
	var top_row := _height_to_row(height)
	for index in _layers.size():
		var layer := _layers[index]
		layer.visible = index < count
		if index >= count:
			continue
		layer.color = PotionReagent.get_color(layers[index]).lerp(final_color, _blend)
		var bottom := roundf(lerpf(INNER_BOTTOM, top_row, float(index) / count))
		var top := roundf(lerpf(INNER_BOTTOM, top_row, float(index + 1) / count))
		var liquid_material := layer.material as ShaderMaterial
		liquid_material.set_shader_parameter("band_top", top / NATIVE_HEIGHT)
		liquid_material.set_shader_parameter("band_bottom", bottom / NATIVE_HEIGHT)
	_update_liquid_motion()


func show_ready(color: Color, perfect_quality: bool = false) -> void:
	_stop_animation()
	_heating = false
	_power = 0.0
	_set_ideal_marks_visible(false)
	for layer in _layers:
		layer.hide()
	_mixed_liquid.color = color
	_mixed_liquid.show()
	var liquid_material := _mixed_liquid.material as ShaderMaterial
	liquid_material.set_shader_parameter("band_top", _height_to_row(0.0) / NATIVE_HEIGHT)
	liquid_material.set_shader_parameter("band_bottom", INNER_BOTTOM / NATIVE_HEIGHT)
	liquid_material.set_shader_parameter("bubble_power", 0.0)
	_set_perfect_ready(perfect_quality)
	_refresh_animation()


## Compatibility with existing prepared-potion callers.
func show_mixed(color: Color) -> void:
	show_ready(color)


func show_failure() -> void:
	_stop_animation()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position:x", _rest_position.x - 5.0, 0.05)
	_active_tween.tween_property(self, "position:x", _rest_position.x + 5.0, 0.08)
	_active_tween.tween_property(self, "position:x", _rest_position.x, 0.05)
	_active_tween.finished.connect(_on_shake_finished)
	_refresh_animation()


func _on_shake_finished() -> void:
	_active_tween = null
	position = _rest_position


## Gives immediate local feedback without changing the scored liquid height.
func show_check_feedback(score: int) -> void:
	if _check_feedback_tween != null:
		_check_feedback_tween.kill()
		_check_feedback_tween = null
	_hide_transient_ideal_outline()
	var result := clampi(score, -1, 1)
	if result > 0:
		_check_pulse.hide()
		_bad_turbulence.hide()
		_ideal_outline_glow.modulate = IDEAL_GOLD
		_ideal_outline_glow.show()
		_check_feedback_tween = create_tween()
		_check_feedback_tween.tween_property(
			_ideal_outline_glow,
			"modulate:a",
			0.0,
			presentation_profile.check_pulse_duration
		)
		_check_feedback_tween.tween_callback(_hide_transient_ideal_outline)
		return
	_check_pulse.default_color = (
		Color(0.72, 0.72, 0.72, 0.9) if result == 0
		else Color("ff2e50")
	)
	_check_pulse.width = 3.0
	_check_pulse.modulate = Color.WHITE
	_check_pulse.scale = Vector2.ONE
	_check_pulse.show()
	_bad_turbulence.position = Vector2.ZERO
	_bad_turbulence.visible = result < 0
	_bad_turbulence.modulate = Color.WHITE
	_check_feedback_tween = create_tween()
	_check_feedback_tween.set_parallel(true)
	_check_feedback_tween.tween_property(
		_check_pulse,
		"scale",
		Vector2.ONE * (1.12 if result > 0 else 1.05),
		presentation_profile.check_pulse_duration
	)
	_check_feedback_tween.tween_property(
		_check_pulse,
		"modulate:a",
		0.0,
		presentation_profile.check_pulse_duration
	)
	if result < 0:
		_check_feedback_tween.tween_property(
			_bad_turbulence,
			"position:x",
			4.0,
			presentation_profile.check_pulse_duration * 0.5
		)
		_check_feedback_tween.chain().tween_callback(_bad_turbulence.hide)
	_check_feedback_tween.chain().tween_callback(_check_pulse.hide)


func reset_view() -> void:
	_stop_animation()
	_shown_layers.clear()
	_blend = 0.0
	_power = 0.0
	_visual_time = 0.0
	_heating = false
	_glass_outline.modulate = Color.WHITE
	_set_perfect_ready(false)
	_mixed_liquid.hide()
	_set_ideal_marks_visible(false)
	_check_pulse.hide()
	_bad_turbulence.hide()
	if _check_feedback_tween != null:
		_check_feedback_tween.kill()
		_check_feedback_tween = null
	for layer in _layers:
		layer.hide()
		layer.color = Color.WHITE
	_update_liquid_motion()
	_refresh_animation()


func set_animation_suspended(suspended: bool) -> void:
	_suspended = suspended
	_perfect_sparks.set_suspended(suspended)
	_refresh_animation()


func is_ideal_cue_active() -> bool:
	return _success_window.visible


func _refresh_animation() -> void:
	var active := is_visible_in_tree() and not _suspended
	set_process(active and _heating and _power > 0.0)
	if _active_tween != null and _active_tween.is_valid():
		if active and not _active_tween.is_running():
			_active_tween.play()
		elif not active and _active_tween.is_running():
			_active_tween.pause()
	_perfect_sparks.set_suspended(not active)


func _stop_animation() -> void:
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null
	position = _rest_position


func _height_to_row(height: float) -> float:
	var fill := lerpf(presentation_profile.base_fill, presentation_profile.max_fill, clampf(height, 0.0, 1.0))
	return roundf(lerpf(INNER_BOTTOM, INNER_TOP, fill))


func _progress_to_y(height: float) -> float:
	return TEXTURE_TOP + _height_to_row(height) * DISPLAY_SCALE


func _set_success_window(min_height: float, max_height: float) -> void:
	_success_window.width = presentation_profile.marker_width
	_success_window.default_color = IDEAL_GOLD
	_success_window.points = PackedVector2Array([
		Vector2(109.0, _progress_to_y(max_height)),
		Vector2(109.0, _progress_to_y(min_height)),
	])
	_ideal_upper_mark.width = presentation_profile.marker_width
	_ideal_upper_mark.points = PackedVector2Array([
		Vector2(100.0, _progress_to_y(max_height)),
		Vector2(112.0, _progress_to_y(max_height)),
	])
	_ideal_lower_mark.width = presentation_profile.marker_width
	_ideal_lower_mark.points = PackedVector2Array([
		Vector2(100.0, _progress_to_y(min_height)),
		Vector2(112.0, _progress_to_y(min_height)),
	])


func _set_ideal_marks_visible(show_marks: bool) -> void:
	_ideal_lower_mark.visible = show_marks
	_ideal_upper_mark.visible = show_marks
	if not show_marks:
		_success_window.hide()


func _set_perfect_ready(active: bool) -> void:
	_perfect_ready = active
	if _check_feedback_tween != null:
		_check_feedback_tween.kill()
		_check_feedback_tween = null
	_ideal_outline_glow.modulate = IDEAL_GOLD
	_ideal_outline_glow.visible = active
	_perfect_sparks.set_emitting(active)


func _hide_transient_ideal_outline() -> void:
	if not _perfect_ready:
		_ideal_outline_glow.hide()


func _update_liquid_motion() -> void:
	for layer in _layers:
		var liquid_material := layer.material as ShaderMaterial
		# Fixed band boundaries keep the bracket aligned with the actual surface.
		liquid_material.set_shader_parameter("surface_step", 0.0)
		liquid_material.set_shader_parameter("bottom_step", 0.0)
		liquid_material.set_shader_parameter("visual_time", _visual_time)
		liquid_material.set_shader_parameter("bubble_speed", presentation_profile.bubble_speed)
		liquid_material.set_shader_parameter("bubble_power", _power if _heating else 0.0)
