class_name PotionEffectData
extends Resource

# Responsibility: Define the stateless contract for one potion effect.

enum ApplyResult { APPLIED, UNSUPPORTED, FAILED }


## Returns whether this shared effect resource is configured for use.
func is_valid() -> bool:
	return false


## Attempts to apply this effect to the capabilities exposed by an impact context.
func apply(_context: PotionImpactContext) -> ApplyResult:
	return ApplyResult.FAILED
