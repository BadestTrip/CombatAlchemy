extends Node
class_name CombatTutorialController


# First-combat tutorial presentation state. Gameplay stays in RoundManager and
# ChantResolver; this controller only gates what the player sees next.
enum TutorialStep {
	INACTIVE,
	INTRO,
	OPEN_RUNES,
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
const OBJECTIVE_Z_INDEX: int = 20
const OBJECTIVE_CANVAS_LAYER: int = 60

const CONTROLLED_TARGET_IDS = [
	"rune_toggle_button",
	"rune_palette",
	"chant_slots",
	"chant_preview",
	"circle_actions",
	"cast_button",
	"clear_button",
	"enemy_intent",
	"combat_log_button",
	"cast_history_button",
	"spellbook_button",
	"debug_chants_button",
	"spell_result_banner",
	"log_panel",
	"cast_history_panel",
	"spellbook_panel",
	"debug_chants_panel",
	"spell_discovery_popup"
]


@export var presentation: CombatTutorialPresentationData


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

var _fallback_presentation: CombatTutorialPresentationData
var _objective_original_state: Dictionary = {}
var _ui_original_state: Dictionary = {}
var _tutorial_controls: Array[Control] = []


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

	if (
		rune_wheel_controller != null
		and not rune_wheel_controller.wheel_expanded.is_connected(_on_wheel_expanded)
	):
		rune_wheel_controller.wheel_expanded.connect(_on_wheel_expanded)


func _maybe_start_tutorial() -> void:
	if _has_started or _has_finished or round_manager == null:
		return
	if GameManager.first_combat_tutorial_completed:
		return
	if not _is_tutorial_encounter():
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

	var settings := _get_presentation()
	_tutorial_mode_active = true
	_store_ui_state()

	if tutorial_highlighter != null:
		tutorial_highlighter.apply_presentation(settings)
		tutorial_highlighter.set_overlay_visible(true)
	else:
		_warn_missing_highlighter()

	_store_objective_state()
	_style_objective_for_tutorial()
	if ui_controller != null:
		ui_controller.set_tutorial_objective_active(true)

	if settings.start_rune_wheel_retracted and rune_wheel_controller != null:
		rune_wheel_controller.set_expanded(false, false)
	_show_only_tutorial_targets([])


func _finish_tutorial() -> void:
	var settings := _get_presentation()
	_has_finished = true
	GameManager.first_combat_tutorial_completed = true
	_current_step = TutorialStep.INACTIVE
	_waiting_for_continue = false
	_pending_continue_step = TutorialStep.INACTIVE

	if tutorial_highlighter != null:
		tutorial_highlighter.clear_all()
	if ui_controller != null:
		ui_controller.hold_spell_result_banner_for_tutorial(false)
		ui_controller.set_tutorial_objective_active(false)
		ui_controller.clear_objective_text_override()

