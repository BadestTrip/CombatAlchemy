# CombatUIController.gd
# Attach this script to the CombatUI VBoxContainer in CombatScene.tscn.
# It builds graybox status panels and a full rune palette, then forwards player
# slot/rune choices to RoundManager. It does not calculate spell effects.
extends VBoxContainer
class_name CombatUIController


# Assign CombatBalance_Default.tres here to tune graybox rune presentation.
@export_group("Balance")
@export var balance: CombatBalanceData

# Assign SymbolLibrary_Default.tres here. The rune palette is built from this
# resource instead of from random hands or hardcoded button lists.
@export_group("Runes")
@export var symbol_library: SymbolLibraryData

# These values control runtime-only discovery and history presentation.
@export_group("Discovery UI")
@export var discovery_popup_auto_hide_seconds: float = 2.5
@export var visible_cast_history_entries: int = 10

@export_group("Modular UI Controllers")
@export var rune_circle_ui: RuneCircleUIController
@export var rune_wheel_controller: RuneWheelController
@export var chant_shout_controller: ChantShoutController
@export var result_banner_controller: SpellResultBannerController
@export var secondary_panel_controller: SecondaryPanelController
@export var player_hud: FloatingUnitHUD
@export var enemy_hud: FloatingUnitHUD
@export var enemy_intent_bubble: EnemyIntentBubble
@export var objective_label: Label


# These node paths assume the exact child names used in CombatScene.tscn.
@onready var mage_statuses: VBoxContainer = %MageStatuses
@onready var enemy_statuses: VBoxContainer = %EnemyStatuses
@onready var enemy_intents: RichTextLabel = %EnemyIntents
@onready var chant_slot_1: Button = %ChantSlot1
@onready var chant_slot_2: Button = %ChantSlot2
@onready var chant_slot_3: Button = %ChantSlot3
@onready var chant_preview: Label = %ChantPreview
@onready var rune_palette: Control = %RunePalette
@onready var cast_button: Button = %CastButton
@onready var clear_button: Button = %ClearButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var spellbook_button: Button = %SpellbookButton
@onready var cast_history_button: Button = %CastHistoryButton
@onready var log_panel: PanelContainer = get_node_or_null("LogPanel") as PanelContainer
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


# CombatManager provides these references after all nodes are ready.
var combat_manager: CombatManager
var round_manager: RoundManager
var discovery_manager: SpellDiscoveryManager
var combat_log: CombatLog

# Runtime rune buttons are rebuilt from SymbolLibraryData once at setup.
var _rune_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []

# RoundManager requests input on/off as phases change. Modal UI can still block it.
var _round_input_enabled: bool = false

# Pause state is stored explicitly instead of relying only on hidden controls.
var _pause_menu_open: bool = false

# A missing Inspector resource uses this safe in-memory default.
var _fallback_balance: CombatBalanceData


# Godot calls this when the UI node enters the scene.
func _ready() -> void:
	_slot_buttons.clear()
	_slot_buttons.append(chant_slot_1)
	_slot_buttons.append(chant_slot_2)
	_slot_buttons.append(chant_slot_3)

	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	discovery_close_button.pressed.connect(_close_discovery_popup)
	discovery_auto_hide_timer.timeout.connect(_close_discovery_popup)

	result_panel.visible = false
	if log_panel != null:
		log_panel.visible = false
	spellbook_panel.visible = false
	cast_history_panel.visible = false
	discovery_popup.visible = false


# CombatManager calls this before RoundManager starts round one.
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

	_resolve_modular_controllers()
	_apply_balance_to_modules()
	_connect_round_objective_signals()

	if discovery_manager != null:
		discovery_manager.spell_discovered.connect(_on_spell_discovered)
		discovery_manager.spellbook_updated.connect(_refresh_spellbook)
		discovery_manager.cast_history_updated.connect(_on_cast_history_updated)

	if rune_circle_ui != null:
		rune_circle_ui.initialize(round_manager, symbol_library)
	else:
		_build_rune_palette()

	if player_hud != null:
		player_hud.bind_unit(combat_manager.player)
	if enemy_hud != null:
		enemy_hud.bind_unit(combat_manager.enemy)
	if enemy_intent_bubble != null:
		enemy_intent_bubble.bind_enemy(combat_manager.enemy)

	_refresh_spellbook()
	_refresh_cast_history()
	_update_objective_text()


