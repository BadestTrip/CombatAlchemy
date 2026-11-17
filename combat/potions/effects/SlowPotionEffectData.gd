class_name SlowPotionEffectData
extends PotionEffectData

# Responsibility: Apply a timed movement slow to subjects with StatusEffectComponent.

const STATUS_EFFECT_COMPONENT_SCRIPT: Script = preload("res://combat/actors/StatusEffectComponent.gd")

## Fraction of speed removed by one successful application.
@export_range(0.01, 1.0, 0.01) var reduction := 0.45
## Seconds across which the shared slow reduction decays to zero.
@export_range(0.1, 60.0, 0.1) var duration := 5.0


func is_valid() -> bool:
	return reduction > 0.0 and duration > 0.0


func apply(context: PotionImpactContext) -> ApplyResult:
	if not is_valid() or context == null or not context.is_valid():
		return ApplyResult.FAILED
	var statuses := context.find_component(STATUS_EFFECT_COMPONENT_SCRIPT)
	if statuses == null:
		return ApplyResult.UNSUPPORTED
	return ApplyResult.APPLIED if statuses.call(&"apply_slow", reduction, duration) else ApplyResult.FAILED
