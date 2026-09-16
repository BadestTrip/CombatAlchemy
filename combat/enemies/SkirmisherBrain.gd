class_name SkirmisherBrain
extends EnemyBrain

# Responsibility: Regain firing distance, hold to shoot, and retreat when approached.

func tick() -> void:
	if attack.is_busy():
		_state = &"attack"
		movement.stop()
		return
	var distance := senses.distance_to_target
	if distance < profile.retreat_start or (_state == &"retreat" and distance < profile.retreat_stop):
		_state = &"retreat"
		movement.move_in_direction(-senses.direction_to_target)
	elif distance > profile.approach_start or (_state == &"approach" and distance > profile.approach_stop):
		_state = &"approach"
		movement.move_in_direction(senses.direction_to_target)
	else:
		_state = &"hold"
		movement.stop()
		if distance <= profile.attack_start_distance and attack.try_start(senses.get_target()):
			_state = &"attack"
