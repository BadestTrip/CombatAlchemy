extends Node

const TEST_PATH := "user://potion_quality_test.cfg"
const QUALITY_PATH := "res://combat/potions/resources/PotionQualityProfile_Default.tres"
const HEALTH_RECIPE := preload("res://combat/potions/resources/HealthPotion.tres")
const LAYERS: Array[StringName] = [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]
const MULTIPLIERS := [0.6, 0.8, 1.0, 1.2, 1.4]

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	# Keep the initial regression runnable before the new API exists.
	var instance := PotionInstance.create(HEALTH_RECIPE, LAYERS)
	_expect(instance.has_method("get_quality_score"), "instances expose quality score")
	_expect(instance.has_method("get_potency_multiplier"), "instances expose potency")
	_expect(ResourceLoader.exists(QUALITY_PATH), "default quality profile exists")
	if _failures.is_empty():
		_test_profile_and_defaults()
		_test_effects_and_immutable_recipe()
		_test_quality_roundtrip()
		_test_legacy_migration_and_backup()
		_test_invalid_quality()
	PlayerProfileStore.delete_test_files(TEST_PATH)
	if _failures.is_empty():
		print("PotionQualityTests: PASS (%d checks)" % _checks)
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_profile_and_defaults() -> void:
	var profile: Resource = load(QUALITY_PATH)
	_expect(profile.call("is_valid"), "default quality multipliers validate")
	for score in range(-2, 3):
		_expect(is_equal_approx(profile.call("get_multiplier", score), MULTIPLIERS[score + 2]), "profile maps score %d" % score)
	var potion := PotionInstance.create(HEALTH_RECIPE, LAYERS)
	_expect(potion.call("get_quality_score") == 0, "legacy create defaults to neutral quality")
	_expect(potion.call("get_potency_multiplier") == 1.0, "legacy create defaults to neutral potency")
	_expect(PotionImpactContext.new().get("potency_multiplier") == 1.0, "new impact context defaults to neutral potency")
	var editable: Resource = profile.duplicate()
	for property in ["minus_two_multiplier", "minus_one_multiplier", "neutral_multiplier", "plus_one_multiplier", "plus_two_multiplier"]:
		var original: float = editable.get(property)
		for invalid in [0.0, -0.1, INF, NAN]:
			editable.set(property, invalid)
			_expect(not editable.call("is_valid"), "profile rejects invalid %s" % property)
		editable.set(property, original)
	editable.set("plus_two_multiplier", 1.75)
	_expect(is_equal_approx(editable.call("get_multiplier", 2), 1.75), "profile multipliers are editable")


func _test_effects_and_immutable_recipe() -> void:
	var health_effect := HealthPotionEffectData.new()
	health_effect.amount = 7
	var slow_effect := SlowPotionEffectData.new()
	var recipe := PotionRecipeData.new()
	recipe.recipe_id = "quality_test"
	recipe.red_count = 2
	recipe.blue_count = 1
	recipe.effects = [health_effect, slow_effect]
	var actor := Node.new()
	var health := HealthComponent.new()
	var statuses := StatusEffectComponent.new()
	actor.add_child(health)
	actor.add_child(statuses)
	var context := PotionImpactContext.new().configure(actor, actor, null, Vector2.ZERO, Vector2.RIGHT, PotionDelivery.DRINK)
	for score in range(-2, 3):
		var multiplier: float = MULTIPLIERS[score + 2]
		for operation in [HealthPotionEffectData.Operation.HEAL, HealthPotionEffectData.Operation.DAMAGE]:
			health_effect.operation = operation
			health.current_health = 50
			statuses.advance(10.0)
			var potion := _create(recipe, LAYERS, score, multiplier)
			_expect(potion != null, "quality %d creates an instance" % score)
			if potion == null:
				continue
			_expect(potion.call("get_quality_score") == score, "instance retains score")
			_expect(is_equal_approx(potion.call("get_potency_multiplier"), multiplier), "instance retains multiplier")
			context.set("potency_multiplier", 9.0)
			_expect(potion.apply(context) == 2, "both quality-scaled effects apply")
			var expected := 50 + roundi(7 * multiplier) * (1 if operation == HealthPotionEffectData.Operation.HEAL else -1)
			_expect(health.current_health == expected, "health rounds scaled amount at quality %d" % score)
			_expect(is_equal_approx(statuses.get_slow_reduction(), 0.45 * multiplier), "slow scales at quality %d" % score)
			_expect(is_equal_approx(context.get("potency_multiplier"), multiplier), "instance overwrites context potency before resolution")
			_expect(potion.apply(context) == 0 and health.current_health == expected, "quality potion only applies once")
			statuses.advance(2.5)
			_expect(is_equal_approx(statuses.get_remaining_ratio(), 0.5), "quality leaves duration unchanged")
			_expect(is_equal_approx(statuses.get_slow_reduction(), 0.225 * multiplier), "scaled slow decays normally")
			statuses.advance(2.5)
			_expect(is_zero_approx(statuses.get_slow_reduction()), "quality slow expires at original duration")
			_expect(health_effect.amount == 7 and health_effect.operation == operation, "health resource remains immutable during apply")
			_expect(is_equal_approx(slow_effect.reduction, 0.45) and slow_effect.duration == 5.0, "slow resource remains immutable during apply")
			_expect(potion.get_recipe() == recipe and recipe.effects == [health_effect, slow_effect], "shared recipe and effects retain identity")
	var strong := _create(recipe, LAYERS, 2, 1.4)
	strong.apply(context)
	var second := _create(recipe, LAYERS, 2, 1.4)
	second.apply(context)
	_expect(is_equal_approx(statuses.get_slow_reduction(), 0.8), "scaled slow stacking retains existing cap")
	actor.free()


