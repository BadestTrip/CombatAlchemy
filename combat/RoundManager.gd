# RoundManager.gd
# Attach this script to the RoundManager node in CombatScene.tscn.
# It owns the 1v1 round flow and the three selected rune slots. Chant effects
# stay in ChantResolver; scene-level Victory/Defeat checks stay in CombatManager.
extends Node
class_name RoundManager


# Emitted when a new numbered round starts.
signal round_started(round_number: int)

# Emitted after enemy intent exists and rune selection is enabled.
signal planning_started

# Emitted when a rune fills or replaces one chant slot.
signal rune_placed(rune: SymbolCardData, slot_index: int)

# Emitted when one slot is selected for replacement.
signal slot_selected(slot_index: int)

# Emitted when one slot is selected for replacement.
signal selected_slot_changed(slot_index: int)

# Emitted when chant slot contents change.
signal selected_runes_changed(selected_runes: Array)

# Emitted when a slot/content change affects Cast availability.
signal cast_availability_changed(can_cast: bool)

# Emitted when all three chant slots are cleared.
signal chant_cleared

# Emitted immediately before ChantResolver applies the selected combination.
signal chant_cast_started(symbols: Array[SymbolCardData], target: EnemyUnit)

# Emitted when cast presentation and resolution start.
signal casting_started

# Emitted after cast presentation and resolution finish.
signal casting_finished

# Emitted after ChantResolver returns its result Dictionary.
signal chant_resolved(result: Dictionary)

# Emitted after enemy intent exists and rune selection is enabled.
signal player_phase_started

# Emitted before the surviving enemy executes its visible intent.
signal enemy_phase_started

# Emitted after statuses update.
signal round_ended(round_number: int)


# These states make button permissions and round order explicit.
enum RoundState {
	ROUND_START,
	PLANNING,
	RESOLVING_CHANT,
	ENEMY_PHASE,
	ROUND_END,
	COMBAT_ENDED
}


# Current state is public so CombatUIController can enable the correct controls.
var current_state: RoundState = RoundState.ROUND_START

# The first call to _start_next_round changes this from 0 to 1.
var round_number: int = 0

# The three chant slots hold freely chosen runes from the wheel.
var selected_runes: Array[SymbolCardData] = []

# The UI marks this slot and rune clicks place or replace here.
var selected_slot_index: int = 0

# There is only one enemy target in the full-rune-palette prototype.
var selected_target: EnemyUnit

# CombatManager provides these references during scene setup.
var combat_manager: CombatManager
var chant_resolver: ChantResolver
var discovery_manager: SpellDiscoveryManager
var ui_controller: CombatUIController
var combat_log: CombatLog
var balance: CombatBalanceData

# Used to distinguish explicit slot replacement from the "first empty slot"
# shortcut when the player simply clicks runes in sequence.
var _slot_was_explicitly_selected: bool = false

# A missing Inspector resource uses this safe in-memory default.
var _fallback_balance: CombatBalanceData


# CombatManager calls this once after all child nodes are ready.
func configure(
	manager: CombatManager,
	resolver: ChantResolver,
	discovery: SpellDiscoveryManager,
	ui: CombatUIController,
	log: CombatLog
) -> void:
	combat_manager = manager
	chant_resolver = resolver
	discovery_manager = discovery
	ui_controller = ui
	combat_log = log
	_clear_selected_runes()
	_validate_chant_slot_count()


# CombatManager calls this after setup.
func start_combat() -> void:
	round_number = 0
	selected_slot_index = 0
	_clear_selected_runes()
	_start_next_round()


# CombatUIController calls this when the player clicks a chant slot.
func select_slot(slot_index: int) -> void:
	if get_tree().paused:
		return
	if current_state != RoundState.PLANNING:
		return
	if slot_index < 0 or slot_index >= selected_runes.size():
		return
	selected_slot_index = slot_index
	_slot_was_explicitly_selected = true
	slot_selected.emit(slot_index)
	selected_slot_changed.emit(slot_index)
	_emit_selection_changed()
	ui_controller.refresh_all()


