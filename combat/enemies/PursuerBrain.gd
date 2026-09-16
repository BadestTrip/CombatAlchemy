class_name PursuerBrain
extends EnemyBrain

# Responsibility: Pursue an acquired target, stop to strike, then finish attack recovery.

func tick() -> void:
	if attack.is_busy():
		_state = &"attack"
		movement.stop()
	elif senses.distance_to_target <= profile.attack_start_distance:
		movement.stop()
		if attack.try_start(senses.get_target()):
			_state = &"attack"
	else:
		_state = &"chase"
		movement.move_in_direction(senses.direction_to_target)
