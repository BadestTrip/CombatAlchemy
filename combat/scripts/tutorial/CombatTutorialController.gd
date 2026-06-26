extends Node
class_name CombatTutorialController


# This is a hardcoded first-combat tutorial. If we add more tutorials, move
# steps, copy, and target ids to TutorialSequenceData.
enum TutorialStep {
	INACTIVE,
	INTRO,
	CHOOSE_ASHA,
	CHOOSE_VORO,
	CHOOSE_KETH,
	CAST_FIRST_CHANT,
	EXPLAIN_RESULT,
	EXPLAIN_ENEMY_INTENT,
	OPEN_LOG,
	EXPLAIN_LOG,
	OPEN_HISTORY,
	EXPLAIN_HISTORY,
	OPEN_SPELLBOOK,
	EXPLAIN_SPELLBOOK,
	FREE_EXPERIMENT
}


const FIRST_CHANT_KEY: String = "asha_voro_keth"
const FIRST_RESULT_NAME: String = "Razor Comet"
const CONTINUE_PROMPT: String = "\n\nPress Space / Click to continue"

const TEXT_INTRO: String = "This is your first duel.\nYou cast magic by forming three-rune chants."
const TEXT_CHOOSE_ASHA: String = "First chant: ASHA -> VORO -> KETH\nClick ASHA."
const TEXT_CHOOSE_VORO: String = "Good. Now click VORO."
const TEXT_CHOOSE_KETH: String = "Now click KETH."
const TEXT_CAST_FIRST_CHANT: String = "The chant is ready.\nClick Cast."
const TEXT_EXPLAIN_RESULT: String = "Razor Comet is a learned spell.\nKnown rune orders create known results."
const TEXT_EXPLAIN_ENEMY_INTENT: String = "Enemy intent shows what the enemy will do after your chant."
const TEXT_OPEN_LOG: String = "Open Log to read what happened."
const TEXT_EXPLAIN_LOG: String = "The Log records combat events and spell effects."
const TEXT_OPEN_HISTORY: String = "Open History to see chants you tried."
const TEXT_EXPLAIN_HISTORY: String = "History remembers your attempted chants this fight."
const TEXT_OPEN_SPELLBOOK: String = "Open Chants to see learned spells."
const TEXT_EXPLAIN_SPELLBOOK: String = "Discovered spells are listed here."
const TEXT_FREE_EXPERIMENT: String = "Now experiment with any three runes. Good Luck, little one."

const OBJECTIVE_Z_INDEX: int = 20


var ui_controller: CombatUIController
var rune_wheel_controller: RuneWheelController
var round_manager: RoundManager
var tutorial_highlighter: TutorialHighlighter
var objective_label: Label

var _current_step: TutorialStep = TutorialStep.INACTIVE
var _pending_continue_step: TutorialStep = TutorialStep.INACTIVE
var _has_started: bool = false
var _has_finished: bool = false
var _waiting_for_continue: bool = false
var _tutorial_mode_active: bool = false
var _warned_missing_highlighter: bool = false

var _objective_original_state: Dictionary = {}


func _ready() -> void:
	set_process_input(true)
	call_deferred("_initialize")


func _input(event: InputEvent) -> void:
	if not _waiting_for_continue or _has_finished:
		return
	if not _is_continue_event(event):
		return

	var should_block_mouse := _current_step == TutorialStep.INTRO
	var is_mouse_click := event is InputEventMouseButton
	if not is_mouse_click or should_block_mouse:
		get_viewport().set_input_as_handled()

	_advance_from_continue()


func _initialize() -> void:
	_resolve_references()
	if ui_controller == null or round_manager == null:
		push_warning("CombatTutorialController could not find CombatUI or RoundManager.")
		return

	_connect_signals()
	_maybe_start_tutorial()


func _resolve_references() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = owner
	if scene == null:
		return

	ui_controller = scene.find_child("CombatUI", true, false) as CombatUIController
	round_manager = scene.find_child("RoundManager", true, false) as RoundManager
	tutorial_highlighter = (
		scene.find_child("TutorialHighlighter", true, false) as TutorialHighlighter
	)

	if ui_controller != null:
		rune_wheel_controller = ui_controller.rune_wheel_controller
		objective_label = ui_controller.objective_label
	if rune_wheel_controller == null:
		rune_wheel_controller = scene.find_child("RuneWheelRoot", true, false) as RuneWheelController
	if objective_label == null:
		objective_label = scene.find_child("ObjectiveLabel", true, false) as Label


