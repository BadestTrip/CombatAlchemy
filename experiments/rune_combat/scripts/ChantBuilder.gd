extends Node
class_name ChantBuilder

signal chant_changed(sequence: Array[String])

@export var max_length: int = 5

var _sequence: Array[String] = []


func add_rune(rune_id: String) -> bool:
	if _sequence.size() >= max_length:
		return false
	_sequence.append(rune_id)
	chant_changed.emit(get_sequence())
	return true


func remove_last() -> void:
	if _sequence.is_empty():
		return
	_sequence.pop_back()
	chant_changed.emit(get_sequence())


func clear() -> void:
	if _sequence.is_empty():
		return
	_sequence.clear()
	chant_changed.emit(get_sequence())


func get_sequence() -> Array[String]:
	var copy: Array[String] = []
	for rune_id in _sequence:
		copy.append(rune_id)
	return copy
