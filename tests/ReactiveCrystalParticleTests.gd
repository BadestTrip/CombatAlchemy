extends Node

# Responsibility: Verify the shared charged-neon palette and reusable crystal VFX scenes.

const PALETTE_PATH: String = "res://shared/alchemy/ChargedNeonPalette.tres"
const PILE_SCENE_PATH: String = "res://vfx/reactive_crystal/ReactiveCrystalPile.tscn"
const SHATTER_SCENE_PATH: String = "res://vfx/reactive_crystal/PotionShatterParticles.tscn"
const WORKSHOP_SCENE_PATH: String = "res://vfx/reactive_crystal/ReactiveCrystalVFXWorkshop.tscn"

var _failures: Array[String] = []
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	_test_required_resources()
	_test_palette_contract()
	await _test_pile_contract()
	await _test_shatter_contract()
	await _test_workshop_contract()
	_free_owned_nodes()

	if _failures.is_empty():
		print("ReactiveCrystalParticleTests: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("ReactiveCrystalParticleTests: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _test_required_resources() -> void:
	for path in [PALETTE_PATH, PILE_SCENE_PATH, SHATTER_SCENE_PATH, WORKSHOP_SCENE_PATH]:
		_expect(ResourceLoader.exists(path), "%s exists" % path)


func _test_palette_contract() -> void:
	if not ResourceLoader.exists(PALETTE_PATH):
		return
	var palette := load(PALETTE_PATH)
	_expect(palette != null and palette.has_method(&"get_color"), "palette exposes get_color")
	if palette == null or not palette.has_method(&"get_color"):
		return
	var expected_colors: Dictionary = {
		&"red": Color("ff2e50"),
		&"green": Color("9cff38"),
		&"blue": Color("29d9ff"),
		&"health": Color("ff3bd4"),
		&"damage": Color("20f5d0"),
	}
	for color_id in expected_colors:
		var actual := palette.call(&"get_color", color_id) as Color
		_expect(actual.is_equal_approx(expected_colors[color_id]), "%s resolves to its charged-neon color" % color_id)
	_expect((palette.call(&"get_color", &"unknown") as Color) == Color.WHITE, "unknown palette IDs fall back to white")


func _test_pile_contract() -> void:
	var pile := _instantiate_scene(PILE_SCENE_PATH)
	if pile == null:
		return
	add_child(pile)
	await get_tree().process_frame
	for method_name in [&"set_crystal_color", &"set_glow_strength", &"set_emitting"]:
		_expect(pile.has_method(method_name), "crystal pile exposes %s" % method_name)
	var static_pile := pile.get_node_or_null("StaticPile") as Node2D
	var reflection := pile.get_node_or_null("Reflection") as Polygon2D
	var motes := pile.get_node_or_null("DriftMotes") as GPUParticles2D
	_expect(static_pile != null and static_pile.get_child_count() >= 6, "crystal pile authors a visible settled mound")
	_expect(reflection != null, "crystal pile authors a surface reflection")
	_expect(motes != null and motes.fixed_fps == 12 and not motes.interpolate, "drifting motes use stepped pixel motion")
	if not pile.has_method(&"set_crystal_color") or motes == null:
		return
	pile.call(&"set_crystal_color", Color("ff2e50"))
	_expect(_has_property(pile, &"crystal_color") and (pile.get("crystal_color") as Color).is_equal_approx(Color("ff2e50")), "pile stores runtime crystal color")
	pile.call(&"set_glow_strength", -1.0)
	_expect(_has_property(pile, &"glow_strength") and is_zero_approx(float(pile.get("glow_strength"))), "pile clamps negative glow")
	pile.call(&"set_emitting", false)
	_expect(not motes.emitting, "pile can stop ambient motes")
	pile.call(&"set_emitting", true)
	_expect(motes.emitting, "pile can resume ambient motes")


func _test_shatter_contract() -> void:
	var shatter := _instantiate_scene(SHATTER_SCENE_PATH)
	if shatter == null:
		return
	add_child(shatter)
	await get_tree().process_frame
	_expect(shatter.has_method(&"play_burst"), "shatter scene exposes play_burst")
	var grains := shatter.get_node_or_null("Grains") as GPUParticles2D
	var fragments := shatter.get_node_or_null("Fragments") as GPUParticles2D
	_expect(grains != null and grains.amount >= 24 and grains.amount <= 32, "shatter authors 24-32 grains")
	_expect(fragments != null and fragments.amount >= 5 and fragments.amount <= 7, "shatter authors 5-7 bright fragments")
	if not shatter.has_method(&"play_burst") or grains == null or fragments == null:
		return
	_owned_nodes.erase(shatter)
	shatter.call(&"play_burst", Vector2(240.0, 160.0), Color("20f5d0"), Vector2.RIGHT)
	_expect((shatter as Node2D).global_position == Vector2(240.0, 160.0), "shatter starts at the requested world position")
	_expect(grains.emitting and fragments.emitting, "shatter starts both one-shot particle groups")
	await get_tree().create_timer(1.1).timeout
	_expect(not is_instance_valid(shatter), "shatter automatically frees after its burst")


func _test_workshop_contract() -> void:
	var workshop := _instantiate_scene(WORKSHOP_SCENE_PATH)
	if workshop == null:
		return
	add_child(workshop)
	await get_tree().process_frame
	var piles := workshop.get_node_or_null("Piles")
	var burst_origin := workshop.get_node_or_null("BurstOrigin") as Marker2D
	var controls := workshop.get_node_or_null("UI/BurstControls") as Control
	_expect(piles != null and piles.get_child_count() == 5, "workshop shows all five charged-neon colors")
	_expect(burst_origin != null, "workshop authors a burst preview origin")
	_expect(controls != null and controls.get_child_count() == 5, "workshop provides one burst control per color")


func _instantiate_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads as PackedScene" % path)
	if packed == null:
		return null
	var instance := packed.instantiate()
	_owned_nodes.append(instance)
	return instance


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
