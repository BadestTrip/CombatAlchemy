class_name GoldSparkProfileData
extends Resource

# Responsibility: Store reusable tuning for a continuous gold pixel-spark emitter.

@export_range(0.1, 30.0, 0.1) var emission_rate := 4.0
@export_range(1, 32, 1) var max_visible_particles := 3
@export_range(0.0, 200.0, 1.0) var speed_min := 18.0
@export_range(0.0, 200.0, 1.0) var speed_max := 42.0
@export_range(-200.0, 200.0, 1.0) var gravity_y := 24.0
@export var spark_color := Color("ffd064")


func is_valid() -> bool:
	return (
		is_finite(emission_rate) and emission_rate > 0.0
		and max_visible_particles > 0
		and is_finite(speed_min) and is_finite(speed_max)
		and speed_min >= 0.0 and speed_max >= speed_min
		and is_finite(gravity_y)
	)
