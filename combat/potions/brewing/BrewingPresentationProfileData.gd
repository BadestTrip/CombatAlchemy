class_name BrewingPresentationProfileData
extends Resource

## Input and visual tuning only. Scoring and reaction timing belong to BrewingProfileData.
@export_range(0.0, 1.0, 0.01) var default_heat_power := 0.5
@export_range(0.01, 1.0, 0.01) var heat_step := 0.05
@export_range(0.05, 2.0, 0.01) var repeat_delay := 0.3
@export_range(0.02, 1.0, 0.01) var repeat_interval := 0.1
@export_range(1.0, 30.0, 1.0) var flame_min_fps := 4.0
@export_range(1.0, 30.0, 1.0) var flame_max_fps := 10.0
@export_range(0.1, 1.0, 0.05) var flame_min_height := 0.35
@export_range(0.1, 2.0, 0.05) var flame_max_height := 1.0
@export_range(0.0, 30.0, 0.5) var bubble_speed := 12.0
@export_range(0.1, 2.0, 0.05) var feedback_duration := 0.6
@export_range(0.0, 1.0, 0.01) var base_fill := 0.30
@export_range(0.0, 1.0, 0.01) var max_fill := 0.92
@export_range(0.0, 0.99, 0.01) var blend_before_complete := 0.95
@export_range(1.0, 5.0, 1.0) var marker_width := 3.0
@export_range(0.5, 1.0, 0.01) var high_heat_threshold := 0.9
@export_range(1.0, 2.0, 0.05) var high_heat_scale_multiplier := 1.35
@export var high_heat_color := Color("ffd064")
@export_range(0.0, 1.0, 0.05) var high_heat_glow_alpha := 0.42
@export_range(0.05, 1.0, 0.01) var check_pulse_duration := 0.28
@export_range(0.05, 1.0, 0.01) var perfect_brew_pulse_duration := 0.55

func is_valid() -> bool:
	return (heat_step > 0.0 and repeat_delay > 0.0 and repeat_interval > 0.0
		and default_heat_power >= 0.0 and default_heat_power <= 1.0
		and base_fill >= 0.0 and max_fill <= 1.0 and base_fill < max_fill
		and flame_min_fps > 0.0 and flame_max_fps >= flame_min_fps
		and flame_min_height > 0.0 and flame_max_height >= flame_min_height
		and blend_before_complete >= 0.0 and blend_before_complete < 1.0
		and high_heat_threshold >= 0.0 and high_heat_threshold <= 1.0
		and high_heat_scale_multiplier >= 1.0
		and high_heat_glow_alpha >= 0.0 and high_heat_glow_alpha <= 1.0
		and check_pulse_duration > 0.0 and perfect_brew_pulse_duration > 0.0)
