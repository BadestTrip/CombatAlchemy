class_name GoldSparkEmitter
extends Node2D

# Responsibility: Present continuous low-count gold pixel sparks from scene-authored particles.

@export var profile: Resource = preload("res://vfx/gold_sparks/PerfectPotionGoldSparkProfile.tres")
@export var emitting := false

@onready var _sparks: GPUParticles2D = $Sparks

var _suspended := false


func _ready() -> void:
	visibility_changed.connect(_refresh_emission)
	_apply_profile()
	_refresh_emission()


func set_emitting(active: bool) -> void:
	emitting = active
	if is_node_ready():
		_refresh_emission()


func is_emitting() -> bool:
	return _sparks != null and _sparks.emitting


func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	if is_node_ready():
		_refresh_emission()


func _apply_profile() -> void:
	if profile == null or not profile.has_method(&"is_valid") or not profile.call(&"is_valid"):
		push_error("GoldSparkEmitter requires a valid GoldSparkProfileData resource.")
		_sparks.emitting = false
		return
	var max_visible := int(profile.get("max_visible_particles"))
	var emission_rate := float(profile.get("emission_rate"))
	_sparks.amount = max_visible
	# Continuous particles distribute `amount` emissions over one lifetime.
	_sparks.lifetime = float(max_visible) / emission_rate
	var process := _sparks.process_material as ParticleProcessMaterial
	if process != null:
		process.initial_velocity_min = float(profile.get("speed_min"))
		process.initial_velocity_max = float(profile.get("speed_max"))
		process.gravity = Vector3(0.0, float(profile.get("gravity_y")), 0.0)
	var shader_material := _sparks.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(&"crystal_color", profile.get("spark_color") as Color)


func _refresh_emission() -> void:
	_sparks.emitting = emitting and not _suspended and is_visible_in_tree()
