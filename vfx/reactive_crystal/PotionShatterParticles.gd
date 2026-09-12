class_name PotionShatterParticles
extends Node2D

# Responsibility: Play and retire one potion-glass shatter burst. This visual
# component does not resolve collisions or apply gameplay effects.

@export_range(0.0, 1.5, 0.05) var glow_strength: float = 1.0
@export_range(0.85, 2.0, 0.05) var cleanup_delay: float = 0.95

@onready var _grains: GPUParticles2D = get_node_or_null("Grains") as GPUParticles2D
@onready var _fragments: GPUParticles2D = get_node_or_null("Fragments") as GPUParticles2D
@onready var _cleanup_timer: Timer = get_node_or_null("CleanupTimer") as Timer


func _ready() -> void:
	if _grains == null or _fragments == null or _cleanup_timer == null:
		push_error("PotionShatterParticles is missing an authored particle group or cleanup timer.")
		set_process(false)
		return
	_cleanup_timer.timeout.connect(_on_cleanup_timer_timeout)


## Starts a one-shot burst at a world position using the final potion color.
func play_burst(
	world_position: Vector2,
	color: Color,
	incoming_direction: Vector2 = Vector2.ZERO
) -> void:
	global_position = world_position
	if _grains == null or _fragments == null or _cleanup_timer == null:
		return
	_apply_particle_color(_grains, color, 0.24)
	_apply_particle_color(_fragments, color, 0.36)
	_apply_incoming_direction(_grains, incoming_direction)
	_apply_incoming_direction(_fragments, incoming_direction)
	_grains.restart()
	_fragments.restart()
	_grains.emitting = true
	_fragments.emitting = true
	_cleanup_timer.start(cleanup_delay)


func _apply_particle_color(particles: GPUParticles2D, color: Color, core_size: float) -> void:
	var material := particles.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(&"crystal_color", color)
	material.set_shader_parameter(&"glow_strength", glow_strength)
	material.set_shader_parameter(&"core_size", core_size)


func _apply_incoming_direction(particles: GPUParticles2D, incoming_direction: Vector2) -> void:
	var process := particles.process_material as ParticleProcessMaterial
	if process == null:
		return
	var travel_direction := incoming_direction.normalized()
	if travel_direction.is_zero_approx():
		travel_direction = Vector2.UP
	process.direction = Vector3(travel_direction.x, travel_direction.y, 0.0)


func _on_cleanup_timer_timeout() -> void:
	queue_free()
