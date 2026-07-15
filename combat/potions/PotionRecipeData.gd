class_name PotionRecipeData
extends Resource

# Responsibility: Describe and validate one exact three-layer potion recipe.

enum EffectType { HEAL, DAMAGE }

## The stable identifier used to distinguish this recipe.
@export var recipe_id: String = ""
## The player-facing name for this recipe.
@export var display_name: String = ""
## The number of red reagent layers required.
@export var red_count: int = 0
## The number of green reagent layers required.
@export var green_count: int = 0
## The number of blue reagent layers required.
@export var blue_count: int = 0
## The effect applied when this recipe is consumed.
@export var effect_type: EffectType = EffectType.HEAL
## The positive magnitude of the recipe effect.
@export var effect_amount: int = 0
## The display color of the prepared potion.
@export var mixed_color: Color = Color.WHITE


## Returns whether this recipe has exactly three layers and a positive effect.
func is_valid() -> bool:
	return red_count >= 0 and green_count >= 0 and blue_count >= 0 and _total_layers() == 3 and effect_amount > 0


## Returns whether layers contain this recipe's exact reagent counts in any order.
func matches_layers(layers: Array[StringName]) -> bool:
	if not is_valid() or layers.size() != _total_layers():
		return false
	var red_layers := 0
	var green_layers := 0
	var blue_layers := 0
	for reagent in layers:
		match reagent:
			PotionReagent.RED:
				red_layers += 1
			PotionReagent.GREEN:
				green_layers += 1
			PotionReagent.BLUE:
				blue_layers += 1
			_:
				return false
	return red_layers == red_count and green_layers == green_count and blue_layers == blue_count


func _total_layers() -> int:
	return red_count + green_count + blue_count
