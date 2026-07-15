class_name PotionTarget
extends Area2D

# Responsibility: Receive potion recipes and apply their effects to one health component.

## Emitted after a valid potion recipe has been applied.
signal potion_received(recipe: PotionRecipeData)

## Path to the HealthComponent that receives potion effects.
@export var health_component_path: NodePath

var _health_component: HealthComponent


func _ready() -> void:
	_health_component = get_health_component()
	if _health_component == null:
		push_error("PotionTarget requires a valid HealthComponent path.")


## Applies a valid potion recipe and reports whether the target accepted it.
func receive_potion(recipe: PotionRecipeData) -> bool:
	if recipe == null or not recipe.is_valid():
		return false
	var health := get_health_component()
	if health == null:
		return false
	match recipe.effect_type:
		PotionRecipeData.EffectType.HEAL:
			health.heal(recipe.effect_amount)
		PotionRecipeData.EffectType.DAMAGE:
			health.take_damage(recipe.effect_amount)
		_:
			return false
	potion_received.emit(recipe)
	return true


## Returns the configured HealthComponent, or null when the path is invalid.
func get_health_component() -> HealthComponent:
	if is_instance_valid(_health_component):
		return _health_component
	_health_component = get_node_or_null(health_component_path) as HealthComponent
	return _health_component