# RoundManager calls this after intents are generated.
func show_planning() -> void:
	result_panel.visible = false
	set_input_enabled(true)
	_update_objective_text()
	refresh_all()


# Managers call this after rune slots, HP, shield, intents, or modal state changes.
func refresh_all() -> void:
	if combat_manager == null or round_manager == null:
		return
	if player_hud != null:
		player_hud.refresh()
	if enemy_hud != null:
		enemy_hud.refresh()
	if player_hud == null or enemy_hud == null:
		_refresh_unit_statuses()
	refresh_enemy_intents()
	if rune_circle_ui != null:
		rune_circle_ui.refresh_all()
	else:
		_refresh_chant_slots()
		_refresh_rune_button_state()
		refresh_cast_controls()
	_update_objective_text()


# RoundManager uses this during resolution and enemy actions.
func set_input_enabled(enabled: bool) -> void:
	_round_input_enabled = enabled
	_update_modular_input_lock()
	if rune_circle_ui == null:
		_refresh_rune_button_state()
		refresh_cast_controls()


# This updates only buttons whose state depends on a complete chant.
func refresh_cast_controls() -> void:
	if round_manager == null:
		return
	if rune_circle_ui != null:
		rune_circle_ui.refresh_cast_button()
		return
	var combat_blocked := _combat_actions_blocked()
	cast_button.disabled = combat_blocked or not round_manager.can_cast()
	clear_button.disabled = (
		combat_blocked
		or round_manager.current_state != RoundManager.RoundState.PLANNING
		or _selected_rune_count() == 0
	)


# Enemy intent is visible before Cast, as required by the round flow.
func refresh_enemy_intents() -> void:
	if combat_manager == null:
		return
	enemy_intents.clear()
	for enemy: EnemyUnit in combat_manager.get_living_enemies():
		var description := String(enemy.current_intent.get(
			"description",
			"%s has no intent." % enemy.enemy_name
		))
		enemy_intents.append_text("- %s\n" % description)
	if enemy_intent_bubble != null:
		enemy_intent_bubble.refresh_intent()


# CombatManager calls this after Victory or Defeat.
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
	_update_objective_text("Resolving chant...")
	if chant_shout_controller == null:
		return
	await chant_shout_controller.play_shout_sequence(runes)


func show_spell_result(result: Dictionary) -> void:
	if result_banner_controller == null:
		return
	result_banner_controller.show_result(result)


# Status columns on the left and right are rebuilt from current unit data.
func _refresh_unit_statuses() -> void:
	_clear_children(mage_statuses)
	_clear_children(enemy_statuses)

	for mage: MageUnit in combat_manager.mages:
		mage_statuses.add_child(_make_unit_label(
			mage.mage_name,
			mage.current_hp,
			mage.max_hp,
			mage.shield,
			mage.is_alive,
			Color(0.65, 0.84, 1.0)
		))

	for enemy: EnemyUnit in combat_manager.enemies:
		enemy_statuses.add_child(_make_unit_label(
			enemy.enemy_name,
			enemy.current_hp,
			enemy.max_hp,
			enemy.shield,
			enemy.is_alive,
			Color(1.0, 0.64, 0.48)
		))


# Slots are explicit buttons: click a slot, then click any rune to place it.
func _refresh_chant_slots() -> void:
	var preview_words: PackedStringArray = []

	for index: int in range(_slot_buttons.size()):
		var slot_button := _slot_buttons[index]
		var rune: SymbolCardData = round_manager.selected_runes[index]
		var lines: PackedStringArray = []
		if index == round_manager.selected_slot_index:
			lines.append("[SELECTED]")
		lines.append("Slot %d" % (index + 1))
		if rune == null:
			lines.append("---")
			preview_words.append("...")
		else:
			if not rune.visual_hint.is_empty():
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