func _connect_signals() -> void:
	if not round_manager.planning_started.is_connected(_on_planning_started):
		round_manager.planning_started.connect(_on_planning_started)
	if not round_manager.selected_runes_changed.is_connected(_on_selected_runes_changed):
		round_manager.selected_runes_changed.connect(_on_selected_runes_changed)
	if not round_manager.chant_cleared.is_connected(_on_chant_cleared):
		round_manager.chant_cleared.connect(_on_chant_cleared)

	if not ui_controller.secondary_panel_opened.is_connected(_on_secondary_panel_opened):
		ui_controller.secondary_panel_opened.connect(_on_secondary_panel_opened)
	if not ui_controller.spell_result_shown.is_connected(_on_spell_result_shown):
		ui_controller.spell_result_shown.connect(_on_spell_result_shown)


func _maybe_start_tutorial() -> void:
	if _has_started or _has_finished or round_manager == null:
		return
	if GameManager.first_combat_tutorial_completed:
		return
	if round_manager.round_number > 1:
		return
	if round_manager.current_state != RoundManager.RoundState.PLANNING:
		return

	_has_started = true
	_enter_tutorial_mode()
	_set_step(TutorialStep.INTRO)


func _enter_tutorial_mode() -> void:
	if _tutorial_mode_active:
		return

	_tutorial_mode_active = true
	if tutorial_highlighter != null:
		tutorial_highlighter.set_overlay_visible(true)
	else:
		_warn_missing_highlighter()
	_store_objective_state()
	_style_objective_for_tutorial()
	if ui_controller != null:
		ui_controller.set_tutorial_objective_active(true)


func _finish_tutorial() -> void:
	_has_finished = true
	GameManager.first_combat_tutorial_completed = true
	_current_step = TutorialStep.INACTIVE
	_waiting_for_continue = false
	_pending_continue_step = TutorialStep.INACTIVE
	if tutorial_highlighter != null:
		tutorial_highlighter.clear_all()
	if ui_controller != null:
		ui_controller.hold_spell_result_banner_for_tutorial(false)
	_restore_objective_state()
	if ui_controller != null:
		ui_controller.set_tutorial_objective_active(false)
		ui_controller.clear_objective_text_override()
	_tutorial_mode_active = false


func _set_step(next_step: TutorialStep) -> void:
	if _current_step == next_step:
		return

	_current_step = next_step
	_waiting_for_continue = false
	_pending_continue_step = TutorialStep.INACTIVE
	if tutorial_highlighter != null:
		tutorial_highlighter.clear_focus()
	_apply_current_step()


func _apply_current_step() -> void:
	match _current_step:
		TutorialStep.INTRO:
			_show_waiting_text(
				TEXT_INTRO,
				TutorialStep.CHOOSE_ASHA
			)
		TutorialStep.CHOOSE_ASHA:
			_show_guidance_text(TEXT_CHOOSE_ASHA)
			_highlight_rune("asha")
		TutorialStep.CHOOSE_VORO:
			_show_guidance_text(TEXT_CHOOSE_VORO)
			_highlight_rune("voro")
		TutorialStep.CHOOSE_KETH:
			_show_guidance_text(TEXT_CHOOSE_KETH)
			_highlight_rune("keth")
		TutorialStep.CAST_FIRST_CHANT:
			_show_guidance_text(TEXT_CAST_FIRST_CHANT)
			_highlight_ui_target("cast_button")
		TutorialStep.EXPLAIN_RESULT:
			ui_controller.hold_spell_result_banner_for_tutorial(true)
			_show_waiting_text(
				TEXT_EXPLAIN_RESULT,
				TutorialStep.EXPLAIN_ENEMY_INTENT
			)
			_highlight_ui_target("spell_result_banner")
		TutorialStep.EXPLAIN_ENEMY_INTENT:
			ui_controller.hold_spell_result_banner_for_tutorial(false)
			_show_waiting_text(
				TEXT_EXPLAIN_ENEMY_INTENT,
				TutorialStep.OPEN_LOG
			)
			_highlight_ui_target("enemy_intent")
		TutorialStep.OPEN_LOG:
			_show_guidance_text(TEXT_OPEN_LOG)
			_highlight_ui_target("combat_log_button")
			if ui_controller.is_secondary_panel_open("log"):
				_set_step(TutorialStep.EXPLAIN_LOG)
		TutorialStep.EXPLAIN_LOG:
			_show_waiting_text(
				TEXT_EXPLAIN_LOG,
				TutorialStep.OPEN_HISTORY
			)
			_highlight_ui_target("combat_log_button")
		TutorialStep.OPEN_HISTORY:
			_show_guidance_text(TEXT_OPEN_HISTORY)
			_highlight_ui_target("cast_history_button")
			if ui_controller.is_secondary_panel_open("history"):
				_set_step(TutorialStep.EXPLAIN_HISTORY)
		TutorialStep.EXPLAIN_HISTORY:
			_show_waiting_text(
				TEXT_EXPLAIN_HISTORY,
				TutorialStep.OPEN_SPELLBOOK
			)
			_highlight_ui_target("cast_history_button")
		TutorialStep.OPEN_SPELLBOOK:
			_show_guidance_text(TEXT_OPEN_SPELLBOOK)
			_highlight_ui_target("spellbook_button")
			if ui_controller.is_secondary_panel_open("chants"):
				_set_step(TutorialStep.EXPLAIN_SPELLBOOK)
		TutorialStep.EXPLAIN_SPELLBOOK:
			_show_waiting_text(
				TEXT_EXPLAIN_SPELLBOOK,
				TutorialStep.FREE_EXPERIMENT
			)
			_highlight_ui_target("spellbook_button")
		TutorialStep.FREE_EXPERIMENT:
			_show_waiting_text(TEXT_FREE_EXPERIMENT, TutorialStep.INACTIVE)
		_:
			pass