func _test_quality_roundtrip() -> void:
	for score in range(-2, 3):
		PlayerProfileStore.delete_test_files(TEST_PATH)
		var profile := PlayerProfile.new(PlayerProfileStore.new(TEST_PATH))
		profile.collect_reagent(PotionReagent.RED, 2)
		profile.collect_reagent(PotionReagent.BLUE, 1)
		for layer in LAYERS:
			profile.inventory.reserve(layer)
		# Deliberately differs from the default table: loading must not rebalance it.
		var original_multiplier := 1.13 + score * 0.1
		_expect(profile.call("commit_prepared_potion", &"health", LAYERS, score, original_multiplier), "quality potion commits")
		var loaded := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
		_expect(loaded != null, "quality save reloads")
		if loaded != null:
			var held := loaded.get_held_record()
			_expect(held.get("quality_score") == score, "saved score roundtrips")
			_expect(is_equal_approx(held.get("potency_multiplier", -1.0), original_multiplier), "original multiplier roundtrips without recalculation")
			var restored := _create(HEALTH_RECIPE, held.layers, held.get("quality_score", 0), held.get("potency_multiplier", 1.0))
			_expect(restored != null and is_equal_approx(restored.call("get_potency_multiplier"), original_multiplier), "held record reconstructs the original potency")
		var config := ConfigFile.new()
		config.load(TEST_PATH)
		_expect(config.get_value("profile", "version") == 2, "save writes version two")
		_expect(config.get_value("held", "quality_score", null) == score, "version two writes score")
		_expect(is_equal_approx(config.get_value("held", "potency_multiplier", -1.0), original_multiplier), "version two writes original multiplier")
		profile.collect_reagent(PotionReagent.GREEN, 1)
		var corrupt := ConfigFile.new()
		corrupt.set_value("profile", "version", -1)
		corrupt.save(TEST_PATH)
		var recovered := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
		_expect(recovered != null, "quality backup recovers")
		if recovered != null:
			_expect(recovered.get_held_record().get("quality_score") == score, "quality backup preserves score")
			_expect(is_equal_approx(recovered.get_held_record().get("potency_multiplier", -1.0), original_multiplier), "quality backup preserves original multiplier")


func _test_legacy_migration_and_backup() -> void:
	for mode in ["primary", "missing_primary", "corrupt_primary"]:
		PlayerProfileStore.delete_test_files(TEST_PATH)
		var path := TEST_PATH if mode == "primary" else TEST_PATH + ".bak"
		_write_fixture(path, 1)
		if mode == "corrupt_primary":
			_write_fixture(TEST_PATH, 99)
		var profile := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
		_expect(profile != null, "v1 loads via %s" % mode)
		if profile == null:
			continue
		var held := profile.get_held_record()
		_expect(held.get("quality_score") == 0 and held.get("potency_multiplier") == 1.0, "v1 migrates to neutral quality via %s" % mode)
		_expect(held.recipe_id == &"health" and held.layers == LAYERS, "v1 retains held recipe and layers")
		_expect(profile.inventory.get_total_count(PotionReagent.RED) == 9, "v1 retains inventory")
		_expect(profile.collect_reagent(PotionReagent.GREEN, 1), "migrated v1 can save as v2")
		var config := ConfigFile.new()
		config.load(TEST_PATH)
		_expect(config.get_value("profile", "version") == 2, "v1 next save upgrades to v2")
		var reloaded := PlayerProfile.load(PlayerProfileStore.new(TEST_PATH))
		_expect(reloaded != null and reloaded.get_held_record().get("potency_multiplier") == 1.0, "migrated neutral potency survives v2 reload")


