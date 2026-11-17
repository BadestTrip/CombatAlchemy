class_name ReagentInventory
extends RefCounted

signal availability_changed(reagent: StringName, available: int)

const STACK_SIZE := 999
var _totals: Dictionary = {}
var _reserved: Dictionary = {}

func _init(totals: Dictionary = {}) -> void:
	set_totals(totals)

func set_totals(totals: Dictionary) -> void:
	_totals.clear()
	_reserved.clear()
	for reagent in [PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE]:
		_totals[reagent] = max(0, int(totals.get(reagent, 0)))

func get_total_count(reagent: StringName) -> int:
	return int(_totals.get(reagent, 0))

func get_available_count(reagent: StringName) -> int:
	return max(0, get_total_count(reagent) - get_reserved_count(reagent))

func get_reserved_count(reagent: StringName) -> int:
	return int(_reserved.get(reagent, 0))

func get_stack_count(reagent: StringName) -> int:
	return ceili(float(get_total_count(reagent)) / float(STACK_SIZE))

func reserve(reagent: StringName, amount := 1) -> bool:
	if amount <= 0 or get_available_count(reagent) < amount:
		return false
	_reserved[reagent] = get_reserved_count(reagent) + amount
	availability_changed.emit(reagent, get_available_count(reagent))
	return true

func release(reagent: StringName, amount := 1) -> void:
	var released := mini(maxi(amount, 0), get_reserved_count(reagent))
	if released == 0:
		return
	_reserved[reagent] = get_reserved_count(reagent) - released
	availability_changed.emit(reagent, get_available_count(reagent))

func release_all() -> void:
	for reagent in _reserved.keys():
		release(reagent, get_reserved_count(reagent))

func apply_totals(totals: Dictionary, preserve_reservations: bool = false) -> void:
	var previous_reservations := _reserved.duplicate() if preserve_reservations else {}
	set_totals(totals)
	if preserve_reservations:
		for reagent in previous_reservations:
			_reserved[reagent] = mini(int(previous_reservations[reagent]), get_total_count(reagent))
	for reagent in [PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE]:
		availability_changed.emit(reagent, get_available_count(reagent))

func get_totals_copy() -> Dictionary:
	return _totals.duplicate()
