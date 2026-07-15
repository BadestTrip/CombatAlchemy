class_name PotionProjectile
extends Area2D

# Responsibility: Move one prepared potion forward and apply it to the first valid target hit.

## Projectile movement speed in pixels per second.
@export_range(0.0, 2000.0, 1.0) var speed: float = 650.0
## Maximum lifetime in seconds before the projectile expires.
@export_range(0.01, 10.0, 0.01) var lifetime: float = 2.5

@onready var _projectile_visual: Polygon2D = $ProjectileVisual
@onready var _outline: Line2D = $Outline

var _recipe: PotionRecipeData
var _direction := Vector2.RIGHT
var _ignored_target: PotionTarget
var _elapsed := 0.0
var _launched := false


## Initializes this projectile with a recipe, trajectory, and optional target to ignore.
func launch(
	recipe: PotionRecipeData,
	origin: Vector2,
	direction: Vector2,
	ignored_target: PotionTarget = null
) -> bool:
	if recipe == null or not recipe.is_valid():
		queue_free()
		return false
	_recipe = recipe
	global_position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.000001 else Vector2.RIGHT
	_ignored_target = ignored_target
	_elapsed = 0.0
	_launched = true
	_set_visual_color(recipe.mixed_color)
	return true


func _physics_process(delta: float) -> void:
	if not _launched:
		return
	global_position += _direction * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not _launched or area == _ignored_target:
		return
	var target := area as PotionTarget
	if target != null and target.receive_potion(_recipe):
		_launched = false
		set_deferred(&"monitoring", false)
		queue_free()


func _set_visual_color(color: Color) -> void:
	_projectile_visual.color = color
	_outline.default_color = color.lightened(0.25)
