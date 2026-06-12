# RoundManager.gd
# Attach this script to the RoundManager node in CombatScene.tscn.
# It owns the order of phases, the three selected cards, and the selected enemy.
# Chant effects stay in ChantResolver; scene-level victory checks stay in CombatManager.
extends Node
class_name RoundManager


# Emitted when a new numbered round starts.
# CombatUIController can use it for round presentation.
signal round_started(round_number: int)

# Emitted after enemy intents exist and card selection is enabled.
signal planning_started

# Emitted when one mage card fills or replaces its matching chant slot.
signal chant_card_selected(card: SymbolCardData, slot_index: int)

# Emitted when all three chant slots are cleared.
signal chant_cleared

# Emitted immediately before ChantResolver applies the selected combination.
signal chant_cast_started(symbols: Array[SymbolCardData], target: EnemyUnit)

# Emitted after ChantResolver returns its result Dictionary.
signal chant_resolved(result: Dictionary)

# Emitted before surviving enemies execute their visible intents.
signal enemy_phase_started

# Emitted after statuses update and hands optionally draw to the configured maximum.
signal round_ended(round_number: int)


# Assign CombatBalance_Default.tres here to tune hand refill and phase delays.
@export_group("Balance")
@export var balance: CombatBalanceData


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

# Slots map directly to CombatManager.mages order: mage 1, mage 2, mage 3.
var selected_cards: Array[SymbolCardData] = []

# The player chooses one living enemy before Cast becomes available.
var selected_target: EnemyUnit

# CombatManager provides these references during scene setup.
var combat_manager: CombatManager
var deck_manager: DeckManager
var chant_resolver: ChantResolver
var discovery_manager: SpellDiscoveryManager
var ui_controller: CombatUIController
var combat_log: CombatLog

# A missing Inspector resource uses this safe in-memory default.
var _fallback_balance: CombatBalanceData


# CombatManager calls this once after all child nodes are ready.
func configure(
	manager: CombatManager,
	deck: DeckManager,
	resolver: ChantResolver,
	discovery: SpellDiscoveryManager,
	ui: CombatUIController,
	log: CombatLog
) -> void:
	combat_manager = manager
	deck_manager = deck
	chant_resolver = resolver
	discovery_manager = discovery
	ui_controller = ui
	combat_log = log
	_clear_selected_cards()
	_validate_chant_slot_count()


# CombatManager calls this after opening hands have been dealt.
func start_combat() -> void:
	round_number = 0
	_clear_selected_cards()
	_start_next_round()


# CombatUIController calls this when the player clicks a card.
# Each mage owns one fixed slot, so selecting another card replaces that slot.
func select_chant_card(mage: MageUnit, card: SymbolCardData) -> void:
	if get_tree().paused:
		return
	if current_state != RoundState.PLANNING:
		return
	if mage == null or card == null or not mage.is_alive:
		return
	if not mage.hand.has(card):
		return

	var slot_index := combat_manager.mages.find(mage)
	if slot_index < 0 or slot_index >= selected_cards.size():
		return

	selected_cards[slot_index] = card
	chant_card_selected.emit(card, slot_index)
	ui_controller.refresh_all()


# The Clear Chant button calls this during planning.
func clear_chant() -> void:
	if get_tree().paused:
		return
	if current_state != RoundState.PLANNING:
		return
	_clear_selected_cards()
	chant_cleared.emit()
	ui_controller.refresh_all()


# CombatUIController calls this when the target drop-down changes.
func select_target(enemy: EnemyUnit) -> void:
	if get_tree().paused:
		return
	if current_state != RoundState.PLANNING:
		return
	if enemy != null and enemy.is_alive:
		selected_target = enemy
		ui_controller.refresh_cast_controls()


# CombatUIController uses this to enable Cast only for a complete legal chant.
func can_cast() -> bool:
	if get_tree().paused:
		return false
	if current_state != RoundState.PLANNING:
		return false
	if selected_target == null or not selected_target.is_alive:
		return false
	for card: SymbolCardData in selected_cards:
		if card == null:
			return false
	return true


# The Cast button calls this.
# It resolves the chant, runs enemies, updates statuses, refills hands, and loops.
func cast_chant() -> void:
	if get_tree().paused:
		return
	if not can_cast():
		return

	current_state = RoundState.RESOLVING_CHANT
	combat_manager.set_phase_text("Resolving chant")
	ui_controller.set_input_enabled(false)

	var cast_cards: Array[SymbolCardData] = []
	for selected_card: SymbolCardData in selected_cards:
		cast_cards.append(selected_card)
	var cast_target := selected_target
	chant_cast_started.emit(cast_cards, cast_target)

	# Used cards leave each mage hand before disasters can discard another card.
	for slot_index: int in range(selected_cards.size()):
		var mage: MageUnit = combat_manager.mages[slot_index]
		mage.discard_card(cast_cards[slot_index])

	var result := chant_resolver.resolve_chant(
		cast_cards,
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
	ui_controller.refresh_all()

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
	_clear_selected_cards()
	selected_target = null


# This starts every round in the same readable sequence:
# clear selection, generate visible intents, then enable planning.
func _start_next_round() -> void:
	if current_state == RoundState.COMBAT_ENDED:
		return

	round_number += 1
	current_state = RoundState.ROUND_START
	_clear_selected_cards()
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
	ui_controller.show_planning()


# Enemy intents must exist before the player chooses a chant.
func _generate_enemy_intents() -> void:
	var living_mages := combat_manager.get_living_mages()
	for enemy: EnemyUnit in combat_manager.get_living_enemies():
		enemy.generate_intent(living_mages)
	ui_controller.refresh_enemy_intents()


# Enemies act only after the chant.
# If a target died during the chant, EnemyUnit selects a living replacement.
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


# End-of-round updates preserve last-round attack history and refill each hand.
func _end_round_updates() -> void:
	for enemy: EnemyUnit in combat_manager.enemies:
		enemy.end_round()

	if _get_balance().draw_to_max_hand_at_round_end:
		for mage: MageUnit in combat_manager.get_living_mages():
			mage.draw_to_hand_size(maxi(0, _get_balance().max_hand_size))


# ChantResolver returns an array of lines so presentation remains decoupled.
func _append_result_to_log(result: Dictionary) -> void:
	var log_lines: Array = result.get("log_lines", [])
	for line: Variant in log_lines:
		combat_log.append_line(String(line))


# Typed arrays are filled explicitly because chant slots intentionally contain null.
func _clear_selected_cards() -> void:
	selected_cards.clear()
	for slot_index: int in range(_supported_chant_card_count()):
		selected_cards.append(null)


# The graybox scene has exactly three visual slots and three mage rows.
func _supported_chant_card_count() -> int:
	return 3


# Keep the requested Inspector knob visible without allowing an unsafe UI mismatch.
func _validate_chant_slot_count() -> void:
	if _get_balance().required_chant_cards != _supported_chant_card_count():
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
