class_name AlchemicalBurner
extends Node2D

@export var presentation_profile: BrewingPresentationProfileData = preload("res://combat/potions/brewing/BrewingPresentationProfile_Default.tres")
@export_range(0.0, 1.0, 0.01) var heat_power := 0.5
@export var active := false

@onready var _flame: AnimatedSprite2D = $Flame
@onready var _high_heat_glow: Polygon2D = $HighHeatGlow
@onready var _gold_sparks = $GoldSparks
var _suspended := false


func _ready() -> void:
	visibility_changed.connect(_refresh_animation)
	set_heat_power(heat_power)


func set_heat_power(power: float) -> void:
	heat_power = clampf(power, 0.0, 1.0)
	if _flame == null:
		return
	var height := lerpf(presentation_profile.flame_min_height, presentation_profile.flame_max_height, heat_power)
	var high_heat := heat_power > presentation_profile.high_heat_threshold
	var high_multiplier := presentation_profile.high_heat_scale_multiplier if high_heat else 1.0
	_flame.scale = Vector2(3.0 * high_multiplier, 3.0 * height * high_multiplier)
	_flame.modulate = Color.WHITE
	_high_heat_glow.color = Color(
		presentation_profile.high_heat_color,
		presentation_profile.high_heat_glow_alpha
	)
	_high_heat_glow.visible = active and high_heat
	var fps := lerpf(presentation_profile.flame_min_fps, presentation_profile.flame_max_fps, heat_power)
	_flame.speed_scale = fps / _flame.sprite_frames.get_animation_speed(&"burn")
	_refresh_animation()


func set_active(value: bool) -> void:
	active = value
	if is_node_ready():
		_refresh_animation()


func is_active() -> bool:
	return active


func set_animation_suspended(suspended: bool) -> void:
	_suspended = suspended
	if is_node_ready():
		_refresh_animation()


func _refresh_animation() -> void:
	_flame.visible = active and heat_power > 0.0
	var high_heat_active := (
		_flame.visible
		and heat_power > presentation_profile.high_heat_threshold
	)
	_high_heat_glow.visible = high_heat_active
	_gold_sparks.set_suspended(_suspended or not is_visible_in_tree())
	_gold_sparks.set_emitting(high_heat_active)
	if _flame.visible and is_visible_in_tree() and not _suspended:
		_flame.play(&"burn")
	else:
		_flame.pause()
