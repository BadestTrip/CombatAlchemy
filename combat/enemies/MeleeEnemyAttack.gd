class_name MeleeEnemyAttack
extends EnemyAttack

# Responsibility: Resolve a single strike against the captured direction, reach and sector.

func configure(actor: Node2D, profile: EnemyProfileData) -> bool:
	if not super.configure(actor, profile):
		return false
	# Authored unit arc becomes the exact editable damage sector without creating visual nodes.
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(17):
		var angle := deg_to_rad(lerpf(-profile.melee_arc_degrees * 0.5, profile.melee_arc_degrees * 0.5, float(index) / 16.0))
		points.append(Vector2.from_angle(angle) * profile.melee_reach)
	(_telegraph as Polygon2D).polygon = points
	(_impact_flash as Polygon2D).polygon = points
	return true


func _execute() -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_target_health):
		return
	var offset := _target.global_position - _actor.global_position
	if offset.length() > _profile.melee_reach:
		return
	var minimum_dot := cos(deg_to_rad(_profile.melee_arc_degrees * 0.5))
	if offset.is_zero_approx() or offset.normalized().dot(_direction) >= minimum_dot:
		_target_health.take_damage(_profile.damage)
