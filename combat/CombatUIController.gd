# CombatUIController.gd
# High-level UI wiring for the current 1v1 full-rune-palette prototype.
# Spell math stays in ChantResolver; round state stays in RoundManager.
extends VBoxContainer
class_name CombatUIController


signal secondary_panel_opened(panel_id: String)
signal spell_result_shown(result: Dictionary)


@export_group("Runes")
@export var symbol_library: SymbolLibraryData

@export_group("Active UI Helpers")
@export var rune_wheel_controller: RuneWheelController
@export var player_hud: FloatingUnitHUD
@export var enemy_hud: FloatingUnitHUD
@export var objective_label: Label


@onready var chant_slot_1: Button = %ChantSlot1
@onready var chant_slot_2: Button = %ChantSlot2
@onready var chant_slot_3: Button = %ChantSlot3
@onready var chant_preview: Label = %ChantPreview
@onready var cast_button: Button = %CastButton
@onready var clear_button: Button = %ClearButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var spellbook_button: Button = %SpellbookButton
@onready var cast_history_button: Button = %CastHistoryButton
@onready var spellbook_panel: PanelContainer = %SpellbookPanel
@onready var spellbook_list: RichTextLabel = %SpellbookList
@onready var spellbook_close_button: Button = %SpellbookCloseButton
@onready var cast_history_panel: PanelContainer = %CastHistoryPanel
@onready var cast_history_list: RichTextLabel = %CastHistoryList
@onready var cast_history_close_button: Button = %CastHistoryCloseButton
@onready var discovery_popup: PanelContainer = %SpellDiscoveryPopup
@onready var discovery_popup_label: Label = %DiscoveryPopupLabel
@onready var discovery_close_button: Button = %DiscoveryCloseButton
@onready var discovery_auto_hide_timer: Timer = %DiscoveryAutoHideTimer


var combat_manager: CombatManager
var round_manager: RoundManager
var discovery_manager: SpellDiscoveryManager
var combat_log: CombatLog
var balance: CombatBalanceData

var _slot_buttons: Array[Button] = []
var _round_input_enabled: bool = false
var _pause_menu_open: bool = false
var _fallback_balance: CombatBalanceData
var _result_banner_tween: Tween
var _shout_is_playing: bool = false

var _combat_log_button: Button
var _log_panel: Control
var _enemy_intent_bubble: Control
var _enemy_intent_label: Label
var _shout_label: Label
var _spell_result_banner: Control
var _spell_result_title_label: Label
var _spell_result_category_label: Label
var _tutorial_objective_text: String = ""
var tutorial_objective_active: bool = false
var _spell_result_banner_tutorial_hold: bool = false


