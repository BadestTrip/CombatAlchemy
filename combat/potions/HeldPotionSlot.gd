class_name HeldPotionSlot
extends Node

# Responsibility: Own references to the one potion instance and entity currently held by the player.

signal potion_changed(potion: PotionInstance)

var _potion: PotionInstance
var _entity: PotionEntity


func hold(potion: PotionInstance, entity: PotionEntity) -> bool:
	if (
		has_potion()
		or potion == null
		or not potion.is_valid()
		or potion.is_consumed()
		or entity == null
		or not is_instance_valid(entity)
		or entity.get_potion() != potion
	):
		return false
	_potion = potion
	_entity = entity
	potion_changed.emit(_potion)
	return true


func clear() -> void:
	if not has_potion():
		return
	_potion = null
	_entity = null
	potion_changed.emit(null)


func has_potion() -> bool:
	return _potion != null and _entity != null


func get_potion() -> PotionInstance:
	return _potion


func get_entity() -> PotionEntity:
	return _entity