# Rune button shortcut: fill the selected empty slot, otherwise the first empty
# slot, otherwise replace the currently selected slot.
func place_rune_in_selected_slot(rune: SymbolCardData) -> void:
	var slot_index := selected_slot_index
	if not _slot_was_explicitly_selected and _slot_has_rune(slot_index):
		var first_empty := _first_empty_slot()
		if first_empty != -1:
			slot_index = first_empty
	place_rune_in_slot(rune, slot_index)


# CombatUIController can call this directly for future explicit slot UI.
func place_rune_in_slot(rune: SymbolCardData, slot_index: int) -> void:
	if get_tree().paused:
		return
	if current_state != RoundState.PLANNING:
		return
	if rune == null or slot_index < 0 or slot_index >= selected_runes.size():
		return
	if not _get_balance().allow_repeated_runes and _rune_used_elsewhere(rune, slot_index):
		return

	selected_runes[slot_index] = rune
	selected_slot_index = slot_index
	_slot_was_explicitly_selected = false
	rune_placed.emit(rune, slot_index)

	if _get_balance().auto_advance_slot_after_rune_pick:
		_advance_selected_slot()

	_emit_selection_changed()
	ui_controller.refresh_all()


# Optional Clear Slot behavior for keyboard/controller or future UI.
func clear_slot(slot_index: int) -> void:
	if get_tree().paused:
		return
	if current_state != RoundState.PLANNING:
		return
	if slot_index < 0 or slot_index >= selected_runes.size():
		return
	selected_runes[slot_index] = null
	selected_slot_index = slot_index
	_slot_was_explicitly_selected = true
	_emit_selection_changed()
	ui_controller.refresh_all()


# The Clear Chant button calls this during planning.
func clear_chant() -> void:
	if get_tree().paused:
		return
	if current_state != RoundState.PLANNING:
		return
	_clear_selected_runes()
	chant_cleared.emit()
	_emit_selection_changed()
	ui_controller.refresh_all()


# CombatUIController uses this to enable Cast only for a complete legal chant.
func can_cast() -> bool:
	if get_tree().paused:
		return false
	if current_state != RoundState.PLANNING:
		return false
	if selected_target == null or not selected_target.is_alive:
		return false
	for rune: SymbolCardData in selected_runes:
		if rune == null:
			return false
	return true


# The Cast button calls this. Selected runes are sent directly to ChantResolver.
func cast_chant() -> void:
	if get_tree().paused:
		return
	if not can_cast():
		return

	current_state = RoundState.RESOLVING_CHANT
	combat_manager.set_phase_text("Resolving chant")
	ui_controller.set_input_enabled(false)
	casting_started.emit()

	var cast_runes: Array[SymbolCardData] = []
	for selected_rune: SymbolCardData in selected_runes:
		cast_runes.append(selected_rune)
	var cast_target := selected_target
	chant_cast_started.emit(cast_runes, cast_target)
	if ui_controller != null:
		await ui_controller.play_chant_shout(cast_runes)

	var result := chant_resolver.resolve_chant(
		cast_runes,
		cast_target,
		combat_manager.get_combat_context()
	)
	if discovery_manager != null:
		discovery_manager.record_chant_result(
			result,
			result.get("recipe") as SpellRecipeData,
			round_number,
			cast_target.enemy_name if cast_target != null else ""
		)
	chant_resolved.emit(result)
	_append_result_to_log(result)
	if ui_controller != null:
		ui_controller.show_spell_result(result)
	ui_controller.refresh_all()
	casting_finished.emit()

	if combat_manager.check_combat_end():
		return

	if _get_balance().enemy_phase_after_chant:
		current_state = RoundState.ENEMY_PHASE
		combat_manager.set_phase_text("Enemy phase")
		enemy_phase_started.emit()
		await _execute_enemy_phase()

		if combat_manager.check_combat_end():
			return

	current_state = RoundState.ROUND_END
	combat_manager.set_phase_text("Round end")
	_end_round_updates()
	round_ended.emit(round_number)
	ui_controller.refresh_all()

	await get_tree().create_timer(
		maxf(0.0, _get_balance().next_round_delay_seconds)
	).timeout
	_start_next_round()


# CombatManager calls this after Victory or Defeat.
func end_combat() -> void:
	current_state = RoundState.COMBAT_ENDED
	_clear_selected_runes()
	selected_target = null


