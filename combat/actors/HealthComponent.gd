class_name HealthComponent
extends Node

# Responsibility: Own bounded actor health and report health state changes.

## Emitted whenever current or maximum health changes.
signal health_changed(current_health: int, max_health: int)
## Emitted only when health moves from a positive value to zero.
signal depleted

var _max_health: int = 100
var _current_health: int = 100

## The highest health this component can hold. Runtime assignments clamp to one or higher.
@export_range(1, 9999, 1) var max_health: int = 100:
	get:
		return _max_health
	set(value):
		_apply_health(value, _current_health)

## The actor's current health. Runtime assignments clamp between zero and maximum health.
@export_range(0, 9999, 1) var current_health: int = 100:
	get:
		return _current_health
	set(value):
		_apply_health(_max_health, value)


## Removes health and returns the amount actually removed.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var actual_damage := mini(amount, _current_health)
	current_health = _current_health - actual_damage
	return actual_damage


## Restores health and returns the amount actually restored.
func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var actual_heal := mini(amount, _max_health - _current_health)
	current_health = _current_health + actual_heal
	return actual_heal


## Restores health, optionally replacing maximum and current values before clamping.
func reset_health(new_max_health: int = -1, new_current_health: int = -1) -> void:
	var resolved_max := new_max_health if new_max_health >= 1 else _max_health
	var resolved_current := new_current_health if new_current_health >= 0 else resolved_max
	_apply_health(resolved_max, resolved_current)


## Returns current health as a value from zero through one.
func get_health_ratio() -> float:
	return float(_current_health) / float(_max_health)


func _apply_health(new_max_health: int, new_current_health: int) -> void:
	var previous_health := _current_health
	var clamped_max := maxi(new_max_health, 1)
	var clamped_current := clampi(new_current_health, 0, clamped_max)
	if _max_health == clamped_max and _current_health == clamped_current:
		return
	_max_health = clamped_max
	_current_health = clamped_current
	health_changed.emit(_current_health, _max_health)
	if previous_health > 0 and _current_health == 0:
		depleted.emit()
