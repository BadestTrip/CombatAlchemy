extends Node

# Responsibility: Verify active combat coordinates brewing input, visibility, and potion ownership.

const COMBAT_SCENE := preload("res://combat/CombatScene.tscn")
const FLASK_VIEW_SCENE := preload("res://combat/ui/FlaskView.tscn")

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_test_input_press_release_and_forced_release()
	_test_scene_authored_flask_feedback()
	await _test_hidden_settling_creates_one_held_potion()
	await _test_clear_cancels_an_active_reaction()
	await _test_pause_freezes_and_resume_requires_fresh_press()
	if _failures.is_empty():
		print("BrewingCombatTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("BrewingCombatTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _test_input_press_release_and_forced_release() -> void:
	var potion_input := PotionInput.new()
	add_child(potion_input)
	var starts := [0]
	var releases := [0]
	potion_input.connect(&"agitation_started", func() -> void: starts[0] += 1)
	potion_input.connect(&"agitation_released", func() -> void: releases[0] += 1)
	_send_action(potion_input, &"mix_potion", true)
	_send_action(potion_input, &"mix_potion", true)
	_expect(starts[0] == 1, "Space press starts agitation once while held")
	_send_action(potion_input, &"mix_potion", false)
	_send_action(potion_input, &"mix_potion", false)
	_expect(releases[0] == 1, "Space release emits once")
	_send_action(potion_input, &"mix_potion", true)
	potion_input.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(releases[0] == 2, "focus loss releases held agitation")
	_send_action(potion_input, &"mix_potion", true)
	potion_input.notification(NOTIFICATION_PAUSED)
	_expect(releases[0] == 3, "pausing releases held agitation")
	_send_action(potion_input, &"mix_potion", true)
	_send_action(potion_input, &"ui_cancel", true)
	_expect(releases[0] == 4, "Escape releases agitation before the pause menu handles it")
	potion_input.queue_free()


func _test_scene_authored_flask_feedback() -> void:
	var flask := FLASK_VIEW_SCENE.instantiate() as FlaskView
	add_child(flask)
	_expect(flask.custom_minimum_size == Vector2(144.0, 190.0), "flask preserves its replacement footprint")
	var success_window := flask.get_node_or_null(^"SuccessWindow") as Line2D
	var current_marker := flask.get_node_or_null(^"CurrentProgressMarker") as Polygon2D
	var predicted_marker := flask.get_node_or_null(^"PredictedSettleMarker") as Polygon2D
	var grains := flask.get_node_or_null(^"Grains") as Node2D
	var foam := flask.get_node_or_null(^"Foam") as Node2D
	_expect(success_window != null, "flask authors a success-range bracket")
	_expect(current_marker != null, "flask authors a current-progress marker")
	_expect(predicted_marker != null, "flask authors a predicted-settle marker")
	_expect(grains != null and grains.get_child_count() >= 4, "flask authors geometric grains")
	_expect(foam != null and foam.get_child_count() >= 3, "flask authors geometric foam")
	if success_window != null and current_marker != null and predicted_marker != null and grains != null and foam != null:
		flask.show_brewing(
			[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE],
			BrewingReaction.State.AGITATING,
			0.5,
			0.8,
			0.75
		)
		_expect(success_window.visible, "brewing shows the broad success window")
		_expect(current_marker.visible and predicted_marker.visible, "brewing shows both progress markers")
		_expect(current_marker.position.y > predicted_marker.position.y, "predicted marker shows progress beyond the current marker")
		_expect(grains.visible and not foam.visible, "agitation shows grains without overreaction foam")
		flask.show_brewing(
			[PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE],
			BrewingReaction.State.COOLDOWN,
			0.92,
			0.0,
			0.92
		)
		_expect(foam.visible, "overreaction cooldown shows foam")
		flask.show_mixed(Color("ff3bd4"))
		_expect(not success_window.visible and not grains.visible and not foam.visible, "prepared view hides brewing feedback")
	flask.queue_free()


func _test_hidden_settling_creates_one_held_potion() -> void:
	var combat := await _new_combat()
	var potion_input := combat.get_node(^"Systems/PotionInput") as PotionInput
	var mixer := combat.get_node(^"Systems/PotionMixer") as PotionMixer
	var reaction := combat.get_node(^"Systems/PotionMixer/BrewingReaction") as BrewingReaction
	var slot := combat.get_node(^"Systems/HeldPotionSlot")
	var mixer_ui := combat.get_node(^"UI/PotionMixerUI") as PotionMixerUI
	_expect(reaction != null, "CombatScene authors a BrewingReaction under PotionMixer")
	if reaction == null:
		combat.queue_free()
		return
	potion_input.mixer_toggle_requested.emit()
	for reagent in [PotionReagent.RED, PotionReagent.RED, PotionReagent.BLUE]:
		potion_input.reagent_requested.emit(reagent)
	potion_input.emit_signal(&"agitation_started")
	reaction.advance(1.35)
	_expect(not (slot.call(&"has_potion") as bool), "agitation alone creates no potion")
	_expect(not mixer_ui.are_reagent_buttons_enabled(), "active brewing disables reagent buttons")
	potion_input.mixer_toggle_requested.emit()
	_expect(not mixer_ui.visible, "Tab hides the mixer while releasing agitation")
	potion_input.mixer_toggle_requested.emit()
	var current_marker := mixer_ui.get_node_or_null(^"FlaskView/CurrentProgressMarker") as Polygon2D
	_expect(mixer_ui.visible, "Tab can reopen a settling mixture")
	_expect(not mixer_ui.are_reagent_buttons_enabled(), "reopened settling mixture keeps reagent edits locked")
	_expect(current_marker != null and current_marker.visible, "reopened settling mixture restores reaction feedback")
	potion_input.mixer_toggle_requested.emit()
	reaction.advance(0.45)
	_expect(slot.call(&"has_potion") as bool, "hidden settling creates a held potion")
	_expect(not mixer_ui.visible, "hidden completion does not reopen the mixer")
	_expect(mixer.get_layers().is_empty(), "successful hidden brewing clears ingredients")
	reaction.advance(1.0)
	_expect(_find_potion_entities(combat).size() == 1, "hidden completion creates exactly one entity")
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
	potion_input.emit_signal(&"agitation_started")
	reaction.advance(0.5)
	potion_input.clear_mixture_requested.emit()
	_expect(mixer.get_layers().is_empty(), "C clears active ingredients")
	_expect(is_zero_approx(reaction.get_progress()), "C clears active reaction progress")
	_expect(reaction.get_state() == BrewingReaction.State.IDLE, "C returns reaction to idle")
	reaction.advance(2.0)
	_expect(not (slot.call(&"has_potion") as bool), "cancelled brewing cannot complete later")
	combat.queue_free()
	await get_tree().process_frame


func _test_pause_freezes_and_resume_requires_fresh_press() -> void:
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
	_expect(reaction.get_state() == BrewingReaction.State.SETTLING, "pause releases active agitation")
	var paused_progress := reaction.get_progress()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(is_equal_approx(reaction.get_progress(), paused_progress), "pause freezes reaction progress")
	get_tree().paused = false
	await get_tree().process_frame
	_expect(reaction.get_progress() > paused_progress, "settling resumes with the scene tree")
	_expect(reaction.get_state() == BrewingReaction.State.SETTLING, "resume does not restart agitation")
	_send_action(potion_input, &"mix_potion", true)
	_expect(reaction.get_state() == BrewingReaction.State.AGITATING, "a fresh Space press resumes agitation")
	_send_action(potion_input, &"mix_potion", false)
	combat.queue_free()
	await get_tree().process_frame


func _new_combat() -> Node:
	var combat := COMBAT_SCENE.instantiate()
	var level_music := combat.get_node_or_null(^"LevelMusic")
	if level_music != null:
		level_music.free()
	add_child(combat)
	await get_tree().process_frame
	return combat


func _send_action(potion_input: PotionInput, action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
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
