# CombatUIController.gd
# Attach this script to the CombatUI VBoxContainer in CombatScene.tscn.
# It builds graybox status panels and card buttons, then forwards player choices
# to RoundManager. It does not calculate spell effects or round rules.
extends VBoxContainer
class_name CombatUIController


# These node paths assume the exact child names used in CombatScene.tscn.
@onready var mage_statuses: VBoxContainer = %MageStatuses
@onready var enemy_statuses: VBoxContainer = %EnemyStatuses
@onready var enemy_intents: RichTextLabel = %EnemyIntents
@onready var chant_slot_1: Label = %ChantSlot1
@onready var chant_slot_2: Label = %ChantSlot2
@onready var chant_slot_3: Label = %ChantSlot3
@onready var chant_preview: Label = %ChantPreview
@onready var mage_hands: VBoxContainer = %MageHands
@onready var target_select: OptionButton = %TargetSelect
@onready var cast_button: Button = %CastButton
@onready var clear_button: Button = %ClearButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton


# CombatManager provides these references after all nodes are ready.
var combat_manager: CombatManager
var round_manager: RoundManager
var combat_log: CombatLog

# Card buttons are tracked so resolving phases can disable them immediately.
var _card_buttons: Array[Button] = []

# This prevents target list rebuilding from triggering selection callbacks.
var _is_refreshing_targets: bool = false


# Godot calls this when the UI node enters the scene.
func _ready() -> void:
	cast_button.pressed.connect(_on_cast_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	target_select.item_selected.connect(_on_target_selected)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	result_panel.visible = false


# CombatManager calls this before RoundManager starts round one.
func configure(
	manager: CombatManager,
	rounds: RoundManager,
	log: CombatLog
) -> void:
	combat_manager = manager
	round_manager = rounds
	combat_log = log


# RoundManager calls this after intents are generated.
func show_planning() -> void:
	result_panel.visible = false
	set_input_enabled(true)
	refresh_all()


# Managers call this after cards, HP, shield, intents, or selection changes.
func refresh_all() -> void:
	if combat_manager == null or round_manager == null:
		return
	_refresh_unit_statuses()
	refresh_enemy_intents()
	_refresh_chant_slots()
	_refresh_mage_hands()
	_refresh_target_options()
	refresh_cast_controls()


# RoundManager uses this during resolution and enemy actions.
func set_input_enabled(enabled: bool) -> void:
	for button: Button in _card_buttons:
		button.disabled = not enabled
	target_select.disabled = not enabled
	cast_button.disabled = not enabled
	clear_button.disabled = not enabled


# This updates only buttons whose state depends on a complete chant and target.
func refresh_cast_controls() -> void:
	if round_manager == null:
		return
	cast_button.disabled = not round_manager.can_cast()
	clear_button.disabled = (
		round_manager.current_state != RoundManager.RoundState.PLANNING
		or _selected_card_count() == 0
	)


# Enemy intents are visible before Cast, as required by the round flow.
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


# Slots always follow mage order, which makes chant order unambiguous.
func _refresh_chant_slots() -> void:
	var slot_labels: Array[Label] = [chant_slot_1, chant_slot_2, chant_slot_3]
	var preview_words: PackedStringArray = []

	for index: int in range(3):
		var card: SymbolCardData = round_manager.selected_cards[index]
		if card == null:
			slot_labels[index].text = "Slot %d\n---" % (index + 1)
			preview_words.append("...")
		else:
			slot_labels[index].text = "Slot %d\n%s  %s" % [
				index + 1,
				card.visual_hint,
				card.spoken_word
			]
			preview_words.append(card.spoken_word)

	chant_preview.text = "  >  ".join(preview_words)


# Each living mage gets one row containing its current three clickable cards.
func _refresh_mage_hands() -> void:
	_card_buttons.clear()
	_clear_children(mage_hands)

	for mage_index: int in range(combat_manager.mages.size()):
		var mage: MageUnit = combat_manager.mages[mage_index]
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)
		mage_hands.add_child(section)

		var title := Label.new()
		title.text = "%s hand - Chant Slot %d" % [mage.mage_name, mage_index + 1]
		title.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
		section.add_child(title)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		section.add_child(row)

		for card: SymbolCardData in mage.hand:
			var card_button := Button.new()
			card_button.custom_minimum_size = Vector2(145.0, 72.0)
			card_button.text = "%s\n%s\n%s" % [
				card.visual_hint,
				card.spoken_word,
				card.display_name
			]
			card_button.tooltip_text = "%s symbol card" % card.spoken_word

			if round_manager.selected_cards[mage_index] == card:
				card_button.text = "[SELECTED]\n" + card_button.text

			card_button.disabled = (
				not mage.is_alive
				or round_manager.current_state != RoundManager.RoundState.PLANNING
			)
			card_button.pressed.connect(_on_card_pressed.bind(mage, card))
			row.add_child(card_button)
			_card_buttons.append(card_button)


# The target drop-down contains only living enemies.
func _refresh_target_options() -> void:
	_is_refreshing_targets = true
	target_select.clear()

	var selected_index := -1
	var living_enemies := combat_manager.get_living_enemies()
	for index: int in range(living_enemies.size()):
		var enemy: EnemyUnit = living_enemies[index]
		target_select.add_item("%s - %d HP / %d Shield" % [
			enemy.enemy_name,
			enemy.current_hp,
			enemy.shield
		])
		target_select.set_item_metadata(index, enemy)
		if enemy == round_manager.selected_target:
			selected_index = index

	if target_select.item_count > 0:
		if selected_index < 0:
			selected_index = 0
			round_manager.selected_target = target_select.get_item_metadata(0) as EnemyUnit
		target_select.select(selected_index)

	target_select.disabled = (
		target_select.item_count == 0
		or round_manager.current_state != RoundManager.RoundState.PLANNING
	)
	_is_refreshing_targets = false


# Card clicks are forwarded to RoundManager, which validates mage, card, and phase.
func _on_card_pressed(mage: MageUnit, card: SymbolCardData) -> void:
	round_manager.select_chant_card(mage, card)


func _on_target_selected(index: int) -> void:
	if _is_refreshing_targets or index < 0:
		return
	var enemy := target_select.get_item_metadata(index) as EnemyUnit
	round_manager.select_target(enemy)


func _on_cast_pressed() -> void:
	round_manager.cast_chant()


func _on_clear_pressed() -> void:
	round_manager.clear_chant()


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
func _selected_card_count() -> int:
	var count := 0
	for card: SymbolCardData in round_manager.selected_cards:
		if card != null:
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