func _test_invalid_quality() -> void:
	for score in [-3, 3]:
		_expect(_create(HEALTH_RECIPE, LAYERS, score, 1.0) == null, "instance rejects out-of-range score")
	for multiplier in [0.0, -1.0, INF, NAN]:
		_expect(_create(HEALTH_RECIPE, LAYERS, 0, multiplier) == null, "instance rejects invalid multiplier")
	var invalid_records := [
		{"quality_score": -3, "potency_multiplier": 1.0},
		{"quality_score": 3, "potency_multiplier": 1.0},
		{"quality_score": 0.5, "potency_multiplier": 1.0},
		{"quality_score": "1", "potency_multiplier": 1.0},
		{"quality_score": true, "potency_multiplier": 1.0},
		{"quality_score": 0, "potency_multiplier": 0.0},
		{"quality_score": 0, "potency_multiplier": -1.0},
		{"quality_score": 0, "potency_multiplier": INF},
		{"quality_score": 0, "potency_multiplier": NAN},
		{"quality_score": 0, "potency_multiplier": "1.2"},
		{"quality_score": 0, "potency_multiplier": true},
		{"quality_score": 0},
		{"potency_multiplier": 1.0},
	]
	for values in invalid_records:
		PlayerProfileStore.delete_test_files(TEST_PATH)
		_write_fixture(TEST_PATH, 2, values)
		var before := FileAccess.get_file_as_bytes(TEST_PATH)
		var store := PlayerProfileStore.new(TEST_PATH)
		_expect(not store.load_snapshot().ok, "v2 rejects malformed or missing quality: %s" % values)
		_expect(not store.last_error.is_empty(), "corrupted quality reports load error")
		_expect(FileAccess.get_file_as_bytes(TEST_PATH) == before, "corrupted quality file is not reset")
		_write_fixture(TEST_PATH + ".bak", 1)
		var recovered := store.load_snapshot()
		_expect(recovered.ok, "invalid v2 quality falls back to valid v1 backup")
		if recovered.ok:
			_expect(recovered.snapshot.held.get("quality_score") == 0, "fallback applies v1 neutral migration")
	PlayerProfileStore.delete_test_files(TEST_PATH)
	var profile := PlayerProfile.create_in_memory({PotionReagent.RED: 2, PotionReagent.BLUE: 1})
	for layer in LAYERS:
		profile.inventory.reserve(layer)
	_expect(not profile.call("commit_prepared_potion", &"health", LAYERS, 3, 1.0), "invalid quality commit is rejected in memory")
	_expect(not profile.call("commit_prepared_potion", &"health", LAYERS, 0, NAN), "invalid potency commit is rejected in memory")
	_expect(profile.inventory.get_reserved_count(PotionReagent.RED) == 2 and not profile.has_held_potion(), "rejected commit preserves ownership and reservations")
	_expect(profile.commit_prepared_potion(&"health", LAYERS), "legacy commit remains supported")
	_expect(profile.get_held_record().get("quality_score") == 0 and profile.get_held_record().get("potency_multiplier") == 1.0, "legacy commit records neutral quality")
	var held := profile.get_held_record()
	held["potency_multiplier"] = NAN
	_expect(not profile.restore_held_potion(held), "restore rejects malformed potency")
	var store := PlayerProfileStore.new(TEST_PATH)
	_expect(not store.save_snapshot({"totals": {}, "held": held}), "store rejects malformed quality before writing")
	_expect(not FileAccess.file_exists(TEST_PATH), "invalid snapshot does not create a profile")


func _create(recipe: PotionRecipeData, layers: Array[StringName], score: int, multiplier: float) -> PotionInstance:
	var script: Script = load("res://combat/potions/PotionInstance.gd")
	return script.call("create", recipe, layers, score, multiplier)


func _write_fixture(path: String, version: int, values: Dictionary = {}) -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "version", version)
	config.set_value("reagents", "red", 9)
	config.set_value("held", "recipe_id", "health")
	config.set_value("held", "layers", PackedStringArray(["red", "red", "blue"]))
	for key in values:
		config.set_value("held", key, values[key])
	_expect(config.save(path) == OK, "test fixture writes to test-only path")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
