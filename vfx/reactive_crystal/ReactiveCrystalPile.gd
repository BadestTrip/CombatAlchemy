@tool
class_name ReactiveCrystalPile
extends Node2D

# Responsibility: Render and tune one settled reagent-crystal deposit. This
# component owns presentation only; it has no potion or gameplay behavior.

const DEFAULT_PALETTE: AlchemyPaletteData = preload("res://shared/alchemy/ChargedNeonPalette.tres")

## Shared semantic palette used when color_id is recognized.
@export var palette: AlchemyPaletteData = DEFAULT_PALETTE
## Palette identifier: red, green, blue, health, or damage.
@export var color_id: StringName = AlchemyPaletteData.RED:
	set(value):
		color_id = value
		_apply_palette_color()
## Runtime color used by the authored crystals and particles.
@export var crystal_color: Color = Color("ff2e50"):
	set(value):
		crystal_color = value
		_apply_visuals()
## Localized halo and reflection intensity.
@export_range(0.0, 1.5, 0.05) var glow_strength: float = 1.0:
	set(value):
		glow_strength = maxf(value, 0.0)
		_apply_visuals()
## Multiplier for the low-simmer mote drift.
@export_range(0.0, 2.0, 0.05) var motion_strength: float = 1.0:
	set(value):
		motion_strength = maxf(value, 0.0)
		_apply_particle_motion()
## Number of low-simmer motes. Table piles use four; shelf deposits use two.
@export_range(1, 8, 1) var mote_amount: int = 4:
	set(value):
		mote_amount = clampi(value, 1, 8)
		_apply_mote_amount()
## Stable per-instance offset used to stagger ambient particles.
@export var random_seed: int = 1:
	set(value):
		random_seed = value
		_apply_particle_stagger()


func _ready() -> void:
	_apply_palette_color()
	_apply_visuals()
	_apply_particle_motion()
	_apply_mote_amount()
	_apply_particle_stagger()


## Recolors the pile without changing its semantic palette identifier.
func set_crystal_color(color: Color) -> void:
	crystal_color = color


## Sets localized glow intensity. Negative values clamp to zero.
func set_glow_strength(strength: float) -> void:
	glow_strength = strength


## Starts or stops only the pile's ambient drifting motes.
func set_emitting(active: bool) -> void:
	var motes := get_node_or_null("DriftMotes") as GPUParticles2D
	if motes != null:
		motes.emitting = active


func _apply_palette_color() -> void:
	if palette != null:
		crystal_color = palette.get_color(color_id)


func _apply_visuals() -> void:
	var static_pile := get_node_or_null("StaticPile") as Node2D
	if static_pile != null:
		for child in static_pile.get_children():
			var polygon := child as Polygon2D
			if polygon == null:
				continue
			var lowercase_name := String(polygon.name).to_lower()
			if lowercase_name.contains("core"):
				polygon.color = crystal_color.lerp(Color.WHITE, 0.88)
			elif lowercase_name.contains("halo"):
				polygon.color = Color(crystal_color.darkened(0.7), 0.56 * glow_strength)
			else:
				polygon.color = Color(crystal_color, 0.92)
	var reflection := get_node_or_null("Reflection") as Polygon2D
	if reflection != null:
		reflection.color = Color(crystal_color.lerp(Color.WHITE, 0.25), 0.18 * glow_strength)
	var motes := get_node_or_null("DriftMotes") as GPUParticles2D
	if motes != null:
		var material := motes.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter(&"crystal_color", crystal_color)
			material.set_shader_parameter(&"glow_strength", glow_strength)


func _apply_particle_motion() -> void:
	var motes := get_node_or_null("DriftMotes") as GPUParticles2D
	if motes == null:
		return
	var process := motes.process_material as ParticleProcessMaterial
	if process == null:
		return
	process.initial_velocity_min = 5.0 * motion_strength
	process.initial_velocity_max = 10.0 * motion_strength
	process.gravity = Vector3(0.0, -2.0 * motion_strength, 0.0)


func _apply_mote_amount() -> void:
	var motes := get_node_or_null("DriftMotes") as GPUParticles2D
	if motes != null:
		motes.amount = mote_amount


func _apply_particle_stagger() -> void:
	var motes := get_node_or_null("DriftMotes") as GPUParticles2D
	if motes != null:
		motes.preprocess = fmod(absf(float(random_seed)) * 0.173, motes.lifetime)