	_restore_objective_state()
	if settings.reveal_full_ui_after_tutorial:
		_restore_ui_state()
	else:
		_hide_all_tutorial_controls()
	if settings.start_rune_wheel_retracted and rune_wheel_controller != null:
		rune_wheel_controller.set_expanded(false, false)
	if ui_controller != null:
		ui_controller.refresh_all()
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
	var settings := _get_presentation()
	match _current_step:
		TutorialStep.INTRO:
			_show_only_tutorial_targets([])
			_show_waiting_text(settings.text_intro, TutorialStep.OPEN_RUNES)
		TutorialStep.OPEN_RUNES:
			_show_only_tutorial_targets(["rune_toggle_button"])
			if settings.start_rune_wheel_retracted and rune_wheel_controller != null:
				rune_wheel_controller.set_expanded(false, false)
			_show_guidance_text(settings.text_open_runes)
			_highlight_ui_target("rune_toggle_button")
		TutorialStep.CHOOSE_ASHA:
			_show_only_tutorial_targets(_rune_selection_targets())
			_show_guidance_text(settings.text_choose_asha)
			_highlight_rune("asha")
		TutorialStep.CHOOSE_VORO:
			_show_only_tutorial_targets(_rune_selection_targets())
			_show_guidance_text(settings.text_choose_voro)
			_highlight_rune("voro")
		TutorialStep.CHOOSE_KETH:
			_show_only_tutorial_targets(_rune_selection_targets())
			_show_guidance_text(settings.text_choose_keth)
			_highlight_rune("keth")
		TutorialStep.CAST_FIRST_CHANT:
			_show_only_tutorial_targets(["chant_slots", "chant_preview", "circle_actions", "cast_button"])
			_show_guidance_text(settings.text_cast)
			_highlight_ui_target("cast_button")
		TutorialStep.EXPLAIN_RESULT:
			ui_controller.hold_spell_result_banner_for_tutorial(true)
			_show_only_tutorial_targets(["spell_result_banner"])
			_show_waiting_text(settings.text_result, TutorialStep.EXPLAIN_ENEMY_INTENT)
			_highlight_ui_target("spell_result_banner")
		TutorialStep.EXPLAIN_ENEMY_INTENT:
			ui_controller.hold_spell_result_banner_for_tutorial(false)
			_show_only_tutorial_targets(["enemy_intent"])
			_show_waiting_text(settings.text_enemy_intent, TutorialStep.OPEN_LOG)
			_highlight_ui_target("enemy_intent")
		TutorialStep.OPEN_LOG:
			_show_only_tutorial_targets(["combat_log_button"])
			_show_guidance_text(settings.text_open_log)
			_highlight_ui_target("combat_log_button")
			if ui_controller.is_secondary_panel_open("log"):
				_set_step(TutorialStep.EXPLAIN_LOG)
		TutorialStep.EXPLAIN_LOG:
			_show_only_tutorial_targets(["combat_log_button", "log_panel"])
			_show_waiting_text(settings.text_explain_log, TutorialStep.OPEN_HISTORY)
			_highlight_ui_target("log_panel")
		TutorialStep.OPEN_HISTORY:
			_show_only_tutorial_targets(["cast_history_button"])
			_show_guidance_text(settings.text_open_history)
			_highlight_ui_target("cast_history_button")
			if ui_controller.is_secondary_panel_open("history"):
				_set_step(TutorialStep.EXPLAIN_HISTORY)
		TutorialStep.EXPLAIN_HISTORY:
			_show_only_tutorial_targets(["cast_history_button", "cast_history_panel"])
			_show_waiting_text(settings.text_explain_history, TutorialStep.OPEN_SPELLBOOK)
			_highlight_ui_target("cast_history_panel")
		TutorialStep.OPEN_SPELLBOOK:
			_show_only_tutorial_targets(["spellbook_button"])
			_show_guidance_text(settings.text_open_spellbook)
			_highlight_ui_target("spellbook_button")
			if ui_controller.is_secondary_panel_open("chants"):
				_set_step(TutorialStep.EXPLAIN_SPELLBOOK)
		TutorialStep.EXPLAIN_SPELLBOOK:
			_show_only_tutorial_targets(["spellbook_button", "spellbook_panel"])
			_show_waiting_text(settings.text_explain_spellbook, TutorialStep.FREE_EXPERIMENT)
			_highlight_ui_target("spellbook_panel")
		TutorialStep.FREE_EXPERIMENT:
			_show_only_tutorial_targets([])
			_show_waiting_text(settings.text_free_experiment, TutorialStep.INACTIVE)
		_:
			pass


func _show_guidance_text(text: String) -> void:
	if ui_controller == null:
		return
	ui_controller.set_objective_text_override(text)


func _show_waiting_text(text: String, next_step: TutorialStep) -> void:
	if ui_controller == null:
		return
	var prompt := _get_presentation().continue_prompt.strip_edges()
	var full_text := text
	if not prompt.is_empty():
		full_text += "\n\n" + prompt
	_waiting_for_continue = true
	_pending_continue_step = next_step
	ui_controller.set_objective_text_override(full_text)


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


func _show_only_tutorial_targets(target_ids: Array) -> void:
	var settings := _get_presentation()
	if not settings.hide_normal_ui_during_tutorial:
		_sync_rune_palette_for_targets(target_ids)
		return

	_collect_tutorial_controls()
	_hide_all_tutorial_controls()
	_sync_rune_palette_for_targets(target_ids)

	for target_id_variant: Variant in target_ids:
		var target_id := String(target_id_variant)
		if not _should_control_target_id(target_id):
			continue
		var control := _target_control(target_id)
		if control == null:
			continue
		_show_control_and_parents(control)
		var button := control as BaseButton
		if button != null:
			button.disabled = false

	if ui_controller != null:
		ui_controller.refresh_cast_controls()


func _store_ui_state() -> void:
	var settings := _get_presentation()
	if not settings.hide_normal_ui_during_tutorial or not _ui_original_state.is_empty():
		return

	_collect_tutorial_controls()
	for control: Control in _tutorial_controls:
		if control == null or not is_instance_valid(control):
			continue
		var state := {
			"control": control,
			"visible": control.visible,
			"modulate": control.modulate,
			"mouse_filter": control.mouse_filter
		}
		var button := control as BaseButton
		if button != null:
			state["disabled"] = button.disabled
		_ui_original_state[control.get_instance_id()] = state


func _restore_ui_state() -> void:
	for state: Dictionary in _ui_original_state.values():
		var control := state.get("control") as Control
		if control == null or not is_instance_valid(control):
			continue
		control.visible = bool(state.get("visible", control.visible))
		control.modulate = state.get("modulate", control.modulate)
		control.mouse_filter = int(state.get("mouse_filter", control.mouse_filter))
		var button := control as BaseButton
		if button != null and state.has("disabled"):
			button.disabled = bool(state["disabled"])

