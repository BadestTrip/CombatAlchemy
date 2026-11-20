class_name PotionQualityProfileData
extends Resource

# Responsibility: Map brewing quality scores to editable potency multipliers.

@export_range(0.01, 10.0, 0.01, "or_greater") var minus_two_multiplier := 0.6
@export_range(0.01, 10.0, 0.01, "or_greater") var minus_one_multiplier := 0.8
@export_range(0.01, 10.0, 0.01, "or_greater") var neutral_multiplier := 1.0
@export_range(0.01, 10.0, 0.01, "or_greater") var plus_one_multiplier := 1.2
@export_range(0.01, 10.0, 0.01, "or_greater") var plus_two_multiplier := 1.4


func is_valid() -> bool:
	for multiplier in _multipliers():
		if not is_valid_quality(0, multiplier):
			return false
	return true


## Invalid scores or profiles resolve to neutral potency, never an invalid value.
func get_multiplier(score: int) -> float:
	if score < -2 or score > 2 or not is_valid():
		return 1.0
	return _multipliers()[score + 2]


## Validate untrusted save values before any conversion can hide corruption.
static func is_valid_quality(score: Variant, multiplier: Variant) -> bool:
	return (
		typeof(score) == TYPE_INT
		and score >= -2
		and score <= 2
		and typeof(multiplier) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(multiplier))
		and float(multiplier) > 0.0
	)


func _multipliers() -> Array[float]:
	return [minus_two_multiplier, minus_one_multiplier, neutral_multiplier, plus_one_multiplier, plus_two_multiplier]
