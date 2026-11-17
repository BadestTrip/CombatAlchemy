class_name PlayerProfile
extends RefCounted

var inventory: ReagentInventory
var _store: PlayerProfileStore
var _held: Dictionary = {}
var last_error := ""

func _init(store: PlayerProfileStore = null) -> void:
	_store = store if store != null else PlayerProfileStore.new()
	inventory = ReagentInventory.new()

static func load(store: PlayerProfileStore) -> PlayerProfile:
	var result := store.load_snapshot()
	if not bool(result.get("ok", false)):
		return null
	var profile := PlayerProfile.new(store)
	var snapshot: Dictionary = result.snapshot
	profile.inventory.apply_totals(snapshot.totals)
	profile._held = snapshot.held.duplicate(true)
	return profile

static func create_in_memory(totals: Dictionary = {}) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile._store = null
	profile.inventory.apply_totals(totals)
	return profile

func collect_reagent(reagent: StringName, amount: int) -> bool:
	if amount <= 0 or not PotionReagent.is_valid(reagent):
		return false
	var totals := inventory.get_totals_copy()
	totals[reagent] = int(totals.get(reagent, 0)) + amount
	return _save_and_apply(totals, _held, true)

func commit_prepared_potion(recipe_id: StringName, layers: Array[StringName]) -> bool:
	var totals := inventory.get_totals_copy()
	var required: Dictionary = {}
	for reagent in layers:
		required[reagent] = int(required.get(reagent, 0)) + 1
	for reagent in required:
		var amount: int = int(required[reagent])
		if inventory.get_reserved_count(reagent) < amount:
			return false
		totals[reagent] = int(totals.get(reagent, 0)) - amount
	var held := {"recipe_id": recipe_id, "layers": layers.duplicate()}
	return _save_and_apply(totals, held)

func clear_held_potion() -> bool:
	return _save_and_apply(inventory.get_totals_copy(), {}, true)

## Restores an already-owned bottle after a rejected delivery transition.
func restore_held_potion(record: Dictionary) -> bool:
	if StringName(record.get("recipe_id", "")).is_empty():
		return false
	return _save_and_apply(inventory.get_totals_copy(), record, true)

func has_held_potion() -> bool:
	return not StringName(_held.get("recipe_id", "")).is_empty()

func get_held_record() -> Dictionary:
	return _held.duplicate(true)

func _save_and_apply(totals: Dictionary, held: Dictionary, preserve_reservations: bool = false) -> bool:
	if _store != null and not _store.save_snapshot({"totals": totals, "held": held}):
		last_error = _store.last_error
		return false
	inventory.apply_totals(totals, preserve_reservations)
	_held = held.duplicate(true)
	last_error = ""
	return true
