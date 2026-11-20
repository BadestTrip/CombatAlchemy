class_name PotionInstance
extends RefCounted

# Responsibility: Own one valid prepared potion until it is consumed or discarded.

var _recipe: PotionRecipeData
var _created_layers: Array[StringName] = []
var _quality_score := 0
var _potency_multiplier := 1.0
var _consumed := false


static func create(
	recipe: PotionRecipeData,
	layers: Array[StringName],
	quality_score: int = 0,
	potency_multiplier: float = 1.0
) -> PotionInstance:
	if recipe == null or not recipe.is_valid() or not recipe.matches_layers(layers):
		return null
	if not PotionQualityProfileData.is_valid_quality(quality_score, potency_multiplier):
		return null
	var potion := PotionInstance.new()
	potion._recipe = recipe
	potion._created_layers.append_array(layers)
	potion._quality_score = quality_score
	potion._potency_multiplier = potency_multiplier
	return potion


func get_recipe() -> PotionRecipeData:
	return _recipe


func get_quality_score() -> int:
	return _quality_score


func get_potency_multiplier() -> float:
	return _potency_multiplier


func get_created_layers() -> Array[StringName]:
	var layers: Array[StringName] = []
	layers.append_array(_created_layers)
	return layers


func get_color() -> Color:
	return _recipe.mixed_color if _recipe != null else Color.WHITE


func is_valid() -> bool:
	return (
		_recipe != null
		and _recipe.is_valid()
		and _created_layers.size() == 3
		and _recipe.matches_layers(_created_layers)
		and PotionQualityProfileData.is_valid_quality(_quality_score, _potency_multiplier)
	)


func is_consumed() -> bool:
	return _consumed


func apply(context: PotionImpactContext) -> int:
	if _consumed or not is_valid() or context == null or not context.is_valid():
		return 0
	_consumed = true
	context.potency_multiplier = _potency_multiplier
	return PotionEffectResolver.apply_recipe(_recipe, context)


func discard() -> bool:
	if _consumed:
		return false
	_consumed = true
	return true
