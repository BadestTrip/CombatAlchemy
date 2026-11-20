class_name BrewingProfileData
extends Resource

# Responsibility: Store boiling speed, scoring windows and pressure-reset timing.

## Height gained per second at full heat power.
@export_range(0.01, 5.0, 0.01) var rise_rate := 0.75
## Inclusive perfect window scores +1; the surrounding normal window scores 0.
@export_range(0.0, 1.0, 0.01) var perfect_min := 0.65
@export_range(0.0, 1.0, 0.01) var perfect_max := 0.75
@export_range(0.0, 1.0, 0.01) var normal_min := 0.5
@export_range(0.0, 1.0, 0.01) var normal_max := 0.9
## Seconds to lower the boiling height after each check.
@export_range(0.0, 5.0, 0.01) var reset_duration := 0.22

const COMPARISON_EPSILON := 0.00001


func is_valid() -> bool:
	return (
		is_finite(rise_rate) and rise_rate > 0.0
		and is_finite(reset_duration) and reset_duration >= 0.0
		and is_finite(normal_min) and is_finite(normal_max)
		and is_finite(perfect_min) and is_finite(perfect_max)
		and normal_min >= 0.0
		and normal_min <= perfect_min
		and perfect_min <= perfect_max
		and perfect_max <= normal_max
		and normal_max <= 1.0
	)


## Returns the same -1/0/+1 result used by the reaction and its presentation.
func score_height(height: float) -> int:
	if not is_finite(height) or height >= 1.0:
		return -1
	if _in_window(height, perfect_min, perfect_max):
		return 1
	if _in_window(height, normal_min, normal_max):
		return 0
	return -1


func is_perfect_height(height: float) -> bool:
	return score_height(height) == 1


func _in_window(value: float, lower: float, upper: float) -> bool:
	return value >= lower - COMPARISON_EPSILON and value <= upper + COMPARISON_EPSILON