# The full rune palette is data-driven from SymbolLibraryData.symbols.
func _build_rune_palette() -> void:
	_rune_buttons.clear()
	_clear_children(rune_palette)

	if symbol_library == null or symbol_library.symbols.is_empty():
		var warning := Label.new()
		warning.text = "No rune library assigned."
		rune_palette.add_child(warning)
		return

	for rune: SymbolCardData in symbol_library.symbols:
		if rune == null:
			continue
		var rune_button := Button.new()
		var settings := _get_balance()
		rune_button.custom_minimum_size = Vector2(
			maxf(1.0, settings.rune_button_width),
			maxf(1.0, settings.rune_button_height)
		)
		rune_button.text = _format_rune_button_text(rune)
		rune_button.tooltip_text = "%s rune" % rune.spoken_word
		rune_button.pressed.connect(_on_rune_pressed.bind(rune))
		rune_palette.add_child(rune_button)
		_rune_buttons.append(rune_button)

	_refresh_rune_button_state()


# Existing balance UI toggles still control what appears on rune buttons.
func _format_rune_button_text(rune: SymbolCardData) -> String:
	var lines: PackedStringArray = []
	if _get_balance().show_card_visual_hints and not rune.visual_hint.is_empty():
		lines.append(rune.visual_hint)
	lines.append(rune.spoken_word)
	if _get_balance().show_card_display_names and not rune.display_name.is_empty():
		lines.append(rune.display_name)
	return "\n".join(lines)


func _refresh_rune_button_state() -> void:
	var allow_input := (
		_round_input_enabled
		and not _combat_actions_blocked()
		and round_manager != null
		and round_manager.current_state == RoundManager.RoundState.PLANNING
	)
	for button: Button in _rune_buttons:
		button.disabled = not allow_input
	for slot_button: Button in _slot_buttons:
		slot_button.disabled = not allow_input


func _on_slot_pressed(slot_index: int) -> void:
	if _combat_actions_blocked():
		return
	round_manager.select_slot(slot_index)


func _on_rune_pressed(rune: SymbolCardData) -> void:
	if _combat_actions_blocked():
		return
	round_manager.place_rune_in_selected_slot(rune)


func _on_cast_pressed() -> void:
	if _combat_actions_blocked():
		return
	round_manager.cast_chant()


func _on_clear_pressed() -> void:
	if _combat_actions_blocked():
		return
	round_manager.clear_chant()


# PauseMenu calls this when Escape opens or closes its overlay.
func set_pause_menu_open(is_open: bool) -> void:
	_pause_menu_open = is_open
	_update_combat_input_state()


# Spellbook is a modal graybox panel populated from discovery-owned data.
func _on_spellbook_pressed() -> void:
	if _pause_menu_open:
		return
	cast_history_panel.visible = false
	spellbook_panel.visible = not spellbook_panel.visible
	_refresh_spellbook()
	_update_combat_input_state()


func _close_spellbook() -> void:
	spellbook_panel.visible = false
	_update_combat_input_state()


# Cast History is toggleable to avoid shrinking the existing combat layout.
func _on_cast_history_pressed() -> void:
	if _pause_menu_open:
		return
	spellbook_panel.visible = false
	cast_history_panel.visible = not cast_history_panel.visible
	_refresh_cast_history()
	_update_combat_input_state()


func _close_cast_history() -> void:
	cast_history_panel.visible = false
	_update_combat_input_state()


