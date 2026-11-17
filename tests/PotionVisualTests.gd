extends Node

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _ready() -> void:
	var entity = load("res://combat/potions/PotionEntity.tscn").instantiate()
	add_child(entity)
	var glass = entity.get_node("Outline")
	var liquid = entity.get_node("BottleVisual")
	check(glass is Sprite2D and liquid is Sprite2D, "World bottle must use separate glass and liquid sprites")
	entity.initialize(PotionInstance.create(load("res://combat/potions/resources/DamagePotion.tres"), [PotionReagent.GREEN, PotionReagent.GREEN, PotionReagent.BLUE]), self)
	if glass is Sprite2D:
		check(glass.texture.get_size() == Vector2(8, 20), "World art must be 8x20")
		check(glass.modulate == Color.WHITE, "Potion color must not tint glass")
	var flask := load("res://combat/ui/FlaskView.tscn").instantiate() as FlaskView
	add_child(flask)
	var ui_glass = flask.get_node("GlassOutline")
	check(ui_glass is Sprite2D, "Mixer must use pixel glass")
	if ui_glass is Sprite2D:
		check(ui_glass.texture.get_size() == Vector2(16, 32), "UI art must be 16x32")
	flask.set_layers([PotionReagent.RED, PotionReagent.BLUE])
	check(flask.get_node("Layer1").visible and flask.get_node("Layer2").visible and not flask.get_node("Layer3").visible, "Layers preserve insertion count")
	check(flask.get_node("Layer1").color == PotionReagent.get_color(PotionReagent.RED), "Bottom layer preserves reagent color")
	check(flask.get_node("Layer1").material is ShaderMaterial, "Liquid must be clipped to sprite interior")
	flask.show_brewing([PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE], BrewingReaction.State.AGITATING, 0.5, 1.0, 0.7)
	flask.call("_process", 0.1)
	for i in range(1, 3):
		var lower = flask.get_node("Layer%d" % i).material as ShaderMaterial
		var upper = flask.get_node("Layer%d" % (i + 1)).material as ShaderMaterial
		check(is_equal_approx(float(lower.get_shader_parameter("band_top")) * 32.0 + float(lower.get_shader_parameter("surface_step")), float(upper.get_shader_parameter("band_bottom")) * 32.0 + float(upper.get_shader_parameter("bottom_step"))), "Moving layers share the same boundary without gaps")
	flask.show_failure()
	await get_tree().create_timer(0.09).timeout
	check(ui_glass.modulate == Color.WHITE, "Failure feedback preserves grayscale palette")
	flask.reset_view()
	check(not flask.get_node("Layer1").visible and not flask.get_node("MixedLiquid").visible, "Reset empties the tube")
	entity.queue_free()
	flask.queue_free()
	if failures.is_empty():
		print("PotionVisualTests: PASS")
	else:
		for message in failures:
			push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)