func _show_guidance_text(text: String) -> void:
	ui_controller.set_objective_text_override(text)


func _show_waiting_text(text: String, next_step: TutorialStep) -> void:
	_waiting_for_continue = true
	_pending_continue_step = next_step
	ui_controller.set_objective_text_override(text + CONTINUE_PROMPT)


func _advance_from_continue() -> void:
	if not _waiting_for_continue:
		return

	var next_step := _pending_continue_step
	_waiting_for_continue = false
	_pending_continue_step = TutorialStep.INACTIVE
	if next_step == TutorialStep.INACTIVE:
		_finish_tutorial()
	else:
		_set_step(next_step)


func _refresh_first_chant_step() -> void:
	if not _has_started or _has_finished or round_manager == null:
		return
	if round_manager.current_state != RoundManager.RoundState.PLANNING:
		return

	if _slot_symbol_id(0) != "asha":
		_set_step(TutorialStep.CHOOSE_ASHA)
	elif _slot_symbol_id(1) != "voro":
		_set_step(TutorialStep.CHOOSE_VORO)
	elif _slot_symbol_id(2) != "keth":
		_set_step(TutorialStep.CHOOSE_KETH)
	else:
		_set_step(TutorialStep.CAST_FIRST_CHANT)


func _highlight_rune(symbol_id: String) -> void:
	if rune_wheel_controller == null:
		return

	rune_wheel_controller.set_expanded(true)
	var rune_button := rune_wheel_controller.get_rune_button_by_id(symbol_id)
	_focus_target(rune_button)


# The controller only resolves the real target. TutorialHighlighter creates the
# visual proxy above the dim overlay without moving or styling the real control.
func _highlight_ui_target(target_id: String) -> void:
	if ui_controller == null:
		return

	var target := ui_controller.get_tutorial_target(target_id)
	_focus_target(target)


func _focus_target(target: Control) -> void:
	if target == null:
		return
	if tutorial_highlighter == null:
		_warn_missing_highlighter()
		return
	tutorial_highlighter.focus_target(target)


func _warn_missing_highlighter() -> void:
	if _warned_missing_highlighter:
		return
	push_warning(
		"CombatTutorialController found no TutorialHighlighter; visual focus is disabled."
	)
	_warned_missing_highlighter = true


func _store_objective_state() -> void:
	if objective_label == null or not _objective_original_state.is_empty():
		return

	_objective_original_state = {
		"anchor_left": objective_label.anchor_left,
		"anchor_top": objective_label.anchor_top,
		"anchor_right": objective_label.anchor_right,
		"anchor_bottom": objective_label.anchor_bottom,
		"offset_left": objective_label.offset_left,
		"offset_top": objective_label.offset_top,
		"offset_right": objective_label.offset_right,
		"offset_bottom": objective_label.offset_bottom,
		"custom_minimum_size": objective_label.custom_minimum_size,
		"horizontal_alignment": objective_label.horizontal_alignment,
		"vertical_alignment": objective_label.vertical_alignment,
		"autowrap_mode": objective_label.autowrap_mode,
		"z_index": objective_label.z_index,
		"z_as_relative": objective_label.z_as_relative,
		"had_font_color": objective_label.has_theme_color_override("font_color"),
		"font_color": objective_label.get_theme_color("font_color"),
		"had_font_size": objective_label.has_theme_font_size_override("font_size"),
		"font_size": objective_label.get_theme_font_size("font_size")
	}


