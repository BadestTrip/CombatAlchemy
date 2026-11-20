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
	check(entity.get_node_or_null("PerfectQualityAccent") is CanvasItem, "Potion entity authors a perfect-quality accent")
	check(entity.get_node_or_null("PerfectSparks") != null, "Potion entity authors reusable perfect-quality sparks")
	if entity.get_node_or_null("PerfectQualityAccent") is CanvasItem:
		check(not (entity.get_node("PerfectQualityAccent") as CanvasItem).visible, "Neutral potion does not show the perfect-quality accent")
	var perfect_potion := PotionInstance.create(load("res://combat/potions/resources/HealthPotion.tres"), [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE], 2, 1.4)
	var perfect_entity := load("res://combat/potions/PotionEntity.tscn").instantiate() as PotionEntity
	add_child(perfect_entity)
	check(perfect_entity.initialize(perfect_potion, self), "Perfect potion initializes for visual test")
	if perfect_entity.get_node_or_null("PerfectQualityAccent") is CanvasItem:
		check((perfect_entity.get_node("PerfectQualityAccent") as CanvasItem).visible, "Quality plus two shows the persistent bottle accent")
	var perfect_sparks := perfect_entity.get_node_or_null("PerfectSparks")
	if perfect_sparks != null and perfect_sparks.has_method(&"is_emitting"):
		check(perfect_sparks.call(&"is_emitting") as bool, "Quality plus two emits persistent bottle sparks")
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
	flask.show_brewing([PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE], BrewingReaction.State.HEATING, 0.5, 0.5, 0.7, load("res://combat/potions/brewing/SmallFlaskBrewingProfile.tres"), Color("ff3bd4"))
	check(flask.get_node_or_null("CurrentProgressMarker") == null, "Tube01 has no obsolete current marker")
	check(flask.get_node_or_null("PredictedSettleMarker") == null, "Tube01 has no obsolete predicted marker")
	check(not flask.get_node("SuccessWindow").visible, "Normal height keeps the ideal connector inactive")
	check(flask.get_node_or_null("IdealLowerMark") is Line2D and flask.get_node_or_null("IdealUpperMark") is Line2D, "Tube01 authors two ideal-height marks on the glass")
	flask.show_brewing([PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE], BrewingReaction.State.HEATING, 0.75, 0.5, 0.7, load("res://combat/potions/brewing/SmallFlaskBrewingProfile.tres"), Color("ff3bd4"))
	check(flask.get_node("SuccessWindow").visible, "Ideal height connects the marks with a gold cue")
	flask.call("_process", 0.1)
	for i in range(1, 4):
		var layer := flask.get_node("Layer%d" % i) as Polygon2D
		var material := layer.material as ShaderMaterial
		check(layer.texture.resource_path == "res://sprites/potions/tube_01/tube_01_ui_mask_v001.png", "Bubbles use the native Tube01 interior alpha mask")
		check(material.shader.resource_path == "res://combat/ui/TubeLiquid.gdshader", "Bubbles render inside the band-clipping liquid shader")
		check(is_equal_approx(float(material.get_shader_parameter("bubble_power")), 0.5), "Heating drives shader bubbles at selected power")
		check(float(material.get_shader_parameter("band_top")) >= 0.0 and float(material.get_shader_parameter("band_bottom")) <= 1.0, "Bubble clipping bands stay within the native mask")
	for i in range(1, 3):
		var lower = flask.get_node("Layer%d" % i).material as ShaderMaterial
		var upper = flask.get_node("Layer%d" % (i + 1)).material as ShaderMaterial
		check(is_equal_approx(float(lower.get_shader_parameter("band_top")) * 32.0 + float(lower.get_shader_parameter("surface_step")), float(upper.get_shader_parameter("band_bottom")) * 32.0 + float(upper.get_shader_parameter("bottom_step"))), "Moving layers share the same boundary without gaps")
	flask.show_failure()
	await get_tree().create_timer(0.09).timeout
	check(ui_glass.modulate == Color.WHITE, "Failure feedback preserves grayscale palette")
	check(flask.has_method("show_check_feedback"), "Flask exposes immediate pressure-release feedback")
	if flask.has_method("show_check_feedback"):
		for score in [-1, 0]:
			flask.call("show_check_feedback", score)
			check((flask.get_node("CheckPulse") as CanvasItem).visible, "Score %d displays a flask-local pulse" % score)
		flask.call("show_check_feedback", 1)
		check(not (flask.get_node("CheckPulse") as CanvasItem).visible, "Perfect release does not use the rectangular pulse")
		check((flask.get_node("IdealOutlineGlow") as CanvasItem).visible, "Perfect release lights the flask silhouette gold")
		flask.call("show_check_feedback", -1)
		check(not (flask.get_node("IdealOutlineGlow") as CanvasItem).visible, "A later non-perfect release clears an unfinished gold flash")
		var turbulence := flask.get_node("BadTurbulence") as Line2D
		turbulence.position.x = 7.0
		flask.call("show_check_feedback", -1)
		check(is_zero_approx(turbulence.position.x), "Repeated weak feedback restarts its turbulence motion")
	flask.show_ready(Color("ff3bd4"), true)
	check((flask.get_node("IdealOutlineGlow") as CanvasItem).visible, "Perfect prepared potion keeps the flask outline gold")
	var ui_sparks := flask.get_node_or_null("PerfectSparks")
	if ui_sparks != null and ui_sparks.has_method(&"is_emitting"):
		check(ui_sparks.call(&"is_emitting") as bool, "Perfect prepared potion emits configurable UI sparks")
	flask.reset_view()
	check(not flask.get_node("Layer1").visible and not flask.get_node("MixedLiquid").visible, "Reset empties the tube")
	entity.queue_free()
	perfect_entity.queue_free()
	flask.queue_free()
	if failures.is_empty():
		print("PotionVisualTests: PASS")
	else:
		for message in failures:
			push_error(message)
	get_tree().quit(0 if failures.is_empty() else 1)
