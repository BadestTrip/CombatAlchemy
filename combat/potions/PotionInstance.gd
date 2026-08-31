class_name PotionInstance
extends RefCounted

# Responsibility: Own one valid prepared potion until it is consumed or discarded.

var _recipe: PotionRecipeData
var _created_layers: Array[StringName] = []
var _consumed := false


static func create(recipe: PotionRecipeData, layers: Array[StringName]) -> PotionInstance:
	if recipe == null or not recipe.is_valid() or not recipe.matches_layers(layers):
		return null
	var potion := PotionInstance.new()
	potion._recipe = recipe
	potion._created_layers.append_array(layers)
	return potion


func get_recipe() -> PotionRecipeData:
	return _recipe


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
	)


func is_consumed() -> bool:
	return _consumed


func apply(context: PotionImpactContext) -> int:
	if _consumed or not is_valid() or context == null or not context.is_valid():
		return 0
	_consumed = true
	return PotionEffectResolver.apply_recipe(_recipe, context)


func discard() -> bool:
	if _consumed:
		return false
	_consumed = true
	return true
