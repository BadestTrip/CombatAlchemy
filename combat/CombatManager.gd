extends Control
class_name CombatManager

signal combat_started
signal combat_ended(victory: bool)
signal unit_damaged(unit: CombatUnit, amount: int)
signal unit_died(unit: CombatUnit)

const ZONE_ADJACENCY := {
	&"left_back": [&"mid_back", &"left_mid", &"center"],
	&"mid_back": [&"left_back", &"right_back", &"left_mid", &"center", &"right_mid"],
	&"right_back": [&"mid_back", &"center", &"right_mid"],
	&"left_mid": [&"left_back", &"mid_back", &"center", &"left_front", &"mid_front"],
	&"center": [
		&"left_back",
		&"mid_back",
		&"right_back",
		&"left_mid",
		&"right_mid",
		&"left_front",
		&"mid_front",
		&"right_front"
	],
	&"right_mid": [&"mid_back", &"right_back", &"center", &"mid_front", &"right_front"],
	&"left_front": [&"left_mid", &"center", &"mid_front"],
	&"mid_front": [&"left_mid", &"center", &"right_mid", &"left_front", &"right_front"],
	&"right_front": [&"center", &"right_mid", &"mid_front"]
}

@onready var round_manager: RoundManager = %RoundManager
@onready var reaction_manager: ReactionManager = %ReactionManager
@onready var ui_controller: CombatUIController = %CombatUI
@onready var combat_log: CombatLog = %CombatLog
@onready var board: GridContainer = %Board
@onready var heroes_root: Node = %Heroes
@onready var enemies_root: Node = %Enemies
@onready var objects_root: Node = %ReactionObjects
@onready var round_label: Label = %RoundLabel
@onready var phase_label: Label = %PhaseLabel

var heroes: Array[HeroUnit] = []
var enemies: Array[EnemyUnit] = []
var zones: Array[CombatZone] = []
var reaction_objects: Array[ReactionObject] = []
var zone_by_id: Dictionary = {}
var has_combat_ended: bool = false


func _ready() -> void:
	_collect_scene_entities()
	_configure_adjacency()
	_place_scene_entities()
	_connect_entity_signals()

	reaction_manager.configure(self, combat_log)
	round_manager.configure(self, reaction_manager, ui_controller)
	ui_controller.configure(self, round_manager)

	combat_log.append_event(
		"Three heroes face a bandit ambush on a trapped bridge."
	)
	combat_started.emit()
	round_manager.start_combat()


func get_zone(zone_id: StringName) -> CombatZone:
	return zone_by_id.get(zone_id) as CombatZone


func get_living_heroes() -> Array[HeroUnit]:
	var living: Array[HeroUnit] = []
	for hero: HeroUnit in heroes:
		if hero.is_alive:
			living.append(hero)
	return living


func get_living_enemies() -> Array[EnemyUnit]:
	var living: Array[EnemyUnit] = []
	for enemy: EnemyUnit in enemies:
		if enemy.is_alive:
			living.append(enemy)
	return living


func get_valid_targets(hero: HeroUnit, action_id: StringName) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if hero == null or hero.current_zone == null:
		return targets

	match action_id:
		&"strike":
			for enemy: EnemyUnit in get_living_enemies():
				if (
					enemy.current_zone == hero.current_zone
					or hero.current_zone.is_adjacent_to(enemy.current_zone)
				):
					targets.append(_unit_target_data(enemy))
		&"push":
			for enemy: EnemyUnit in get_living_enemies():
				if enemy.current_zone != hero.current_zone:
					continue
				for destination: CombatZone in hero.current_zone.adjacent_zones:
					if destination.can_enter():
						targets.append({
							"label": "%s -> %s" % [
								enemy.unit_name,
								destination.display_name
							],
							"target": enemy,
							"target_zone": destination
						})
		&"shoot":
			for enemy: EnemyUnit in get_living_enemies():
				targets.append(_unit_target_data(enemy))
			for object: ReactionObject in reaction_objects:
				if not object.is_destroyed and object.current_zone != null:
					targets.append({
						"label": "Object: %s (%s)" % [
							object.display_name,
							object.current_zone.display_name
						],
						"target": object,
						"target_zone": object.current_zone
					})
		&"cut_rope":
			for object: ReactionObject in reaction_objects:
				if not object.is_destroyed and object.object_type == &"rope_log":
					targets.append({
						"label": "%s (%s)" % [
							object.display_name,
							object.current_zone.display_name
						],
						"target": object,
						"target_zone": object.current_zone
					})
		&"ignite", &"throw_oil":
			for zone: CombatZone in zones:
				if zone.can_enter():
					targets.append({
						"label": zone.display_name,
						"target": null,
						"target_zone": zone
					})

	return targets


