extends Node

const TEST_PATH := "user://player_profile_test.cfg"

var _failures: Array[String] = []

func _ready() -> void:
	_test_inventory_reservations()
	_test_collection_preserves_reservations()
	_test_invalid_reagent_is_rejected()
	_test_persisted_profile()
	_test_corrupt_primary_recovers_last_good_backup()
	_test_missing_primary_recovers_last_good_backup()
	_test_corrupt_primary_never_replaces_good_backup()
	if _failures.is_empty():
		print("PlayerProfileTests: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)

func _test_inventory_reservations() -> void:
	var inventory := ReagentInventory.new({PotionReagent.RED: 1000, PotionReagent.BLUE: 1})
	_expect(inventory.get_stack_count(PotionReagent.RED) == 2, "1000 reagents occupy two logical stacks")
	_expect(inventory.reserve(PotionReagent.RED), "available reagent reserves")
	_expect(inventory.get_available_count(PotionReagent.RED) == 999, "reservation lowers availability")
	_expect(not inventory.reserve(PotionReagent.GREEN), "missing reagent cannot reserve")
	inventory.release(PotionReagent.RED)
	_expect(inventory.get_available_count(PotionReagent.RED) == 1000, "release restores availability")

func _test_collection_preserves_reservations() -> void:
	PlayerProfileStore.delete_test_files(TEST_PATH)
	var profile := PlayerProfile.new(PlayerProfileStore.new(TEST_PATH))
	_expect(profile.collect_reagent(PotionReagent.RED, 2), "reservation fixture persists stock")
	_expect(profile.inventory.reserve(PotionReagent.RED), "unfinished mixture reserves one red")
	_expect(profile.collect_reagent(PotionReagent.BLUE, 5), "collection succeeds while a mixture is unfinished")
	_expect(profile.inventory.get_reserved_count(PotionReagent.RED) == 1, "collection preserves existing reservations")
	_expect(profile.inventory.get_available_count(PotionReagent.RED) == 1, "reserved stock remains unavailable after collection")
	PlayerProfileStore.delete_test_files(TEST_PATH)

func _test_invalid_reagent_is_rejected() -> void:
	PlayerProfileStore.delete_test_files(TEST_PATH)
	var profile := PlayerProfile.new(PlayerProfileStore.new(TEST_PATH))
	_expect(not profile.collect_reagent(&"yellow", 5), "unknown reagent cannot be persisted")
	_expect(profile.inventory.get_total_count(&"yellow") == 0, "unknown reagent awards no invisible stock")
	PlayerProfileStore.delete_test_files(TEST_PATH)

func _test_persisted_profile() -> void:
	PlayerProfileStore.delete_test_files(TEST_PATH)
	var profile := PlayerProfile.new(PlayerProfileStore.new(TEST_PATH))
	_expect(profile.collect_reagent(PotionReagent.RED, 5), "collection persists before ownership changes")
	_expect(profile.collect_reagent(PotionReagent.BLUE, 1), "second collection persists")
	_expect(profile.inventory.reserve(PotionReagent.RED), "red reservation works")
	_expect(profile.inventory.reserve(PotionReagent.RED), "second red reservation works")
	_expect(profile.inventory.reserve(PotionReagent.BLUE), "blue reservation works")
	_expect(profile.commit_prepared_potion("health", [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]), "brew commits one held record")
	var loaded := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
	_expect(loaded != null, "saved profile reloads")
	if loaded != null:
		_expect(loaded.inventory.get_total_count(PotionReagent.RED) == 3, "committed recipe spends red")
		_expect(loaded.inventory.get_total_count(PotionReagent.BLUE) == 0, "committed recipe spends blue")
		_expect(loaded.has_held_potion(), "held potion record persists")
	PlayerProfileStore.delete_test_files(TEST_PATH)

func _test_corrupt_primary_recovers_last_good_backup() -> void:
	PlayerProfileStore.delete_test_files(TEST_PATH)
	var profile := PlayerProfile.new(PlayerProfileStore.new(TEST_PATH))
	_expect(profile.collect_reagent(PotionReagent.RED, 5), "backup fixture writes first snapshot")
	_expect(profile.collect_reagent(PotionReagent.BLUE, 3), "backup fixture writes second snapshot")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("corrupt")
	file = null
	var recovered := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
	_expect(recovered != null, "corrupt primary loads last-good backup")
	if recovered != null:
		_expect(recovered.inventory.get_total_count(PotionReagent.RED) == 5, "backup preserves previous red total")
		_expect(recovered.inventory.get_total_count(PotionReagent.BLUE) == 0, "backup is the previous durable snapshot")
	PlayerProfileStore.delete_test_files(TEST_PATH)

func _test_corrupt_primary_never_replaces_good_backup() -> void:
	PlayerProfileStore.delete_test_files(TEST_PATH)
	var profile := PlayerProfile.new(PlayerProfileStore.new(TEST_PATH))
	profile.collect_reagent(PotionReagent.RED, 5)
	profile.collect_reagent(PotionReagent.BLUE, 3)
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("corrupt primary")
	file = null
	_expect(profile.collect_reagent(PotionReagent.GREEN, 2), "save can replace a corrupt primary")
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("corrupt again")
	file = null
	var recovered := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
	_expect(recovered != null, "existing good backup survives a corrupt-primary save")
	if recovered != null:
		_expect(recovered.inventory.get_total_count(PotionReagent.RED) == 5, "surviving backup retains known-good data")
	PlayerProfileStore.delete_test_files(TEST_PATH)

func _test_missing_primary_recovers_last_good_backup() -> void:
	PlayerProfileStore.delete_test_files(TEST_PATH)
	var profile := PlayerProfile.new(PlayerProfileStore.new(TEST_PATH))
	_expect(profile.collect_reagent(PotionReagent.RED, 5), "missing-primary fixture writes first snapshot")
	_expect(profile.collect_reagent(PotionReagent.BLUE, 3), "missing-primary fixture creates a backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var recovered := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
	_expect(recovered != null, "missing primary loads the last-good backup")
	if recovered != null:
		_expect(recovered.inventory.get_total_count(PotionReagent.RED) == 5, "backup recovers owned reagents when primary is missing")
		_expect(recovered.inventory.get_total_count(PotionReagent.BLUE) == 0, "backup remains the previous durable snapshot")
	PlayerProfileStore.delete_test_files(TEST_PATH)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