func _ready() -> void:
	_slot_buttons = [chant_slot_1, chant_slot_2, chant_slot_3]
	for slot_index: int in range(_slot_buttons.size()):
		_slot_buttons[slot_index].pressed.connect(_on_slot_pressed.bind(slot_index))

	cast_button.pressed.connect(_on_cast_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	spellbook_button.pressed.connect(_on_spellbook_pressed)
	cast_history_button.pressed.connect(_on_cast_history_pressed)
	spellbook_close_button.pressed.connect(_close_secondary_panels)
	cast_history_close_button.pressed.connect(_close_secondary_panels)
	discovery_close_button.pressed.connect(_close_discovery_popup)
	discovery_auto_hide_timer.timeout.connect(_close_discovery_popup)

	_resolve_scene_nodes()
	_connect_scene_node_signals()
	set_tutorial_objective_active(false)

	result_panel.visible = false
	if _log_panel != null:
		_log_panel.visible = false
	spellbook_panel.visible = false
	cast_history_panel.visible = false
	discovery_popup.visible = false
	if _shout_label != null:
		_shout_label.visible = false
	if _spell_result_banner != null:
		_spell_result_banner.visible = false


func configure(
	manager: CombatManager,
	rounds: RoundManager,
	discovery: SpellDiscoveryManager,
	log: CombatLog
) -> void:
	combat_manager = manager
	round_manager = rounds
	discovery_manager = discovery
	combat_log = log

	_resolve_scene_nodes()
	_connect_scene_node_signals()
	_connect_round_signals()

	if discovery_manager != null:
		discovery_manager.spell_discovered.connect(_on_spell_discovered)
		discovery_manager.spellbook_updated.connect(_refresh_spellbook)
		discovery_manager.cast_history_updated.connect(_on_cast_history_updated)

	if rune_wheel_controller != null:
		rune_wheel_controller.initialize(symbol_library, _get_balance())
		if not rune_wheel_controller.rune_selected.is_connected(_on_rune_pressed):
			rune_wheel_controller.rune_selected.connect(_on_rune_pressed)

	if player_hud != null:
		player_hud.apply_balance(_get_balance())
		player_hud.bind_unit(combat_manager.player)
	if enemy_hud != null:
		enemy_hud.apply_balance(_get_balance())
		enemy_hud.bind_unit(combat_manager.enemy)

	_refresh_spellbook()
	_refresh_cast_history()
	refresh_all()


func show_planning() -> void:
	result_panel.visible = false
	set_input_enabled(true)
	refresh_all()


func refresh_all() -> void:
	if combat_manager == null or round_manager == null:
		return
	if player_hud != null:
		player_hud.refresh()
	if enemy_hud != null:
		enemy_hud.refresh()
	refresh_enemy_intents()
	_refresh_chant_slots()
	refresh_cast_controls()
	_update_objective_text()


func set_input_enabled(enabled: bool) -> void:
	_round_input_enabled = enabled
	_refresh_chant_slots()
	refresh_cast_controls()
	_update_rune_wheel_lock()


func refresh_cast_controls() -> void:
	if round_manager == null:
		return
	var blocked := _combat_actions_blocked()
	cast_button.disabled = blocked or not round_manager.can_cast()
	clear_button.disabled = (
		blocked
		or round_manager.current_state != RoundManager.RoundState.PLANNING
		or _selected_rune_count() == 0
	)


func refresh_enemy_intents() -> void:
	if combat_manager == null:
		return

	var first_description := "No intent"
	for enemy: EnemyUnit in combat_manager.get_living_enemies():
		var description := String(enemy.current_intent.get(
			"description",
			"%s has no intent." % enemy.enemy_name
		))
		if first_description == "No intent":
			first_description = description

	if _enemy_intent_label != null:
		_enemy_intent_label.text = first_description


func show_result(victory: bool) -> void:
	set_input_enabled(false)
	result_panel.visible = true
	result_label.text = "Victory" if victory else "Defeat"
	result_label.add_theme_color_override(
		"font_color",
		Color(0.52, 0.9, 0.48) if victory else Color(1.0, 0.42, 0.36)
	)
	restart_button.disabled = false
	main_menu_button.disabled = false


func play_chant_shout(runes: Array[SymbolCardData]) -> void:
	if _shout_label == null or _shout_is_playing:
		return

	_shout_is_playing = true
	for index: int in range(runes.size()):
		var rune := runes[index]
		if rune == null:
			continue
		_shout_label.text = "%s!" % rune.spoken_word.to_upper()
		_shout_label.visible = true
		await get_tree().create_timer(
			maxf(0.0, _get_balance().shout_each_rune_seconds)
		).timeout
		_shout_label.visible = false
		await get_tree().create_timer(
			maxf(0.0, _get_balance().shout_between_runes_seconds)
		).timeout

	await get_tree().create_timer(0.25).timeout
	_shout_label.visible = false
	_shout_is_playing = false


func show_spell_result(result: Dictionary) -> void:
	if _spell_result_banner == null:
		return

	if _result_banner_tween != null:
		_result_banner_tween.kill()
		_result_banner_tween = null

	if _spell_result_title_label != null:
		_spell_result_title_label.text = String(result.get("result_name", "Unknown Chant"))
	if _spell_result_category_label != null:
		_spell_result_category_label.text = _result_category_text(
			String(result.get("result_type", "fallback"))
		)

	_spell_result_banner.visible = true
	_spell_result_banner.modulate.a = 1.0
	spell_result_shown.emit(result)
	if _get_balance().spell_result_banner_seconds > 0.0 and not _spell_result_banner_tutorial_hold:
		_result_banner_tween = create_tween()
		_result_banner_tween.tween_interval(_get_balance().spell_result_banner_seconds)
		_result_banner_tween.tween_property(_spell_result_banner, "modulate:a", 0.0, 0.18)
		_result_banner_tween.tween_callback(func() -> void:
			_spell_result_banner.visible = false
		)


func set_pause_menu_open(is_open: bool) -> void:
	_pause_menu_open = is_open
	_update_combat_input_state()


func get_tutorial_target(target_id: String) -> Control:
	return _tutorial_target_for_id(target_id)


func set_tutorial_objective_active(active: bool) -> void:
	tutorial_objective_active = active
	if objective_label != null:
		objective_label.visible = active


func set_objective_text_override(text: String) -> void:
	_tutorial_objective_text = text
	_update_objective_text()


func clear_objective_text_override() -> void:
	_tutorial_objective_text = ""
	_update_objective_text()


func is_secondary_panel_open(panel_id: String) -> bool:
	var panel := _secondary_panel_for_id(panel_id)
	return panel != null and panel.visible


func hold_spell_result_banner_for_tutorial(should_hold: bool) -> void:
	_spell_result_banner_tutorial_hold = should_hold
	if _spell_result_banner == null:
		return

	if should_hold:
		if _result_banner_tween != null:
			_result_banner_tween.kill()
			_result_banner_tween = null
		_spell_result_banner.visible = true
		_spell_result_banner.modulate.a = 1.0
		return

	if _spell_result_banner.visible and _get_balance().spell_result_banner_seconds > 0.0:
		if _result_banner_tween != null:
			_result_banner_tween.kill()
		_result_banner_tween = create_tween()
		_result_banner_tween.tween_property(_spell_result_banner, "modulate:a", 0.0, 0.18)
		_result_banner_tween.tween_callback(func() -> void:
			_spell_result_banner.visible = false
		)


func _resolve_scene_nodes() -> void:
	if rune_wheel_controller == null:
		rune_wheel_controller = _find_scene_node("RuneWheelRoot") as RuneWheelController
	if player_hud == null:
		player_hud = _find_scene_node("PlayerFloatingHUD") as FloatingUnitHUD
	if enemy_hud == null:
		enemy_hud = _find_scene_node("EnemyFloatingHUD") as FloatingUnitHUD
	if objective_label == null:
		objective_label = _find_scene_node("ObjectiveLabel") as Label

	_combat_log_button = _find_scene_node("CombatLogButton") as Button
	_log_panel = _find_scene_node("LogPanel") as Control
	_enemy_intent_bubble = _find_scene_node("EnemyIntentBubble") as Control
	_enemy_intent_label = _find_scene_node("IntentLabel") as Label
	_shout_label = _find_scene_node("ChantShoutText") as Label
	_spell_result_banner = _find_scene_node("SpellResultBanner") as Control
	_spell_result_title_label = _find_scene_node("TitleLabel") as Label
	_spell_result_category_label = _find_scene_node("CategoryLabel") as Label


func _connect_scene_node_signals() -> void:
	if (
		_combat_log_button != null
		and not _combat_log_button.pressed.is_connected(_on_combat_log_pressed)
	):
		_combat_log_button.pressed.connect(_on_combat_log_pressed)


func _connect_round_signals() -> void:
	if round_manager == null:
		return
	if not round_manager.selected_slot_changed.is_connected(_on_round_selection_changed):
		round_manager.selected_slot_changed.connect(_on_round_selection_changed)
	if not round_manager.selected_runes_changed.is_connected(_on_round_runes_changed):
		round_manager.selected_runes_changed.connect(_on_round_runes_changed)
	if not round_manager.cast_availability_changed.is_connected(_on_cast_availability_changed):
		round_manager.cast_availability_changed.connect(_on_cast_availability_changed)
	if not round_manager.casting_started.is_connected(_on_round_casting_started):
		round_manager.casting_started.connect(_on_round_casting_started)
	if not round_manager.casting_finished.is_connected(_on_round_casting_finished):
		round_manager.casting_finished.connect(_on_round_casting_finished)
	if not round_manager.player_phase_started.is_connected(_on_player_phase_started):
		round_manager.player_phase_started.connect(_on_player_phase_started)
	if not round_manager.enemy_phase_started.is_connected(_on_enemy_phase_started):
		round_manager.enemy_phase_started.connect(_on_enemy_phase_started)


func _refresh_chant_slots() -> void:
	if round_manager == null:
		return

	var preview_words: PackedStringArray = []
	for index: int in range(_slot_buttons.size()):
		var slot_button := _slot_buttons[index]
		var rune: SymbolCardData = round_manager.selected_runes[index]
		var lines: PackedStringArray = []
		if index == round_manager.selected_slot_index:
			lines.append("> Slot %d" % (index + 1))
		else:
			lines.append("Slot %d" % (index + 1))

		if rune == null:
			lines.append("---")
			preview_words.append("...")
		else:
			if _get_balance().show_card_visual_hints and not rune.visual_hint.is_empty():
				lines.append(rune.visual_hint)
			lines.append(rune.spoken_word)
			preview_words.append(rune.spoken_word)

		slot_button.text = "\n".join(lines)
		slot_button.disabled = (
			_combat_actions_blocked()
			or not _round_input_enabled
			or round_manager.current_state != RoundManager.RoundState.PLANNING
		)

	chant_preview.text = "Selected Chant:\n" + "  >  ".join(preview_words)


func _update_combat_input_state() -> void:
	set_input_enabled(_round_input_enabled)
	refresh_cast_controls()


func _update_rune_wheel_lock() -> void:
	if rune_wheel_controller == null:
		return
	rune_wheel_controller.set_input_locked(
		not _round_input_enabled
		or _combat_actions_blocked()
		or round_manager == null
		or round_manager.current_state != RoundManager.RoundState.PLANNING
	)


func _combat_actions_blocked() -> bool:
	if _pause_menu_open or get_tree().paused or discovery_popup.visible:
		return true
	return (
		_get_balance().block_combat_input_when_secondary_panel_open
		and _is_secondary_panel_open()
	)


func _is_secondary_panel_open() -> bool:
	return (
		(_log_panel != null and _log_panel.visible)
		or spellbook_panel.visible
		or cast_history_panel.visible
	)


func _on_slot_pressed(slot_index: int) -> void:
	if _combat_actions_blocked() or round_manager == null:
		return
	var was_empty := (
		slot_index >= 0
		and slot_index < round_manager.selected_runes.size()
		and round_manager.selected_runes[slot_index] == null
	)
	round_manager.select_slot(slot_index)
	if (
		was_empty
		and _get_balance().auto_expand_wheel_on_slot_click
		and rune_wheel_controller != null
	):
		rune_wheel_controller.set_expanded(true)


func _on_rune_pressed(rune: SymbolCardData) -> void:
	if _combat_actions_blocked() or round_manager == null:
		return
	round_manager.place_rune_in_selected_slot(rune)


func _on_cast_pressed() -> void:
	if _combat_actions_blocked() or round_manager == null:
		return
	round_manager.cast_chant()


func _on_clear_pressed() -> void:
	if _combat_actions_blocked() or round_manager == null:
		return
	round_manager.clear_chant()


func _on_combat_log_pressed() -> void:
	_toggle_secondary_panel("log")


func _on_spellbook_pressed() -> void:
	_toggle_secondary_panel("chants")


func _on_cast_history_pressed() -> void:
	_toggle_secondary_panel("history")


func _toggle_secondary_panel(panel_id: String) -> void:
	if _pause_menu_open:
		return

	var panel := _secondary_panel_for_id(panel_id)
	if panel == null:
		return
	var should_open := not panel.visible
	_close_secondary_panels()
	if should_open:
		panel.visible = true
		match panel_id:
			"history":
				_refresh_cast_history()
			"chants":
				_refresh_spellbook()
	_update_secondary_button_states()
	_update_combat_input_state()
	if should_open:
		secondary_panel_opened.emit(panel_id)


func _close_secondary_panels() -> void:
	if _log_panel != null:
		_log_panel.visible = false
	spellbook_panel.visible = false
	cast_history_panel.visible = false
	_update_secondary_button_states()
	_update_combat_input_state()


func _secondary_panel_for_id(panel_id: String) -> Control:
	match panel_id:
		"log":
			return _log_panel
		"history":
			return cast_history_panel
		"chants":
			return spellbook_panel
		_:
			return null


func _update_secondary_button_states() -> void:
	if _combat_log_button != null:
		_combat_log_button.button_pressed = _log_panel != null and _log_panel.visible
	if cast_history_button != null:
		cast_history_button.button_pressed = cast_history_panel.visible
	if spellbook_button != null:
		spellbook_button.button_pressed = spellbook_panel.visible


func _on_spell_discovered(
	recipe: SpellRecipeData,
	_result: Dictionary
) -> void:
	if recipe == null:
		return

	var description := recipe.player_description
	if description.is_empty():
		description = "Effect description not written yet."

	var lines: PackedStringArray = [
		"NEW SPELL DISCOVERED",
		_format_recipe_chant(recipe),
		recipe.result_name,
		description
	]
	if not recipe.discovery_flavor_text.is_empty():
		lines.append(recipe.discovery_flavor_text)
	discovery_popup_label.text = "\n".join(lines)
	discovery_popup.visible = true

	if combat_log != null:
		combat_log.append_line(
			"New spell discovered: %s." % recipe.result_name,
			Color(0.95, 0.78, 0.38)
		)

	discovery_auto_hide_timer.stop()
	var auto_hide_seconds := _get_balance().discovery_popup_auto_hide_seconds
	if auto_hide_seconds > 0.0:
		discovery_auto_hide_timer.start(auto_hide_seconds)
	_update_combat_input_state()


func _close_discovery_popup() -> void:
	discovery_auto_hide_timer.stop()
	discovery_popup.visible = false
	_update_combat_input_state()


func _refresh_spellbook() -> void:
	if spellbook_list == null:
		return
	spellbook_list.clear()
	if discovery_manager == null:
		spellbook_list.append_text("Discovery manager is not configured.")
		return

	var recipes := discovery_manager.get_discovered_recipes()
	if recipes.is_empty():
		spellbook_list.append_text("No authored spells discovered yet.")
		return

	for recipe: SpellRecipeData in recipes:
		var description := recipe.player_description
		if description.is_empty():
			description = "Effect description not written yet."
		spellbook_list.append_text(
			"%s\n%s\nType: %s\nEffect: %s\n\n" % [
				recipe.result_name,
				_format_recipe_chant(recipe),
				recipe.result_type,
				description
			]
		)


func _on_cast_history_updated(history: Array[Dictionary]) -> void:
	_refresh_cast_history(history)


func _refresh_cast_history(history: Array[Dictionary] = []) -> void:
	if cast_history_list == null:
		return
	cast_history_list.clear()

	var entries := history
	if entries.is_empty() and discovery_manager != null:
		entries = discovery_manager.cast_history
	if entries.is_empty():
		cast_history_list.append_text("No chants attempted yet.")
		return

	var visible_entries := maxi(1, _get_balance().visible_cast_history_entries)
	var first_index := maxi(0, entries.size() - visible_entries)
	for index: int in range(entries.size() - 1, first_index - 1, -1):
		var entry: Dictionary = entries[index]
		var markers: PackedStringArray = []
		if bool(entry.get("was_new_discovery", false)):
			markers.append("[NEW]")
		if not bool(entry.get("is_known", false)):
			markers.append("[UNKNOWN]")
		else:
			markers.append("[%s]" % String(entry.get("result_type", "invalid")).to_upper())

		var words: PackedStringArray = []
		for word: Variant in entry.get("spoken_words", []):
			words.append(String(word))
		cast_history_list.append_text(
			"Round %d: %s = %s %s\nTarget: %s\n\n" % [
				int(entry.get("round", 0)),
				" > ".join(words),
				String(entry.get("result_name", "Unknown Result")),
				" ".join(markers),
				String(entry.get("target", "None"))
			]
		)


func _format_recipe_chant(recipe: SpellRecipeData) -> String:
	var words: PackedStringArray = []
	for symbol_id: String in recipe.chant_symbols:
		words.append(symbol_id.to_upper())
	return " > ".join(words)


func _result_category_text(result_type: String) -> String:
	match result_type:
		"workable":
			return "Known Spell"
		"disaster":
			return "Disaster Spell"
		"op":
			return "Rare Spell"
		"funny":
			return "Strange Spell"
		"invalid":
			return "Invalid Chant"
		_:
			return "Unknown Chant"


func _on_round_selection_changed(_slot_index: int) -> void:
	_refresh_chant_slots()
	_update_objective_text()


func _on_round_runes_changed(_selected_runes: Array) -> void:
	_refresh_chant_slots()
	refresh_cast_controls()
	_update_objective_text()


func _on_cast_availability_changed(_can_cast: bool) -> void:
	refresh_cast_controls()


func _on_round_casting_started() -> void:
	_update_objective_text()


func _on_round_casting_finished() -> void:
	_update_objective_text()


func _on_player_phase_started() -> void:
	_update_objective_text()


func _on_enemy_phase_started() -> void:
	_update_objective_text()


func _update_objective_text(forced_text: String = "") -> void:
	if objective_label == null:
		return
	if not tutorial_objective_active:
		objective_label.visible = false
		return
	objective_label.visible = true
	if not _tutorial_objective_text.is_empty():
		objective_label.text = _tutorial_objective_text
		return
	if not forced_text.is_empty():
		objective_label.text = forced_text
		return
	objective_label.text = ""


func _on_restart_pressed() -> void:
	restart_button.disabled = true
	main_menu_button.disabled = true
	GameManager.restart_combat()


func _on_main_menu_pressed() -> void:
	restart_button.disabled = true
	main_menu_button.disabled = true
	GameManager.go_to_main_menu()


func _selected_rune_count() -> int:
	var count := 0
	if round_manager == null:
		return count
	for rune: SymbolCardData in round_manager.selected_runes:
		if rune != null:
			count += 1
	return count


func _find_scene_node(node_name: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		scene = owner
	if scene == null:
		return null
	return scene.find_child(node_name, true, false)


func _tutorial_target_for_id(target_id: String) -> Control:
	match target_id:
		"chant_slot_1":
			return chant_slot_1
		"chant_slot_2":
			return chant_slot_2
		"chant_slot_3":
			return chant_slot_3
		"cast_button":
			return cast_button
		"clear_button":
			return clear_button
		"enemy_intent":
			if _enemy_intent_bubble != null:
				return _enemy_intent_bubble
			return _enemy_intent_label
		"combat_log_button":
			return _combat_log_button
		"cast_history_button":
			return cast_history_button
		"spellbook_button":
			return spellbook_button
		"spell_result_banner":
			return _spell_result_banner
		_:
			return null


func _get_balance() -> CombatBalanceData:
	if balance != null:
		return balance
	if _fallback_balance == null:
		_fallback_balance = CombatBalanceData.new()
		push_warning(
			"CombatUIController has no CombatBalanceData assigned; using script defaults."
		)
	return _fallback_balance
