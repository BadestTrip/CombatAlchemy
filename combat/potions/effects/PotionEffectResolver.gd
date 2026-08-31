class_name PotionEffectResolver
extends RefCounted

# Responsibility: Apply every configured recipe effect to one impact context.


## Applies all supported effects and returns how many reached a matching capability.
static func apply_recipe(recipe: PotionRecipeData, context: PotionImpactContext) -> int:
	if recipe == null or not recipe.is_valid() or context == null or not context.is_valid():
		return 0
	var applied_count := 0
	for effect in recipe.effects:
		if effect != null and effect.apply(context) == PotionEffectData.ApplyResult.APPLIED:
			applied_count += 1
	return applied_count
