extends Resource
class_name ChantEffectTemplateData

@export var template_id: String = "default"
@export var display_name: String = "Default Chant Effect"
@export_enum("auto", "projectile", "shield", "fizzle") var effect_mode: String = "auto"

@export_group("Motion")
@export var speed_multiplier: float = 1.0
@export var lifetime_multiplier: float = 1.0
@export var acceleration: float = 0.0
@export var start_offset: float = 0.0
@export var fizzle_speed_multiplier: float = 0.18
@export var hit_radius: float = 26.0

@export_group("Shape")
@export var core_radius_multiplier: float = 1.0
@export var glow_radius_multiplier: float = 0.45
@export var ring_start_multiplier: float = 2.2
@export var ring_end_multiplier: float = 5.2
@export var line_width_multiplier: float = 0.75
@export var tail_length_multiplier: float = 3.4

@export_group("Color")
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var glow_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var use_result_color: bool = true
@export var alpha_multiplier: float = 1.0
@export var fade_power: float = 1.0
@export var trail_alpha_multiplier: float = 0.45
@export var shield_alpha_multiplier: float = 0.45

@export_group("Animation")
@export var pulse_speed: float = 18.0
@export var pulse_amount: float = 0.08
@export var spin_speed: float = 0.0
@export var wobble_amount: float = 0.0
@export var wobble_speed: float = 8.0

@export_group("Sparks")
@export var spark_count: int = 4
@export var spark_spread_degrees: float = 90.0
@export var spark_length_multiplier: float = 1.0
@export var spark_fade_multiplier: float = 1.0

@export_group("Layers")
@export var show_core: bool = true
@export var show_trail: bool = true
@export var show_ring: bool = true
@export var show_burst: bool = true
@export var show_shield_aura: bool = true
