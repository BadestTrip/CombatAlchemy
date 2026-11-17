extends Node

const SOURCE_SCENE := preload("res://combat/reagents/ReagentSource.tscn")
const COMBAT_SCENE := preload("res://combat/CombatScene.tscn")
const EFFECT_PATH := "res://combat/reagents/ReagentCollectionEffect.tscn"

class FailingProfileStore extends PlayerProfileStore:
	func save_snapshot(_snapshot: Dictionary) -> bool:
		last_error = "Forced collection write failure."
		return false

var _failures: Array[String] = []

func _ready() -> void:
	_test_source_awards_once()
	_test_arena_sources_and_input()
	_test_equal_distance_uses_node_path()
	_test_failed_collection_preserves_source_and_reports_error()
	await _test_player_collects_after_moving_in_combat()
	_expect(ResourceLoader.exists(EFFECT_PATH), "collection effect is a reusable authored scene")
	if _failures.is_empty():
		print("ReagentCollectionTests: PASS")
		get_tree().quit(0)
		return
	for failure in _failures: push_error(failure)
	get_tree().quit(1)

func _test_source_awards_once() -> void:
	var source := SOURCE_SCENE.instantiate() as ReagentSource
	add_child(source)
	var profile := PlayerProfile.create_in_memory()
	_expect(source.collect(profile) == 5, "source awards its complete initial stock")
	_expect(profile.inventory.get_total_count(PotionReagent.RED) == 5, "source award reaches persistent inventory")
	_expect(source.collect(profile) == 0, "depleted source cannot award twice")
	source.queue_free()

func _test_arena_sources_and_input() -> void:
	var combat := COMBAT_SCENE.instantiate()
	for data in [["RedSource", PotionReagent.RED], ["GreenSource", PotionReagent.GREEN], ["BlueSource", PotionReagent.BLUE]]:
		var source := combat.get_node("Arena/%s" % data[0]) as ReagentSource
		_expect(source != null and source.reagent == data[1], "%s uses its expected reagent" % data[0])
		var deposit := source.get_node_or_null(^"Deposit")
		_expect(deposit != null and StringName(deposit.get("color_id")) == data[1], "%s deposit uses its reagent color" % data[0])
	_expect(InputMap.has_action(&"collect_reagent"), "collection action exists")
	var uses_e := false
	for event in InputMap.action_get_events(&"collect_reagent"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_E: uses_e = true
	_expect(uses_e, "collection action uses physical E")
	combat.free()

func _test_equal_distance_uses_node_path() -> void:
	var collector := PlayerReagentCollector.new()
	var sensor := Area2D.new()
	sensor.name = "CollectionArea"
	collector.add_child(sensor)
	add_child(collector)
	var source_z := SOURCE_SCENE.instantiate() as ReagentSource
	source_z.name = "ZSource"
	var source_a := SOURCE_SCENE.instantiate() as ReagentSource
	source_a.name = "ASource"
	add_child(source_z)
	add_child(source_a)
	var candidates: Array[ReagentSource] = [source_z, source_a]
	var selected := collector.select_nearest_source(candidates)
	_expect(selected == source_a, "equal-distance source selection uses scene-node path")
	collector.queue_free()
	source_z.queue_free()
	source_a.queue_free()

func _test_failed_collection_preserves_source_and_reports_error() -> void:
	var collector := PlayerReagentCollector.new()
	var sensor := Area2D.new()
	sensor.name = "CollectionArea"
	collector.add_child(sensor)
	add_child(collector)
	var source := SOURCE_SCENE.instantiate() as ReagentSource
	add_child(source)
	var profile := PlayerProfile.new(FailingProfileStore.new())
	collector.configure(profile)
	collector.set("_current", source)
	var errors: Array[String] = []
	collector.collection_failed.connect(func(message: String) -> void: errors.append(message))
	var event := InputEventAction.new()
	event.action = &"collect_reagent"
	event.pressed = true
	collector._unhandled_input(event)
	_expect(source.doses == 5, "failed collection save leaves source stock unchanged")
	_expect(errors == ["Forced collection write failure."], "failed collection reports the profile error")
	collector.queue_free()
	source.queue_free()

func _test_player_collects_after_moving_in_combat() -> void:
	# Exercise real physics overlap and viewport input, not an injected _current.
	await get_tree().process_frame
	var profile := PlayerProfile.create_in_memory()
	GameManager.set_player_profile_for_testing(profile)
	var combat := COMBAT_SCENE.instantiate() as Node2D
	combat.get_node("LevelMusic").free()
	add_child(combat)
	var arena := combat.get_node("Arena") as Node2D
	arena.position = Vector2(400, 300)
	var player := combat.get_node("Arena/Player") as Node2D
	var sensor := player.get_node("ReagentCollector/CollectionArea") as Area2D
	player.position = Vector2(800, 600)
	await _wait_for_collection_overlap()
	_press_collection_key()
	_expect(profile.inventory.get_total_count(PotionReagent.RED) == 0, "E cannot collect a distant source")
	for data in [["RedSource", PotionReagent.RED], ["GreenSource", PotionReagent.GREEN], ["BlueSource", PotionReagent.BLUE]]:
		var source := combat.get_node("Arena/%s" % data[0]) as ReagentSource
		player.global_position = source.global_position + Vector2(0, 60)
		await _wait_for_collection_overlap()
		_expect(sensor.global_position.is_equal_approx(player.global_position), "collection sensor follows player and arena transforms")
		_expect(sensor.overlaps_area(source), "%s enters the moving collection sensor" % data[0])
		_expect(source.get_node("Prompt").visible, "%s shows E near the player" % data[0])
		_press_collection_key()
		await get_tree().process_frame
		_expect(profile.inventory.get_total_count(data[1]) == 5, "%s reaches inventory through physical E input" % data[0])
		_expect(source.doses == 0 and not source.get_node("Prompt").visible, "%s depletes and hides prompt" % data[0])
		_press_collection_key()
		_expect(profile.inventory.get_total_count(data[1]) == 5, "%s cannot collect twice through input" % data[0])
	combat.queue_free()
	await get_tree().process_frame
	GameManager.set_player_profile_for_testing(null)

func _wait_for_collection_overlap() -> void:
	for frame in range(3):
		await get_tree().physics_frame
	await get_tree().process_frame

func _press_collection_key() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	get_viewport().push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	get_viewport().push_input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
