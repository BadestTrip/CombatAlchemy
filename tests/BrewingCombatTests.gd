extends Node

# Responsibility: Verify active combat coordinates brewing input, visibility, and potion ownership.

const COMBAT_SCENE := preload("res://combat/CombatScene.tscn")
const FLASK_VIEW_SCENE := preload("res://combat/ui/FlaskView.tscn")

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_test_input_distinct_presses_and_key_release()
	_test_scene_authored_flask_feedback()
	_test_feedback_tween_lifecycle()
	await _test_hidden_brewing_suspends_until_reopened()
	await _test_clear_cancels_an_active_reaction()
	await _test_pause_and_focus_freeze_without_releasing_pressure()
	await _test_heat_keys_and_slider()
	await _test_independent_fire_lifecycle()
	_test_high_heat_burner_and_feedback_contracts()
	if _failures.is_empty():
		print("BrewingCombatTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("BrewingCombatTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _test_feedback_tween_lifecycle() -> void:
	var ui := load("res://combat/ui/PotionMixerUI.tscn").instantiate() as PotionMixerUI
	add_child(ui)
	ui.set_open(true)
	ui.show_check_result(0, 1)
	var first := ui.get("_feedback_tween") as Tween
	ui.set_open(false)
	_expect(not first.is_running(), "hiding mixer pauses unfinished feedback")
	ui.set_open(true)
	_expect(first.is_running() and ui.get("_feedback_tween") == first, "reopening resumes the same feedback tween")
	first.custom_step(2.0)
	_expect(ui.get("_feedback_tween") == null, "completion immediately clears feedback tween reference")
	ui.show_brewing([PotionReagent.RED], BrewingReaction.State.HEATING, 0.5, 0.5, 0.5)
	_expect(not ui.get_node("CheckFeedback").visible, "next brewing update cannot revive finished feedback")
	ui.show_check_result(1, 0)
	_expect(ui.get("_feedback_tween") != first and ui.get_node("CheckFeedback").visible, "second check creates fresh feedback")
	ui.free()
	var flask := FLASK_VIEW_SCENE.instantiate() as FlaskView
	add_child(flask)
	flask.show_failure()
	var shake := flask.get("_active_tween") as Tween
	shake.custom_step(1.0)
	_expect(flask.get("_active_tween") == null, "completed flask shake clears its tween reference")
	flask.set_animation_suspended(true)
	flask.set_animation_suspended(false)
	flask.free()


func _test_input_distinct_presses_and_key_release() -> void:
	var potion_input := PotionInput.new()
	add_child(potion_input)
	var presses := [0]
	potion_input.connect(&"mix_pressed", func() -> void: presses[0] += 1)
	_send_action(potion_input, &"mix_potion", true)
	_send_action(potion_input, &"mix_potion", true)
	_send_key(potion_input, KEY_SPACE, true, true)
	_expect(presses[0] == 1, "held Space and keyboard echo emit only one mix press")
	_send_action(potion_input, &"mix_potion", false)
	_send_action(potion_input, &"mix_potion", false)
	_expect(presses[0] == 1, "Space key release emits no brewing request")
	_send_action(potion_input, &"mix_potion", true)
	_expect(presses[0] == 2, "a distinct second Space press emits one brewing request")
	potion_input.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	potion_input.notification(NOTIFICATION_PAUSED)
	_send_action(potion_input, &"ui_cancel", true)
	_expect(presses[0] == 2, "focus loss, pause, and Escape never synthesize a pressure release")
	potion_input.queue_free()


func _test_scene_authored_flask_feedback() -> void:
	var flask := FLASK_VIEW_SCENE.instantiate() as FlaskView
	add_child(flask)
	_expect(flask.custom_minimum_size == Vector2(144.0, 190.0), "flask preserves its replacement footprint")
	var success_window := flask.get_node_or_null(^"SuccessWindow") as Line2D
	var lower_mark := flask.get_node_or_null(^"IdealLowerMark") as Line2D
	var upper_mark := flask.get_node_or_null(^"IdealUpperMark") as Line2D
	var current_marker := flask.get_node_or_null(^"CurrentProgressMarker") as Polygon2D
	var predicted_marker := flask.get_node_or_null(^"PredictedSettleMarker") as Polygon2D
	_expect(success_window != null, "flask authors an ideal-zone connector on the glass")
	_expect(lower_mark != null and upper_mark != null, "flask authors direct lower and upper ideal marks")
	_expect(current_marker == null, "flask removes the obsolete current-progress marker")
	_expect(predicted_marker == null, "flask removes the obsolete predicted-settle marker")
	if success_window != null:
		flask.show_brewing(
			[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE],
			BrewingReaction.State.HEATING,
			0.5,
			0.8,
			0.75
		)
		_expect(not success_window.visible, "normal heating does not show the gold ideal cue")
		_expect(lower_mark != null and lower_mark.visible and upper_mark.visible, "heating shows both target marks directly on the glass")
		flask.show_brewing(
			[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE],
			BrewingReaction.State.HEATING,
			0.65,
			0.8,
			0.75,
			load("res://combat/potions/brewing/SmallFlaskBrewingProfile.tres")
		)
		_expect(success_window.visible, "inclusive ideal boundary lights the gold connector")
		_expect(flask.call(&"is_ideal_cue_active") as bool, "ideal cue reports the exact scoring state")
		for layer_name in [^"Layer1", ^"Layer2", ^"Layer3"]:
			var layer := flask.get_node(layer_name) as Polygon2D
			var material := layer.material as ShaderMaterial
			_expect(material != null and material.shader != null, "boiling liquid uses a clipping shader")
			_expect(layer.texture != null and layer.texture.resource_path == "res://sprites/potions/tube_01/tube_01_ui_mask_v001.png", "boiling effects share the Tube01 interior mask")
			if material != null:
				_expect(is_equal_approx(float(material.get_shader_parameter("bubble_power")), 0.8), "masked shader bubbles follow heating power")
		for effect_path in [^"Grains", ^"Foam"]:
			var old_effect := flask.get_node_or_null(effect_path) as CanvasItem
			_expect(old_effect == null or not old_effect.visible, "unmasked geometric effects stay inactive")
		flask.show_brewing(
			[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE],
			BrewingReaction.State.RESETTING,
			0.92,
			0.0,
			0.92
		)
		_expect(not success_window.visible, "pressure reset hides the actionable ideal cue")
		_expect(lower_mark != null and not lower_mark.visible and not upper_mark.visible, "pressure reset hides target marks")
		_expect(is_zero_approx(float((flask.get_node(^"Layer1").material as ShaderMaterial).get_shader_parameter("bubble_power"))), "pressure reset stops heating bubbles")
		flask.show_mixed(Color("ff3bd4"))
		_expect(not success_window.visible, "prepared view hides the pressure window")
	flask.queue_free()


func _test_hidden_brewing_suspends_until_reopened() -> void:
	var combat := await _new_combat()
	var potion_input := combat.get_node(^"Systems/PotionInput") as PotionInput
	var mixer := combat.get_node(^"Systems/PotionMixer") as PotionMixer
	var reaction := combat.get_node(^"Systems/PotionMixer/BrewingReaction") as BrewingReaction
	var slot := combat.get_node(^"Systems/HeldPotionSlot")
	var mixer_ui := combat.get_node(^"UI/PotionMixerUI") as PotionMixerUI
	_expect(mixer_ui.get_node_or_null(^"RedCount") is Label, "mixer authors a red availability label")
	_expect(mixer_ui.get_node_or_null(^"GreenCount") is Label, "mixer authors a green availability label")
	_expect(mixer_ui.get_node_or_null(^"BlueCount") is Label, "mixer authors a blue availability label")
	_expect((mixer_ui.get_node(^"RedCount") as Label).text == "100", "mixer shows available red stock")
	_expect(reaction != null, "CombatScene authors a BrewingReaction under PotionMixer")
	if reaction == null:
		combat.queue_free()
		return
	potion_input.mixer_toggle_requested.emit()
	for reagent in [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	_send_action(potion_input, &"mix_potion", true)
	reaction.advance(0.55 / 0.375)
	_send_action(potion_input, &"mix_potion", true)
	_send_key(potion_input, KEY_SPACE, true, true)
	_expect(reaction.get_results().is_empty(), "repeated held Space cannot release the first pressure check")
	_send_action(potion_input, &"mix_potion", false)
	_expect(reaction.get_state() == BrewingReaction.State.HEATING, "Space key-up leaves the reaction heating")
	_expect(not (slot.call(&"has_potion") as bool), "heating alone creates no potion")
	_expect(not mixer_ui.are_reagent_buttons_enabled(), "active brewing disables reagent buttons")
	var hidden_height := reaction.get_progress()
	var hidden_blend := mixer.get_blend_progress()
	potion_input.mixer_toggle_requested.emit()
	_expect(not mixer_ui.visible, "Tab hides the active mixer")
	reaction.advance(5.0)
	_expect(is_equal_approx(reaction.get_progress(), hidden_height), "hidden mixer freezes pressure height")
	_expect(is_equal_approx(mixer.get_blend_progress(), hidden_blend), "hidden mixer freezes blend progress")
	_expect(reaction.get_results().is_empty(), "Tab does not score a pressure release")
	_expect(not (slot.call(&"has_potion") as bool), "hidden heating cannot create a potion")
	potion_input.mixer_toggle_requested.emit()
	_expect(mixer_ui.visible, "Tab reopens the suspended mixture")
	_expect(not mixer_ui.are_reagent_buttons_enabled(), "reopened heating keeps ingredient edits locked")
	_press_mix(potion_input)
	_expect(reaction.get_results().size() == 1, "second distinct Space press releases the first check")
	_expect(not (slot.call(&"has_potion") as bool), "first release does not create a held potion")
	potion_input.mixer_toggle_requested.emit()
	var reset_height := reaction.get_progress()
	reaction.advance(5.0)
	_expect(reaction.get_state() == BrewingReaction.State.RESETTING, "Tab also suspends pressure resetting")
	_expect(is_equal_approx(reaction.get_progress(), reset_height), "hidden pressure reset does not advance")
	potion_input.mixer_toggle_requested.emit()
	reaction.advance(0.22)
	reaction.advance(0.55 / 0.375)
	_press_mix(potion_input)
	reaction.advance(0.22)
	_expect(slot.call(&"has_potion") as bool, "third distinct Space press completes one held potion")
	_expect(mixer.get_layers().is_empty(), "successful two-release brewing clears ingredients")
	reaction.advance(1.0)
	_press_mix(potion_input)
	_expect(_find_potion_entities(combat).size() == 1, "extra Space after completion cannot duplicate the physical bottle")
	combat.queue_free()
	await get_tree().process_frame


func _test_clear_cancels_an_active_reaction() -> void:
	var combat := await _new_combat()
	var potion_input := combat.get_node(^"Systems/PotionInput") as PotionInput
	var mixer := combat.get_node(^"Systems/PotionMixer") as PotionMixer
	var reaction := combat.get_node(^"Systems/PotionMixer/BrewingReaction") as BrewingReaction
	var slot := combat.get_node(^"Systems/HeldPotionSlot")
	potion_input.mixer_toggle_requested.emit()
	for reagent in [PotionReagent.GREEN, PotionReagent.GREEN, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	potion_input.emit_signal(&"mix_pressed")
	reaction.advance(0.5)
	potion_input.clear_mixture_requested.emit()
	_expect(mixer.get_layers().is_empty(), "C clears active ingredients")
	_expect(is_zero_approx(reaction.get_progress()), "C clears active reaction progress")
	_expect(reaction.get_state() == BrewingReaction.State.IDLE, "C returns reaction to idle")
	reaction.advance(2.0)
	_expect(not (slot.call(&"has_potion") as bool), "cancelled brewing cannot complete later")
	combat.queue_free()
	await get_tree().process_frame


func _test_pause_and_focus_freeze_without_releasing_pressure() -> void:
	var combat := await _new_combat()
	combat.process_mode = Node.PROCESS_MODE_PAUSABLE
	var potion_input := combat.get_node(^"Systems/PotionInput") as PotionInput
	var reaction := combat.get_node(^"Systems/PotionMixer/BrewingReaction") as BrewingReaction
	potion_input.mixer_toggle_requested.emit()
	for reagent in [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	_send_action(potion_input, &"mix_potion", true)
	reaction.advance(0.5)
	get_tree().paused = true
	await get_tree().process_frame
	_expect(reaction.get_state() == BrewingReaction.State.HEATING, "pause preserves heating without releasing pressure")
	var paused_progress := reaction.get_progress()
	var paused_results := reaction.get_results().duplicate()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(is_equal_approx(reaction.get_progress(), paused_progress), "pause freezes reaction progress")
	_expect(reaction.get_results() == paused_results, "pause does not score a release")
	get_tree().paused = false
	await get_tree().process_frame
	_expect(reaction.get_state() == BrewingReaction.State.HEATING, "resume preserves the active pressure check")
	reaction.advance(0.1)
	_expect(reaction.get_progress() > paused_progress, "heating resumes with the scene tree")
	_send_action(potion_input, &"mix_potion", false)
	combat.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var unfocused_progress := reaction.get_progress()
	reaction.advance(2.0)
	_expect(is_equal_approx(reaction.get_progress(), unfocused_progress), "focus loss freezes the reaction")
	_expect(reaction.get_results() == paused_results, "focus loss does not release pressure")
	combat.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	reaction.advance(0.1)
	_expect(reaction.get_progress() > unfocused_progress, "focus restoration resumes heating")
	# Restoring focus must not override the independent hidden-mixer suspension.
	potion_input.mixer_toggle_requested.emit()
	combat.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	combat.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var hidden_progress := reaction.get_progress()
	get_tree().paused = true
	await get_tree().process_frame
	get_tree().paused = false
	await get_tree().process_frame
	reaction.advance(2.0)
	_expect(is_equal_approx(reaction.get_progress(), hidden_progress), "pause and focus restoration cannot resume a hidden mixer")
	combat.queue_free()
	await get_tree().process_frame


func _test_heat_keys_and_slider() -> void:
	var combat := await _new_combat()
	var potion_input := combat.get_node(^"Systems/PotionInput") as PotionInput
	var mixer := combat.get_node(^"Systems/PotionMixer") as PotionMixer
	var reaction := mixer.get_node(^"BrewingReaction") as BrewingReaction
	var mixer_ui := combat.get_node(^"UI/PotionMixerUI") as Control
	var slider := combat.get_node_or_null(^"UI/PotionMixerUI/HeatControl/Slider") as HSlider
	_expect(slider != null, "CombatScene authors UI/PotionMixerUI/HeatControl/Slider")
	_expect(is_equal_approx(mixer_ui.custom_minimum_size.y, 290.0), "mixer reserves the approved 290-pixel height")
	_expect(is_equal_approx(mixer.get_brewing_power(), 0.5), "heat power defaults to one half")
	potion_input.mixer_toggle_requested.emit()
	_send_key(potion_input, KEY_Z, true)
	_send_key(potion_input, KEY_Z, false)
	_expect(mixer.get_brewing_power() < 0.5, "Z lowers heat power")
	var lower_power := mixer.get_brewing_power()
	_send_key(potion_input, KEY_X, true)
	_send_key(potion_input, KEY_X, false)
	_expect(mixer.get_brewing_power() > lower_power, "X raises heat power")
	if slider != null:
		_expect(is_zero_approx(slider.min_value) and is_equal_approx(slider.max_value, 1.0), "heat slider uses normalized zero-to-one power")
		_expect(is_equal_approx(slider.value, mixer.get_brewing_power()), "keyboard heat updates the slider")
		slider.value = 0.8
		_expect(is_equal_approx(mixer.get_brewing_power(), 0.8), "slider changes mixer heat power")
		_expect(is_equal_approx(reaction.get_heat_power(), 0.8), "slider changes simulation heat power")
	for reagent in [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	_press_mix(potion_input)
	if slider != null:
		slider.value = 0.0
		reaction.advance(1.0)
		_expect(is_zero_approx(reaction.get_progress()), "zero heat stops pressure rise without releasing")
		slider.value = 1.0
		reaction.advance(0.5)
		_expect(is_equal_approx(reaction.get_progress(), 0.375), "full slider power applies the configured rise rate")
	_expect(not (mixer_ui as PotionMixerUI).are_reagent_buttons_enabled(), "heat changes do not unlock brewing edits")
	combat.queue_free()
	await get_tree().process_frame


func _test_independent_fire_lifecycle() -> void:
	var combat := await _new_combat()
	var potion_input := combat.get_node(^"Systems/PotionInput") as PotionInput
	var reaction := combat.get_node(^"Systems/PotionMixer/BrewingReaction") as BrewingReaction
	var mixer_ui := combat.get_node(^"UI/PotionMixerUI") as PotionMixerUI
	_expect(mixer_ui.has_signal(&"fire_toggle_requested"), "mixer UI exposes a fire-toggle intent")
	_expect(mixer_ui.has_method(&"is_fire_active"), "mixer UI exposes current fire state")
	if not mixer_ui.has_signal(&"fire_toggle_requested") or not mixer_ui.has_method(&"is_fire_active"):
		combat.queue_free()
		await get_tree().process_frame
		return
	potion_input.mixer_toggle_requested.emit()
	_expect(not (mixer_ui.call(&"is_fire_active") as bool), "fire starts off outside brewing")
	for reagent in [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	_press_mix(potion_input)
	_expect(mixer_ui.call(&"is_fire_active") as bool, "valid brewing auto-lights an extinguished burner")
	var before_off := reaction.get_progress()
	mixer_ui.emit_signal(&"fire_toggle_requested")
	_expect(not (mixer_ui.call(&"is_fire_active") as bool), "fire button can extinguish an active brew")
	reaction.advance(1.0)
	_expect(is_equal_approx(reaction.get_progress(), before_off), "extinguished fire freezes liquid height")
	mixer_ui.emit_signal(&"fire_toggle_requested")
	reaction.advance(0.2)
	_expect(reaction.get_progress() > before_off, "relighting resumes the same pressure check")
	_complete_active_brew(reaction, potion_input)
	_expect(mixer_ui.call(&"is_fire_active") as bool, "manual override during brewing preserves the player's final fire state")
	combat.queue_free()
	await get_tree().process_frame

	combat = await _new_combat()
	potion_input = combat.get_node(^"Systems/PotionInput") as PotionInput
	reaction = combat.get_node(^"Systems/PotionMixer/BrewingReaction") as BrewingReaction
	mixer_ui = combat.get_node(^"UI/PotionMixerUI") as PotionMixerUI
	potion_input.mixer_toggle_requested.emit()
	for reagent in [PotionReagent.GREEN, PotionReagent.GREEN, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	_press_mix(potion_input)
	_complete_active_brew(reaction, potion_input)
	_expect(not (mixer_ui.call(&"is_fire_active") as bool), "untouched auto-lit fire restores its previous off state")
	combat.queue_free()
	await get_tree().process_frame

	combat = await _new_combat()
	potion_input = combat.get_node(^"Systems/PotionInput") as PotionInput
	reaction = combat.get_node(^"Systems/PotionMixer/BrewingReaction") as BrewingReaction
	mixer_ui = combat.get_node(^"UI/PotionMixerUI") as PotionMixerUI
	potion_input.mixer_toggle_requested.emit()
	mixer_ui.emit_signal(&"fire_toggle_requested")
	for reagent in [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	_press_mix(potion_input)
	_complete_active_brew(reaction, potion_input)
	_expect(mixer_ui.call(&"is_fire_active") as bool, "fire lit manually before brewing remains lit afterward")
	combat.queue_free()
	await get_tree().process_frame


func _test_high_heat_burner_and_feedback_contracts() -> void:
	var burner_scene := load("res://combat/ui/AlchemicalBurner.tscn") as PackedScene
	var burner := burner_scene.instantiate() as AlchemicalBurner
	add_child(burner)
	var flame := burner.get_node(^"Flame") as AnimatedSprite2D
	var high_glow := burner.get_node_or_null(^"HighHeatGlow") as CanvasItem
	var gold_sparks := burner.get_node_or_null(^"GoldSparks")
	_expect(high_glow != null, "burner authors a localized high-heat glow")
	_expect(gold_sparks != null and gold_sparks.has_method(&"is_emitting"), "burner authors reusable configurable gold sparks")
	burner.set_active(true)
	burner.set_heat_power(0.9)
	var normal_scale := flame.scale
	if gold_sparks != null and gold_sparks.has_method(&"is_emitting"):
		_expect(not (gold_sparks.call(&"is_emitting") as bool), "burner sparks remain off at exactly 90 percent")
	burner.set_heat_power(0.91)
	_expect(flame.scale.x > normal_scale.x and flame.scale.y > normal_scale.y, "power above 90 percent visibly enlarges the flame")
	_expect(flame.modulate == Color.WHITE, "high heat preserves the white-cyan flame instead of multiplying it green")
	if high_glow != null:
		_expect(high_glow.visible, "high heat enables its localized glow")
		_expect((high_glow as Polygon2D).color.r > (high_glow as Polygon2D).color.b, "high-heat light shifts toward gold")
	if gold_sparks != null and gold_sparks.has_method(&"is_emitting"):
		_expect(gold_sparks.call(&"is_emitting") as bool, "burner sparks emit strictly above 90 percent")
		var particles := gold_sparks.get_node_or_null(^"Sparks") as GPUParticles2D
		_expect(particles != null and particles.amount == 4, "burner spark profile caps visible particles at four")
		burner.set_active(false)
		_expect(not (gold_sparks.call(&"is_emitting") as bool), "extinguishing the burner stops new sparks")
	burner.free()

	var combat_scene := COMBAT_SCENE.instantiate()
	var feedback := combat_scene.get_node_or_null(^"UI/PotionMixerUI/BrewingAudioFeedback")
	_expect(feedback != null, "combat authors scene-backed brewing audio feedback")
	if feedback != null:
		for player_name in [^"FireLoop", ^"BoilLoop", ^"ReleaseBad", ^"ReleaseNormal", ^"ReleasePerfect", ^"PerfectBrew"]:
			var player := feedback.get_node_or_null(player_name) as AudioStreamPlayer
			_expect(player != null and player.stream != null and player.bus == &"SFX", "%s uses a replaceable SFX stream" % player_name)
	combat_scene.free()


func _complete_active_brew(reaction: BrewingReaction, potion_input: PotionInput) -> void:
	var rate := reaction.profile.rise_rate * reaction.get_heat_power()
	if reaction.get_progress() < 0.7:
		reaction.advance((0.7 - reaction.get_progress()) / rate)
	_press_mix(potion_input)
	reaction.advance(reaction.profile.reset_duration)
	rate = reaction.profile.rise_rate * reaction.get_heat_power()
	reaction.advance(0.7 / rate)
	_press_mix(potion_input)
	reaction.advance(reaction.profile.reset_duration)


func _new_combat() -> Node:
	GameManager.set_player_profile_for_testing(_new_stocked_profile())
	var combat := COMBAT_SCENE.instantiate()
	var level_music := combat.get_node_or_null(^"LevelMusic")
	if level_music != null:
		level_music.free()
	add_child(combat)
	await get_tree().process_frame
	return combat

func _new_stocked_profile() -> PlayerProfile:
	return PlayerProfile.create_in_memory({PotionReagent.RED: 100, PotionReagent.GREEN: 100, PotionReagent.BLUE: 100})


func _send_action(potion_input: PotionInput, action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	potion_input._unhandled_input(event)


func _press_mix(potion_input: PotionInput) -> void:
	_send_action(potion_input, &"mix_potion", true)
	_send_action(potion_input, &"mix_potion", false)


func _send_key(potion_input: PotionInput, key: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	potion_input._unhandled_input(event)


func _find_potion_entities(root: Node) -> Array[PotionEntity]:
	var entities: Array[PotionEntity] = []
	_collect_potion_entities(root, entities)
	return entities


func _collect_potion_entities(node: Node, entities: Array[PotionEntity]) -> void:
	for child in node.get_children():
		if child is PotionEntity:
			entities.append(child as PotionEntity)
		_collect_potion_entities(child, entities)


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
