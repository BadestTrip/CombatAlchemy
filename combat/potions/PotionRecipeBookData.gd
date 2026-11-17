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

## Resolves one stable saved recipe ID, rejecting missing and ambiguous IDs.
func find_by_id(recipe_id: StringName) -> PotionRecipeData:
	var matched: PotionRecipeData
	for recipe in recipes:
		if recipe != null and recipe.recipe_id == recipe_id:
			if matched != null:
				push_error("PotionRecipeBookData has duplicate recipe ID %s." % recipe_id)
				return null
			matched = recipe
	return matched
