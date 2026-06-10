extends VBoxContainer
class_name CombatUIController

@onready var enemy_intents: RichTextLabel = $EnemyIntents
@onready var hero_action_rows: VBoxContainer = $HeroActionRows
@onready var queued_actions_label: RichTextLabel = $QueuedActions
@onready var resolve_button: Button = $ResolveButton
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/Margin/VBox/ResultLabel
@onready var restart_button: Button = $ResultPanel/Margin/VBox/Buttons/RestartButton
@onready var main_menu_button: Button = $ResultPanel/Margin/VBox/Buttons/MainMenuButton

var combat_manager: CombatManager
var round_manager: RoundManager
var _hero_controls: Dictionary = {}


func _ready() -> void:
	resolve_button.pressed.connect(_on_resolve_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	result_panel.visible = false
	resolve_button.disabled = true


func configure(manager: CombatManager, rounds: RoundManager) -> void:
	combat_manager = manager
	round_manager = rounds


func show_enemy_intents(intent_lines: PackedStringArray) -> void:
	enemy_intents.clear()
	if intent_lines.is_empty():
		enemy_intents.append_text("No enemy intents.")
		return
	for line: String in intent_lines:
		enemy_intents.append_text("- %s\n" % line)


func show_planning(heroes: Array[HeroUnit]) -> void:
	result_panel.visible = false
	set_resolving(false)
	_clear_hero_rows()

	for hero: HeroUnit in heroes:
		_build_hero_row(hero)

	queued_actions_label.clear()
	queued_actions_label.append_text("Queue one action for each living hero.")
	resolve_button.disabled = true


func update_queued_actions(
	actions: Array[CombatAction],
	living_heroes: Array[HeroUnit]
) -> void:
	queued_actions_label.clear()
	for index: int in range(actions.size()):
		queued_actions_label.append_text(
			"%d. %s\n" % [index + 1, actions[index].get_summary()]
		)

	resolve_button.disabled = (
		actions.is_empty()
		or actions.size() < living_heroes.size()
		or round_manager.current_state != RoundManager.RoundState.PLANNING
	)


func set_resolving(is_resolving: bool) -> void:
	for controls_value: Variant in _hero_controls.values():
		var controls: Dictionary = controls_value
		(controls["action_select"] as OptionButton).disabled = is_resolving
		(controls["target_select"] as OptionButton).disabled = is_resolving
		(controls["queue_button"] as Button).disabled = is_resolving
	resolve_button.disabled = is_resolving


func show_result(victory: bool) -> void:
	set_resolving(true)
	result_panel.visible = true
	result_label.text = "Victory" if victory else "Defeat"
	result_label.add_theme_color_override(
		"font_color",
		Color(0.52, 0.9, 0.48) if victory else Color(1.0, 0.42, 0.36)
	)
	restart_button.disabled = false
	main_menu_button.disabled = false


func _build_hero_row(hero: HeroUnit) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.15, 0.95)
	style.border_color = Color(0.3, 0.36, 0.38)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	hero_action_rows.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var title := Label.new()
	title.text = "%s - %d/%d HP - %s" % [
		hero.unit_name,
		hero.current_hp,
		hero.max_hp,
		hero.current_zone.display_name
	]
	title.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	content.add_child(title)

	var selectors := HBoxContainer.new()
	selectors.add_theme_constant_override("separation", 6)
	content.add_child(selectors)

	var action_select := OptionButton.new()
	action_select.custom_minimum_size.x = 120.0
	for action_id: StringName in hero.available_actions:
		action_select.add_item(hero.get_action_display_name(action_id))
		action_select.set_item_metadata(action_select.item_count - 1, action_id)
	selectors.add_child(action_select)

	var target_select := OptionButton.new()
	target_select.custom_minimum_size.x = 230.0
	target_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(target_select)

	var queue_button := Button.new()
	queue_button.text = "Queue"
	queue_button.custom_minimum_size.x = 80.0
	selectors.add_child(queue_button)

	var hero_id := hero.get_instance_id()
	var controls := {
		"hero": hero,
		"action_select": action_select,
		"target_select": target_select,
		"queue_button": queue_button
	}
	_hero_controls[hero_id] = controls

	action_select.item_selected.connect(_on_action_selected.bind(hero_id))
	target_select.item_selected.connect(_on_target_selected.bind(hero_id))
	queue_button.pressed.connect(_on_queue_pressed.bind(hero_id))
	_refresh_targets(hero_id)


func _refresh_targets(hero_id: int) -> void:
	var controls: Dictionary = _hero_controls.get(hero_id, {})
	if controls.is_empty():
		return

	var hero := controls["hero"] as HeroUnit
	var action_select := controls["action_select"] as OptionButton
	var target_select := controls["target_select"] as OptionButton
	var queue_button := controls["queue_button"] as Button
	var action_id := StringName(action_select.get_item_metadata(action_select.selected))
	var targets := combat_manager.get_valid_targets(hero, action_id)

	target_select.clear()
	for target_data: Dictionary in targets:
		target_select.add_item(String(target_data.get("label", "Target")))
		target_select.set_item_metadata(target_select.item_count - 1, target_data)

	target_select.disabled = targets.is_empty()
	queue_button.disabled = targets.is_empty()


func _clear_hero_rows() -> void:
	_hero_controls.clear()
	for child: Node in hero_action_rows.get_children():
		hero_action_rows.remove_child(child)
		child.queue_free()


func _on_action_selected(_index: int, hero_id: int) -> void:
	_refresh_targets(hero_id)


func _on_target_selected(_index: int, hero_id: int) -> void:
	var controls: Dictionary = _hero_controls.get(hero_id, {})
	if controls.is_empty():
		return
	var target_select := controls["target_select"] as OptionButton
	(controls["queue_button"] as Button).disabled = target_select.item_count == 0


func _on_queue_pressed(hero_id: int) -> void:
	var controls: Dictionary = _hero_controls.get(hero_id, {})
	if controls.is_empty():
		return

	var hero := controls["hero"] as HeroUnit
	var action_select := controls["action_select"] as OptionButton
	var target_select := controls["target_select"] as OptionButton
	if target_select.item_count == 0:
		return

	var action_id := StringName(action_select.get_item_metadata(action_select.selected))
	var target_data: Dictionary = target_select.get_item_metadata(target_select.selected)
	var action := combat_manager.create_action(hero, action_id, target_data)
	round_manager.queue_action(action)
	(controls["queue_button"] as Button).text = "Queued"


func _on_resolve_pressed() -> void:
	round_manager.resolve_round()


func _on_restart_pressed() -> void:
	restart_button.disabled = true
	main_menu_button.disabled = true
	GameManager.restart_combat()


func _on_main_menu_pressed() -> void:
	restart_button.disabled = true
	main_menu_button.disabled = true
	GameManager.go_to_main_menu()
