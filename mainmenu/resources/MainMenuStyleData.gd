# MainMenuStyleData.gd
# High-level visual tuning for the main menu without editing scene internals.
extends Resource
class_name MainMenuStyleData


@export var background_texture: Texture2D
@export_range(0.0, 1.0, 0.01) var rune_circle_opacity: float = 0.52
@export var rune_circle_rotation_speed: float = 3.0
@export var shader_enabled: bool = false
@export var shader_effect_strength: float = 1.0
@export var vignette_strength: float = 0.38
@export var pulse_speed: float = 4.5
