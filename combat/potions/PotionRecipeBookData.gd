class_name PotionRecipeBookData
extends Resource

# Responsibility: Provide order-independent lookup for valid potion recipes.

## The recipes available to this potion mixer.
@export var recipes: Array[PotionRecipeData] = []


## Returns the valid recipe that exactly matches layers, or null when none matches.
func find_match(layers: Array[StringName]) -> PotionRecipeData:
	for recipe in recipes:
		if recipe != null and recipe.matches_layers(layers):
			return recipe
	return null
