class_name HealthPotionEffectData
extends PotionEffectData

# Responsibility: Apply healing or damage when an impacted subject has HealthComponent.

enum Operation { HEAL, DAMAGE }

const HEALTH_COMPONENT_SCRIPT: Script = preload("res://combat/actors/HealthComponent.gd")

## Whether this effect restores or removes health.
@export var operation: Operation = Operation.HEAL
## Positive health magnitude requested from the subject.
@export_range(1, 9999, 1) var amount: int = 1


func is_valid() -> bool:
	return amount > 0


func apply(context: PotionImpactContext) -> ApplyResult:
	if not is_valid() or context == null or not context.is_valid():
		return ApplyResult.FAILED
	var health := context.find_component(HEALTH_COMPONENT_SCRIPT) as HealthComponent
	if health == null:
		return ApplyResult.UNSUPPORTED
	match operation:
		Operation.HEAL:
			health.heal(amount)
		Operation.DAMAGE:
			health.take_damage(amount)
		_:
			return ApplyResult.FAILED
	return ApplyResult.APPLIED
