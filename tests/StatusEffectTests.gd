extends Node

# Responsibility: Verify timed, target-owned status effects and potion integration.

const STATUS_COMPONENT_SCRIPT_PATH := "res://combat/actors/StatusEffectComponent.gd"
const SLOW_EFFECT_SCRIPT_PATH := "res://combat/potions/effects/SlowPotionEffectData.gd"
const CONTEXT_SCRIPT_PATH := "res://combat/potions/effects/PotionImpactContext.gd"
const RESOLVER_SCRIPT_PATH := "res://combat/potions/effects/PotionEffectResolver.gd"
const RECIPE_BOOK_PATH := "res://combat/potions/resources/PotionRecipeBook_Default.tres"

const SLOW_AMOUNT := 0.45
const SLOW_CAP := 0.80
const SLOW_DURATION := 5.0

var _failures: Array[String] = []
var _checks := 0
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	_run_tests()
	_free_owned_nodes()
	for failure in _failures:
		push_error(failure)
	print("StatusEffectTests: %s (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run_tests() -> void:
	var status_script := _load_required_script(STATUS_COMPONENT_SCRIPT_PATH)
	var slow_effect_script := _load_required_script(SLOW_EFFECT_SCRIPT_PATH)
	var context_script := _load_required_script(CONTEXT_SCRIPT_PATH)
	var resolver_script := _load_required_script(RESOLVER_SCRIPT_PATH)
	_test_rgb_recipe_exists(slow_effect_script)
	if status_script == null or slow_effect_script == null or context_script == null or resolver_script == null:
		return
	_test_slow_stacks_caps_and_decays(status_script)
	_test_slow_refreshes_its_decay_window(status_script)
	_test_slow_effect_requires_a_status_capability(status_script, slow_effect_script, context_script, resolver_script)


func _load_required_script(path: String) -> Script:
	_expect(FileAccess.file_exists(path), "%s exists" % path.get_file())
	return load(path) as Script if FileAccess.file_exists(path) else null


func _test_rgb_recipe_exists(slow_effect_script: Script) -> void:
	_expect(ResourceLoader.exists(RECIPE_BOOK_PATH), "default potion recipe book exists")
	var recipe_book := load(RECIPE_BOOK_PATH) as PotionRecipeBookData
	_expect(recipe_book != null, "default potion recipe book loads")
	if recipe_book == null:
		return
	var recipe := recipe_book.find_match([PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE])
	_expect(recipe != null, "RGB layers resolve to the slow potion")
	if recipe == null:
		return
	_expect(recipe.recipe_id == "slow_potion", "RGB recipe uses the stable slow_potion identifier")
	_expect(recipe.effects.size() == 1, "RGB recipe contains one focused effect")
	_expect(slow_effect_script != null and recipe.effects[0].get_script() == slow_effect_script, "RGB recipe contains SlowPotionEffectData")


func _test_slow_stacks_caps_and_decays(status_script: Script) -> void:
	var statuses := status_script.new() as Node
	_expect(statuses != null, "StatusEffectComponent instantiates")
	if statuses == null:
		return
	_owned_nodes.append(statuses)
	_expect(statuses.has_method(&"apply_slow"), "status component exposes apply_slow")
	_expect(statuses.has_method(&"advance"), "status component exposes deterministic advance")
	_expect(statuses.has_method(&"get_speed_multiplier"), "status component exposes effective speed")
	if not statuses.has_method(&"apply_slow") or not statuses.has_method(&"advance") or not statuses.has_method(&"get_speed_multiplier"):
		return
	statuses.call(&"apply_slow", SLOW_AMOUNT, SLOW_DURATION)
	_expect(is_equal_approx(statuses.call(&"get_speed_multiplier") as float, 1.0 - SLOW_AMOUNT), "one slow application reduces speed by 45 percent")
	statuses.call(&"apply_slow", SLOW_AMOUNT, SLOW_DURATION)
	_expect(is_equal_approx(statuses.call(&"get_speed_multiplier") as float, 1.0 - SLOW_CAP), "two slow applications clamp at 80 percent reduction")
	statuses.call(&"advance", 2.5)
	_expect(is_equal_approx(statuses.call(&"get_speed_multiplier") as float, 1.0 - SLOW_CAP * 0.5), "slow reduction decays linearly")
	statuses.call(&"advance", 2.5)
	_expect(is_equal_approx(statuses.call(&"get_speed_multiplier") as float, 1.0), "expired slow restores full speed")


func _test_slow_refreshes_its_decay_window(status_script: Script) -> void:
	var statuses := status_script.new() as Node
	_owned_nodes.append(statuses)
	statuses.call(&"apply_slow", SLOW_AMOUNT, SLOW_DURATION)
	statuses.call(&"advance", 2.5)
	statuses.call(&"apply_slow", SLOW_AMOUNT, SLOW_DURATION)
	_expect(is_equal_approx(statuses.call(&"get_speed_multiplier") as float, 1.0 - 0.675), "fresh slow adds to remaining potency and restarts decay")
	statuses.call(&"advance", 4.0)
	_expect(is_equal_approx(statuses.call(&"get_speed_multiplier") as float, 1.0 - 0.675 * 0.2), "refreshed slow decays from its new window")
	_expect((statuses.call(&"get_active_statuses") as Array).size() == 1, "slow remains one shared visible status")


func _test_slow_effect_requires_a_status_capability(status_script: Script, slow_effect_script: Script, context_script: Script, resolver_script: Script) -> void:
	var subject := Node2D.new()
	var statuses := status_script.new() as Node
	subject.add_child(statuses)
	_owned_nodes.append(subject)
	var supported_context: PotionImpactContext = context_script.new() as PotionImpactContext
	supported_context.call(&"configure", subject, subject, null, Vector2.ZERO, Vector2.RIGHT, PotionDelivery.THROW)
	var recipe := _new_recipe([slow_effect_script.new()])
	_expect(resolver_script.call(&"apply_recipe", recipe, supported_context) == 1, "slow applies to a target with StatusEffectComponent")
	_expect(is_equal_approx(statuses.call(&"get_speed_multiplier") as float, 1.0 - SLOW_AMOUNT), "slow effect supplies 45 percent reduction")
	var unsupported_subject := Node2D.new()
	_owned_nodes.append(unsupported_subject)
	var unsupported_context: PotionImpactContext = context_script.new() as PotionImpactContext
	unsupported_context.call(&"configure", unsupported_subject, unsupported_subject, null, Vector2.ZERO, Vector2.RIGHT, PotionDelivery.THROW)
	_expect(resolver_script.call(&"apply_recipe", recipe, unsupported_context) == 0, "slow cleanly ignores unsupported targets")


func _new_recipe(effects: Array[PotionEffectData]) -> PotionRecipeData:
	var recipe := PotionRecipeData.new()
	recipe.recipe_id = "slow_test"
	recipe.display_name = "Slow Test"
	recipe.red_count = 1
	recipe.green_count = 1
	recipe.blue_count = 1
	recipe.effects = effects
	return recipe


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