# First-time authored discoveries show data from SpellRecipeData.
func _on_spell_discovered(
	recipe: SpellRecipeData,
	result: Dictionary
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

	combat_log.append_line(
		"New spell discovered: %s." % recipe.result_name,
		Color(0.95, 0.78, 0.38)
	)

	discovery_auto_hide_timer.stop()
	if discovery_popup_auto_hide_seconds > 0.0:
		discovery_auto_hide_timer.start(discovery_popup_auto_hide_seconds)
	_update_combat_input_state()


func _close_discovery_popup() -> void:
	discovery_auto_hide_timer.stop()
	discovery_popup.visible = false
	_update_combat_input_state()


# Spellbook shows only recipes discovered by SpellDiscoveryManager.
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


# History uses snapshots, so later resource edits cannot rewrite earlier casts.
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

	var first_index := maxi(
		0,
		entries.size() - maxi(1, visible_cast_history_entries)
	)
	for index: int in range(entries.size() - 1, first_index - 1, -1):
		var entry: Dictionary = entries[index]
		var markers: PackedStringArray = []
		if bool(entry.get("was_new_discovery", false)):
			markers.append("[NEW]")
		if not bool(entry.get("is_known", false)):
			markers.append("[UNKNOWN]")
		else:
			markers.append(
				"[%s]" % String(entry.get("result_type", "invalid")).to_upper()
			)

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


# This is the single safety check used by every combat input callback.
func _combat_actions_blocked() -> bool:
	if _pause_menu_open or get_tree().paused or discovery_popup.visible:
		return true
	if secondary_panel_controller != null:
		return (
			_get_balance().block_combat_input_when_secondary_panel_open
			and secondary_panel_controller.is_any_panel_open()
		)
	return spellbook_panel.visible or cast_history_panel.visible


func _update_combat_input_state() -> void:
	set_input_enabled(_round_input_enabled)
	refresh_cast_controls()


func _resolve_modular_controllers() -> void:
	if rune_circle_ui == null:
		rune_circle_ui = _find_scene_node("RuneCircleRoot") as RuneCircleUIController
	if rune_circle_ui == null:
		rune_circle_ui = _find_scene_node("ChantPanel") as RuneCircleUIController
	if rune_wheel_controller == null:
		rune_wheel_controller = _find_scene_node("RuneWheelRoot") as RuneWheelController
	if rune_wheel_controller == null:
		rune_wheel_controller = _find_scene_node("HandsPanel") as RuneWheelController
	if chant_shout_controller == null:
		chant_shout_controller = _find_scene_node("ChantShoutText") as ChantShoutController
	if result_banner_controller == null:
		result_banner_controller = _find_scene_node("SpellResultBanner") as SpellResultBannerController
	if secondary_panel_controller == null:
		secondary_panel_controller = _find_scene_node("SecondaryUI") as SecondaryPanelController
	if player_hud == null:
		player_hud = _find_scene_node("PlayerFloatingHUD") as FloatingUnitHUD
	if enemy_hud == null:
		enemy_hud = _find_scene_node("EnemyFloatingHUD") as FloatingUnitHUD
	if enemy_intent_bubble == null:
		enemy_intent_bubble = _find_scene_node("EnemyIntentBubble") as EnemyIntentBubble
	if enemy_intent_bubble == null:
		enemy_intent_bubble = _find_scene_node("IntentPanel") as EnemyIntentBubble
	if objective_label == null:
		objective_label = _find_scene_node("ObjectiveLabel") as Label


func _apply_balance_to_modules() -> void:
	var settings := _get_balance()
	if rune_circle_ui != null:
		rune_circle_ui.auto_expand_wheel_on_empty_slot_click = settings.auto_expand_wheel_on_slot_click
		rune_circle_ui.rune_wheel_controller = rune_wheel_controller
	if rune_wheel_controller != null:
		rune_wheel_controller.starts_expanded = settings.rune_wheel_starts_expanded
		rune_wheel_controller.auto_retract_after_rune_pick = settings.auto_retract_wheel_after_rune_pick
		rune_wheel_controller.wheel_radius = settings.rune_wheel_radius
		rune_wheel_controller.tween_seconds = settings.rune_wheel_tween_seconds
		rune_wheel_controller.rune_button_size = Vector2(
			maxf(1.0, settings.rune_button_width * 0.62),
			maxf(1.0, settings.rune_button_height)
		)
	if chant_shout_controller != null:
		chant_shout_controller.shout_each_rune_seconds = settings.shout_each_rune_seconds
		chant_shout_controller.shout_between_runes_seconds = settings.shout_between_runes_seconds
	if result_banner_controller != null:
		result_banner_controller.auto_hide_seconds = settings.spell_result_banner_seconds
	if secondary_panel_controller != null:
		secondary_panel_controller.configure(
			settings.secondary_panels_start_closed,
			settings.only_one_secondary_panel_open,
			settings.block_combat_input_when_secondary_panel_open
		)
		if not secondary_panel_controller.panel_state_changed.is_connected(_on_secondary_panel_state_changed):
			secondary_panel_controller.panel_state_changed.connect(_on_secondary_panel_state_changed)


func _connect_round_objective_signals() -> void:
	if round_manager == null:
		return
	if not round_manager.selected_slot_changed.is_connected(_on_round_selection_changed):
		round_manager.selected_slot_changed.connect(_on_round_selection_changed)
	if not round_manager.selected_runes_changed.is_connected(_on_round_runes_changed):
		round_manager.selected_runes_changed.connect(_on_round_runes_changed)
	if not round_manager.casting_started.is_connected(_on_round_casting_started):
		round_manager.casting_started.connect(_on_round_casting_started)
	if not round_manager.casting_finished.is_connected(_on_round_casting_finished):
		round_manager.casting_finished.connect(_on_round_casting_finished)
	if not round_manager.player_phase_started.is_connected(_on_player_phase_started):
		round_manager.player_phase_started.connect(_on_player_phase_started)
	if not round_manager.enemy_phase_started.is_connected(_on_enemy_phase_started):
		round_manager.enemy_phase_started.connect(_on_enemy_phase_started)


func _update_modular_input_lock() -> void:
	var locked := not _round_input_enabled or _combat_actions_blocked()
	if rune_circle_ui != null:
		rune_circle_ui.set_input_locked(locked)
	elif rune_wheel_controller != null:
		rune_wheel_controller.set_input_locked(locked)


func _update_objective_text(forced_text: String = "") -> void:
	if objective_label == null:
		return
	if not forced_text.is_empty():
		objective_label.text = forced_text
		return
	if round_manager == null:
		objective_label.text = "Ready."
		return
	if round_manager.current_state == RoundManager.RoundState.ENEMY_PHASE:
		objective_label.text = "Enemy phase."
		return
	if round_manager.current_state == RoundManager.RoundState.RESOLVING_CHANT:
		objective_label.text = "Resolving chant..."
		return
	if round_manager.can_cast():
		objective_label.text = "Cast the chant."
		return
	var slot_number := round_manager.selected_slot_index + 1
	objective_label.text = "Choose a rune for Slot %d." % slot_number


func _on_secondary_panel_state_changed(panel_id: String, is_open: bool) -> void:
	if is_open:
		match panel_id:
			"history":
				_refresh_cast_history()
			"chants":
				_refresh_spellbook()
	_update_combat_input_state()


func _on_round_selection_changed(_slot_index: int) -> void:
	_update_objective_text()


func _on_round_runes_changed(_selected_runes: Array) -> void:
	_update_objective_text()


func _on_round_casting_started() -> void:
	_update_objective_text("Resolving chant...")


func _on_round_casting_finished() -> void:
	_update_objective_text()


func _on_player_phase_started() -> void:
	_update_objective_text()


func _on_enemy_phase_started() -> void:
	_update_objective_text("Enemy phase.")


func _find_scene_node(node_name: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		scene = owner
	if scene == null:
		return null
	return scene.find_child(node_name, true, false)


# Result buttons preserve the existing GameManager scene flow.
func _on_restart_pressed() -> void:
	restart_button.disabled = true
	main_menu_button.disabled = true
	GameManager.restart_combat()


func _on_main_menu_pressed() -> void:
	restart_button.disabled = true
	main_menu_button.disabled = true
	GameManager.go_to_main_menu()


# These small UI helpers keep the rebuilding functions readable.
func _selected_rune_count() -> int:
	var count := 0
	for rune: SymbolCardData in round_manager.selected_runes:
		if rune != null:
			count += 1
	return count


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _make_unit_label(
	unit_name: String,
	current_hp: int,
	max_hp: int,
	shield: int,
	is_alive: bool,
	color: Color
) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(250.0, 62.0)
	label.text = "%s\nHP %d / %d    Shield %d" % [
		unit_name,
		current_hp,
		max_hp,
		shield
	]
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override(
		"font_color",
		color if is_alive else Color(0.45, 0.45, 0.45)
	)
	return label


# Missing scene wiring should warn but should not crash UI rebuilding.
func _get_balance() -> CombatBalanceData:
	if balance != null:
		return balance
	if _fallback_balance == null:
		_fallback_balance = CombatBalanceData.new()
		push_warning(
			"CombatUIController has no CombatBalanceData assigned; "
			+ "using script defaults."
		)
	return _fallback_balance