func _style_objective_for_tutorial() -> void:
	if objective_label == null:
		return

	objective_label.anchor_left = 0.06
	objective_label.anchor_top = 0.22
	objective_label.anchor_right = 0.94
	objective_label.anchor_bottom = 0.46
	objective_label.offset_left = 0.0
	objective_label.offset_top = 0.0
	objective_label.offset_right = 0.0
	objective_label.offset_bottom = 0.0
	objective_label.custom_minimum_size = Vector2(0.0, 140.0)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.z_as_relative = false
	objective_label.z_index = OBJECTIVE_Z_INDEX
	objective_label.add_theme_font_size_override("font_size", 32)
	objective_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.56, 1.0))


func _restore_objective_state() -> void:
	if objective_label == null or _objective_original_state.is_empty():
		return

	objective_label.anchor_left = float(_objective_original_state["anchor_left"])
	objective_label.anchor_top = float(_objective_original_state["anchor_top"])
	objective_label.anchor_right = float(_objective_original_state["anchor_right"])
	objective_label.anchor_bottom = float(_objective_original_state["anchor_bottom"])
	objective_label.offset_left = float(_objective_original_state["offset_left"])
	objective_label.offset_top = float(_objective_original_state["offset_top"])
	objective_label.offset_right = float(_objective_original_state["offset_right"])
	objective_label.offset_bottom = float(_objective_original_state["offset_bottom"])
	objective_label.custom_minimum_size = _objective_original_state["custom_minimum_size"]
	objective_label.horizontal_alignment = int(_objective_original_state["horizontal_alignment"])
	objective_label.vertical_alignment = int(_objective_original_state["vertical_alignment"])
	objective_label.autowrap_mode = int(_objective_original_state["autowrap_mode"])
	objective_label.z_index = int(_objective_original_state["z_index"])
	objective_label.z_as_relative = bool(_objective_original_state["z_as_relative"])

	if bool(_objective_original_state["had_font_color"]):
		objective_label.add_theme_color_override(
			"font_color",
			_objective_original_state["font_color"]
		)
	else:
		objective_label.remove_theme_color_override("font_color")

	if bool(_objective_original_state["had_font_size"]):
		objective_label.add_theme_font_size_override(
			"font_size",
			int(_objective_original_state["font_size"])
		)
	else:
		objective_label.remove_theme_font_size_override("font_size")

	_objective_original_state.clear()


func _is_continue_event(event: InputEvent) -> bool:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT

	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode == KEY_SPACE:
		return true
	if key_event.keycode == KEY_ENTER:
		return true
	if key_event.keycode == KEY_KP_ENTER:
		return true
	if key_event.keycode == KEY_E:
		return true
	return event.is_action_pressed("ui_accept")


func _slot_symbol_id(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= round_manager.selected_runes.size():
		return ""
	var rune := round_manager.selected_runes[slot_index] as SymbolCardData
	if rune == null:
		return ""
	return String(rune.symbol_id).to_lower()


func _is_first_tutorial_chant(result: Dictionary) -> bool:
	return (
		String(result.get("chant_key", "")) == FIRST_CHANT_KEY
		or String(result.get("result_name", "")) == FIRST_RESULT_NAME
	)


func _is_first_chant_guidance_step() -> bool:
	return (
		_current_step == TutorialStep.CHOOSE_ASHA
		or _current_step == TutorialStep.CHOOSE_VORO
		or _current_step == TutorialStep.CHOOSE_KETH
		or _current_step == TutorialStep.CAST_FIRST_CHANT
	)


func _on_planning_started() -> void:
	_maybe_start_tutorial()
	if _has_started and not _has_finished and _is_first_chant_guidance_step():
		_refresh_first_chant_step()


func _on_selected_runes_changed(_selected_runes: Array) -> void:
	if _is_first_chant_guidance_step():
		_refresh_first_chant_step()


func _on_chant_cleared() -> void:
	if _is_first_chant_guidance_step():
		_refresh_first_chant_step()


func _on_spell_result_shown(result: Dictionary) -> void:
	if _current_step != TutorialStep.CAST_FIRST_CHANT:
		return
	if _is_first_tutorial_chant(result):
		_set_step(TutorialStep.EXPLAIN_RESULT)


func _on_secondary_panel_opened(panel_id: String) -> void:
	match _current_step:
		TutorialStep.OPEN_LOG:
			if panel_id == "log":
				_set_step(TutorialStep.EXPLAIN_LOG)
		TutorialStep.OPEN_HISTORY:
			if panel_id == "history":
				_set_step(TutorialStep.EXPLAIN_HISTORY)
		TutorialStep.OPEN_SPELLBOOK:
			if panel_id == "chants":
				_set_step(TutorialStep.EXPLAIN_SPELLBOOK)
		_:
			pass
