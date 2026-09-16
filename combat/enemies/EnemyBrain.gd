class_name EnemyBrain
extends Node

# Responsibility: Define the small dependency contract shared by tactical decision scripts.

var senses: EnemySenses
var movement: EnemyMovement
var attack: EnemyAttack
var profile: EnemyProfileData
var _state: StringName = &"idle"


## Receives scene-local capabilities; no component discovers global gameplay nodes.
func configure(sensor: EnemySenses, motor: EnemyMovement, action: EnemyAttack, tuning: EnemyProfileData) -> void:
	senses = sensor
	movement = motor
	attack = action
	profile = tuning


## Concrete archetypes choose a movement request or attack each physics update.
func tick() -> void:
	pass


## Clears tactical memory when the assigned target becomes unavailable.
func reset() -> void:
	_state = &"idle"
	movement.stop()


## Read-only tactical state for diagnostics and behaviour tests.
func get_state() -> StringName:
	return _state