	_ui_original_state.clear()


func _collect_tutorial_controls() -> void:
	_tutorial_controls.clear()
	for target_id_variant: Variant in CONTROLLED_TARGET_IDS:
		var target_id := String(target_id_variant)
		if not _should_control_target_id(target_id):
			continue
		_add_tutorial_control(_target_control(target_id))


func _add_tutorial_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if _tutorial_controls.has(control):
		return
	_tutorial_controls.append(control)


func _hide_all_tutorial_controls() -> void:
	for control: Control in _tutorial_controls:
		if control == null or not is_instance_valid(control):
			continue
		control.visible = false
		var button := control as BaseButton
		if button != null:
			button.disabled = true


func _show_control_and_parents(control: Control) -> void:
	var current: Node = control
	while current != null:
		var current_control := current as Control
		if current_control == null:
			return
		current_control.visible = true
		current = current_control.get_parent()


func _sync_rune_palette_for_targets(target_ids: Array) -> void:
	if rune_wheel_controller == null:
		return

	if _target_ids_include(target_ids, "rune_palette"):
		rune_wheel_controller.set_expanded(true, false)
	else:
		rune_wheel_controller.set_expanded(false, false)


func _target_ids_include(target_ids: Array, target_id: String) -> bool:
	for candidate_variant: Variant in target_ids:
		if String(candidate_variant) == target_id:
			return true
	return false


func _target_control(target_id: String) -> Control:
	if ui_controller == null:
		return null
	return ui_controller.get_tutorial_target(target_id)


func _should_control_target_id(target_id: String) -> bool:
	if not _get_presentation().hide_debug_buttons_during_tutorial:
		return not target_id.begins_with("debug_chants")
	return true


func _rune_selection_targets() -> Array:
	var targets: Array = ["rune_toggle_button", "rune_palette", "chant_slots", "chant_preview"]
	if _selected_rune_count() > 0:
		targets.append("circle_actions")
		targets.append("clear_button")
	return targets


func _store_objective_state() -> void:
	if objective_label == null or not _objective_original_state.is_empty():
		return

	var canvas_layer := objective_label.get_parent() as CanvasLayer
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
		"modulate": objective_label.modulate,
		"z_index": objective_label.z_index,
		"z_as_relative": objective_label.z_as_relative,
		"canvas_layer": canvas_layer,
		"canvas_layer_index": canvas_layer.layer if canvas_layer != null else 0,
		"had_font_color": objective_label.has_theme_color_override("font_color"),
		"font_color": objective_label.get_theme_color("font_color"),
		"had_font_size": objective_label.has_theme_font_size_override("font_size"),
		"font_size": objective_label.get_theme_font_size("font_size")
	}


func _style_objective_for_tutorial() -> void:
	if objective_label == null:
		return

	var settings := _get_presentation()
	objective_label.anchor_left = 0.06
	objective_label.anchor_top = 0.22
	objective_label.anchor_right = 0.94
	objective_label.anchor_bottom = 0.46
	objective_label.offset_left = 0.0
	objective_label.offset_top = 0.0
	objective_label.offset_right = 0.0
	objective_label.offset_bottom = 0.0
	objective_label.custom_minimum_size = Vector2(0.0, settings.objective_panel_min_height)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.modulate = Color.WHITE
	objective_label.z_as_relative = false
	objective_label.z_index = OBJECTIVE_Z_INDEX
	_set_objective_canvas_layer(OBJECTIVE_CANVAS_LAYER)
	objective_label.add_theme_font_size_override("font_size", settings.objective_font_size)
	objective_label.add_theme_color_override("font_color", settings.objective_color)


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
	objective_label.modulate = _objective_original_state["modulate"]
	objective_label.z_index = int(_objective_original_state["z_index"])
	objective_label.z_as_relative = bool(_objective_original_state["z_as_relative"])
	var canvas_layer := _objective_original_state["canvas_layer"] as CanvasLayer
	if canvas_layer != null and is_instance_valid(canvas_layer):
		canvas_layer.layer = int(_objective_original_state["canvas_layer_index"])

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


func _set_objective_canvas_layer(layer_index: int) -> void:
	if objective_label == null:
		return
	var canvas_layer := objective_label.get_parent() as CanvasLayer
	if canvas_layer == null:
		return
	canvas_layer.layer = layer_index


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


func _selected_rune_count() -> int:
	if round_manager == null:
		return 0
	var count := 0
	for rune: SymbolCardData in round_manager.selected_runes:
		if rune != null:
			count += 1
	return count


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


func _get_presentation() -> CombatTutorialPresentationData:
	if presentation != null:
		return presentation
	if _fallback_presentation == null:
		_fallback_presentation = CombatTutorialPresentationData.new()
		push_warning(
			"CombatTutorialController has no CombatTutorialPresentationData assigned; using script defaults."
		)
	return _fallback_presentation


func _is_tutorial_encounter() -> bool:
	var encounter := GameManager.pending_encounter
	return encounter == null or encounter.is_tutorial_fight


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


func _on_wheel_expanded() -> void:
	if _current_step == TutorialStep.OPEN_RUNES:
		_set_step(TutorialStep.CHOOSE_ASHA)


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
