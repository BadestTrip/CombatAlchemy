class_name RangedEnemyAttack
extends EnemyAttack

# Responsibility: Release one independent projectile along the windup's captured direction.

## Editable projectile scene; no potion delivery or effect-resolver dependency.
@export var projectile_scene: PackedScene
## Assigned by the owning actor; defaults to the actor's parent in standalone scenes.
var projectiles_parent: Node


func configure(actor: Node2D, profile: EnemyProfileData) -> bool:
	if not super.configure(actor, profile):
		return false
	if projectile_scene == null:
		push_error("RangedEnemyAttack requires a projectile scene.")
		return false
	return true


func _execute() -> void:
	var container := projectiles_parent if is_instance_valid(projectiles_parent) else _actor.get_parent()
	if container == null:
		return
	var candidate := projectile_scene.instantiate() as Node2D
	if candidate == null or not candidate.has_method(&"launch"):
		if candidate != null:
			candidate.queue_free()
		push_error("RangedEnemyAttack projectile requires launch().")
		return
	container.add_child(candidate)
	candidate.call(
		&"launch", _actor.global_position, _direction, _target, _actor,
		_profile.damage, _profile.projectile_speed, _profile.projectile_lifetime
	)