func create_action(
	hero: HeroUnit,
	action_id: StringName,
	target_data: Dictionary
) -> CombatAction:
	var target: Variant = target_data.get("target")
	var target_zone := target_data.get("target_zone") as CombatZone
	var action := CombatAction.new(
		action_id,
		hero.get_action_display_name(action_id),
		hero,
		target,
		target_zone
	)

	match action_id:
		&"strike":
			action.action_type = &"damage"
			action.damage = 4
			action.creates_event = &"unit_damaged"
		&"push":
			action.action_type = &"movement"
			action.push_distance = 1
			action.creates_event = &"unit_pushed"
		&"shoot":
			action.action_type = &"ranged"
			action.damage = 3
			action.creates_event = (
				&"object_hit" if target is ReactionObject else &"unit_damaged"
			)
		&"cut_rope":
			action.action_type = &"interaction"
			action.creates_event = &"rope_cut"
		&"ignite":
			action.action_type = &"hazard"
			action.creates_event = &"fire_created"
		&"throw_oil":
			action.action_type = &"hazard"
			action.creates_event = &"oil_spilled"

	return action


func check_combat_end() -> bool:
	if has_combat_ended:
		return true
	if get_living_enemies().is_empty():
		_end_combat(true)
		return true
	if get_living_heroes().is_empty():
		_end_combat(false)
		return true
	return false


func set_round_number(number: int) -> void:
	round_label.text = "Round %d" % number


func set_phase_text(phase_name: String) -> void:
	phase_label.text = phase_name


func _end_combat(victory: bool) -> void:
	if has_combat_ended:
		return
	has_combat_ended = true
	round_manager.end_combat()
	set_phase_text("Combat ended")
	combat_log.append_separator()
	combat_log.append_event(
		"Victory! All enemies are defeated." if victory
		else "Defeat! All heroes have fallen.",
		Color(0.52, 0.9, 0.48) if victory else Color(1.0, 0.42, 0.36)
	)
	ui_controller.show_result(victory)
	combat_ended.emit(victory)


func _collect_scene_entities() -> void:
	for child: Node in board.get_children():
		var zone := child as CombatZone
		if zone != null:
			zones.append(zone)
			zone_by_id[zone.zone_id] = zone

	for child: Node in heroes_root.get_children():
		var hero := child as HeroUnit
		if hero != null:
			heroes.append(hero)

	for child: Node in enemies_root.get_children():
		var enemy := child as EnemyUnit
		if enemy != null:
			enemies.append(enemy)

	for child: Node in objects_root.get_children():
		var object := child as ReactionObject
		if object != null:
			reaction_objects.append(object)


func _configure_adjacency() -> void:
	for zone: CombatZone in zones:
		var adjacent: Array[CombatZone] = []
		var adjacent_ids: Array = ZONE_ADJACENCY.get(zone.zone_id, [])
		for adjacent_id: StringName in adjacent_ids:
			var adjacent_zone := get_zone(adjacent_id)
			if adjacent_zone != null:
				adjacent.append(adjacent_zone)
		zone.set_adjacent_zones(adjacent)


func _place_scene_entities() -> void:
	for hero: HeroUnit in heroes:
		hero.move_to_zone(get_zone(hero.starting_zone_id))
	for enemy: EnemyUnit in enemies:
		enemy.move_to_zone(get_zone(enemy.starting_zone_id))
	for object: ReactionObject in reaction_objects:
		object.move_to_zone(get_zone(object.starting_zone_id))


func _connect_entity_signals() -> void:
	for hero: HeroUnit in heroes:
		hero.unit_damaged.connect(_on_unit_damaged)
		hero.unit_died.connect(_on_unit_died)
	for enemy: EnemyUnit in enemies:
		enemy.unit_damaged.connect(_on_unit_damaged)
		enemy.unit_died.connect(_on_unit_died)


func _unit_target_data(unit: CombatUnit) -> Dictionary:
	return {
		"label": "%s (%s, %d HP)" % [
			unit.unit_name,
			unit.current_zone.display_name,
			unit.current_hp
		],
		"target": unit,
		"target_zone": unit.current_zone
	}


func _on_unit_damaged(unit: CombatUnit, amount: int) -> void:
	unit_damaged.emit(unit, amount)
	if unit.current_zone != null:
		unit.current_zone.refresh_display()


func _on_unit_died(unit: CombatUnit) -> void:
	combat_log.append_event(
		"%s is defeated." % unit.unit_name,
		Color(1.0, 0.52, 0.42)
	)
	unit_died.emit(unit)