# This starts every round in the same readable sequence:
# clear selection, generate visible intent, then enable planning.
func _start_next_round() -> void:
	if current_state == RoundState.COMBAT_ENDED:
		return

	round_number += 1
	current_state = RoundState.ROUND_START
	if round_number == 1 or _get_balance().clear_chant_after_cast:
		_clear_selected_runes()
	selected_target = combat_manager.get_first_living_enemy()

	combat_manager.set_round_number(round_number)
	combat_log.append_separator()
	combat_log.append_line(
		"Round %d begins." % round_number,
		Color(0.95, 0.78, 0.38)
	)
	round_started.emit(round_number)

	_generate_enemy_intents()

	current_state = RoundState.PLANNING
	combat_manager.set_phase_text("Planning")
	planning_started.emit()
	player_phase_started.emit()
	_emit_selection_changed()
	ui_controller.show_planning()


# Enemy intent must exist before the player chooses a chant.
func _generate_enemy_intents() -> void:
	var living_mages := combat_manager.get_living_mages()
	for enemy: EnemyUnit in combat_manager.get_living_enemies():
		enemy.generate_intent(living_mages)
	ui_controller.refresh_enemy_intents()


# The single enemy acts only after the chant.
func _execute_enemy_phase() -> void:
	for enemy: EnemyUnit in combat_manager.get_living_enemies():
		enemy.execute_intent(combat_manager.get_living_mages())
		if not enemy.last_action_log.is_empty():
			combat_log.append_line(enemy.last_action_log)
		ui_controller.refresh_all()

		if combat_manager.check_combat_end():
			return

		await get_tree().create_timer(
			maxf(0.0, _get_balance().enemy_action_delay_seconds)
		).timeout


# End-of-round updates preserve previous-round attack history.
func _end_round_updates() -> void:
	for enemy: EnemyUnit in combat_manager.enemies:
		enemy.end_round()


# ChantResolver returns an array of lines so presentation remains decoupled.
func _append_result_to_log(result: Dictionary) -> void:
	var log_lines: Array = result.get("log_lines", [])
	for line: Variant in log_lines:
		combat_log.append_line(String(line))


# Typed arrays are filled explicitly because chant slots intentionally contain null.
func _clear_selected_runes() -> void:
	selected_runes.clear()
	for slot_index: int in range(_supported_chant_rune_count()):
		selected_runes.append(null)
	selected_slot_index = 0
	_slot_was_explicitly_selected = false


func _slot_has_rune(slot_index: int) -> bool:
	return (
		slot_index >= 0
		and slot_index < selected_runes.size()
		and selected_runes[slot_index] != null
	)


func _first_empty_slot() -> int:
	for slot_index: int in range(selected_runes.size()):
		if selected_runes[slot_index] == null:
			return slot_index
	return -1


func _advance_selected_slot() -> void:
	var first_empty := _first_empty_slot()
	if first_empty != -1:
		selected_slot_index = first_empty
		selected_slot_changed.emit(selected_slot_index)
		return
	selected_slot_index = mini(selected_slot_index + 1, selected_runes.size() - 1)
	selected_slot_changed.emit(selected_slot_index)


func _emit_selection_changed() -> void:
	selected_runes_changed.emit(selected_runes.duplicate())
	cast_availability_changed.emit(can_cast())


func _rune_used_elsewhere(rune: SymbolCardData, slot_index: int) -> bool:
	for index: int in range(selected_runes.size()):
		if index != slot_index and selected_runes[index] == rune:
			return true
	return false


# The graybox scene has exactly three chant slots.
func _supported_chant_rune_count() -> int:
	return 3


# Keep the balance knob visible without allowing an unsafe UI mismatch.
func _validate_chant_slot_count() -> void:
	if _get_balance().required_chant_cards != _supported_chant_rune_count():
		push_warning(
			"Current graybox UI supports exactly 3 chant slots. "
			+ "Keep required_chant_cards at 3 for now."
		)


# Missing scene wiring should warn but should not crash combat setup.
func _get_balance() -> CombatBalanceData:
	if balance != null:
		return balance
	if _fallback_balance == null:
		_fallback_balance = CombatBalanceData.new()
		push_warning(
			"RoundManager has no CombatBalanceData assigned; using script defaults."
		)
	return _fallback_balance
