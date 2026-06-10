extends Node
class_name RoundManager

signal round_started(round_number: int)
signal planning_started
signal action_queued(action: CombatAction)
signal resolve_started
signal round_ended(round_number: int)

enum RoundState {
	ROUND_START,
	PLANNING,
	RESOLVING_HERO_ACTIONS,
	ENEMY_PHASE,
	ROUND_END,
	COMBAT_ENDED
}

var current_state: RoundState = RoundState.ROUND_START
var round_number: int = 0
var queued_actions: Array[CombatAction] = []

var combat_manager: CombatManager
var reaction_manager: ReactionManager
var ui_controller: CombatUIController


func configure(
	manager: CombatManager,
	reactions: ReactionManager,
	ui: CombatUIController
) -> void:
	combat_manager = manager
	reaction_manager = reactions
	ui_controller = ui


func start_combat() -> void:
	round_number = 0
	_start_next_round()


func queue_action(action: CombatAction) -> void:
	if current_state != RoundState.PLANNING or action == null or action.actor == null:
		return

	for index: int in range(queued_actions.size() - 1, -1, -1):
		if queued_actions[index].actor == action.actor:
			queued_actions.remove_at(index)

	# Re-queuing a hero moves that action to the end, so click order is resolve order.
	queued_actions.append(action)
	action_queued.emit(action)
	ui_controller.update_queued_actions(queued_actions, combat_manager.get_living_heroes())


func resolve_round() -> void:
	if current_state != RoundState.PLANNING:
		return
	if queued_actions.size() < combat_manager.get_living_heroes().size():
		return

	current_state = RoundState.RESOLVING_HERO_ACTIONS
	resolve_started.emit()
	combat_manager.set_phase_text("Resolving hero actions")
	ui_controller.set_resolving(true)

	for action: CombatAction in queued_actions.duplicate():
		if action.actor != null and action.actor.is_alive:
			await _execute_hero_action(action)
			if combat_manager.check_combat_end():
				return

	current_state = RoundState.ENEMY_PHASE
	combat_manager.set_phase_text("Enemy phase")
	await _run_enemy_phase()
	if combat_manager.check_combat_end():
		return

	current_state = RoundState.ROUND_END
	combat_manager.set_phase_text("Round end")
	await reaction_manager.resolve_round_end()
	if combat_manager.check_combat_end():
		return

	round_ended.emit(round_number)
	await get_tree().create_timer(0.35).timeout
	_start_next_round()


func end_combat() -> void:
	current_state = RoundState.COMBAT_ENDED
	queued_actions.clear()


func _start_next_round() -> void:
	if current_state == RoundState.COMBAT_ENDED:
		return

	round_number += 1
	current_state = RoundState.ROUND_START
	queued_actions.clear()
	round_started.emit(round_number)
	combat_manager.set_round_number(round_number)
	combat_manager.combat_log.append_separator()
	combat_manager.combat_log.append_event(
		"Round %d begins." % round_number,
		Color(0.95, 0.78, 0.38)
	)

	_generate_enemy_intents()

	current_state = RoundState.PLANNING
	combat_manager.set_phase_text("Planning")
	planning_started.emit()
	ui_controller.show_planning(combat_manager.get_living_heroes())


func _generate_enemy_intents() -> void:
	var heroes := combat_manager.get_living_heroes()
	var intent_lines: PackedStringArray = []
	for enemy: EnemyUnit in combat_manager.get_living_enemies():
		var intent := enemy.generate_intent(heroes)
		if not intent.is_empty():
			intent_lines.append(String(intent.get("description", "")))
	ui_controller.show_enemy_intents(intent_lines)


func _run_enemy_phase() -> void:
	for enemy: EnemyUnit in combat_manager.get_living_enemies():
		var target := enemy.current_intent.get("target") as HeroUnit
		if target == null or not target.is_alive:
			enemy.generate_intent(combat_manager.get_living_heroes())

		var event_data := enemy.execute_intent()
		if not event_data.is_empty():
			await reaction_manager.resolve_event(event_data)
			if combat_manager.check_combat_end():
				return


func _execute_hero_action(action: CombatAction) -> void:
	match action.action_id:
		&"strike":
			await _execute_strike(action)
		&"push":
			await _execute_push(action)
		&"shoot":
			await _execute_shoot(action)
		&"cut_rope":
			var rope_log := action.target as ReactionObject
			if rope_log == null or rope_log.is_destroyed:
				return
			await reaction_manager.resolve_event({
				"type": &"rope_cut",
				"source": action.actor,
				"target": rope_log,
				"zone": rope_log.current_zone,
				"log": "%s cuts the Rope Log's line." % action.actor.unit_name
			})
		&"ignite":
			await reaction_manager.resolve_event({
				"type": &"fire_created",
				"source": action.actor,
				"zone": action.target_zone,
				"log": "%s ignites %s." % [
					action.actor.unit_name,
					action.target_zone.display_name
				]
			})
		&"throw_oil":
			action.target_zone.add_hazard(&"oil")
			await reaction_manager.resolve_event({
				"type": &"oil_spilled",
				"source": action.actor,
				"zone": action.target_zone,
				"log": "%s throws oil into %s." % [
					action.actor.unit_name,
					action.target_zone.display_name
				]
			})


func _execute_strike(action: CombatAction) -> void:
	var target := action.target as CombatUnit
	if target == null or not target.is_alive:
		return
	target.take_damage(action.damage)
	await reaction_manager.resolve_event({
		"type": &"unit_damaged",
		"source": action.actor,
		"target": target,
		"zone": target.current_zone,
		"amount": action.damage,
		"log": "%s strikes %s for %d damage." % [
			action.actor.unit_name,
			target.unit_name,
			action.damage
		]
	})


func _execute_push(action: CombatAction) -> void:
	var target := action.target as CombatUnit
	if target == null or not target.is_alive or action.target_zone == null:
		return
	if not target.move_to_zone(action.target_zone):
		return
	await reaction_manager.resolve_event({
		"type": &"unit_pushed",
		"source": action.actor,
		"target": target,
		"zone": action.target_zone,
		"log": "%s pushes %s into %s." % [
			action.actor.unit_name,
			target.unit_name,
			action.target_zone.display_name
		]
	})


func _execute_shoot(action: CombatAction) -> void:
	if action.target is CombatUnit:
		var target_unit := action.target as CombatUnit
		if target_unit == null or not target_unit.is_alive:
			return
		target_unit.take_damage(action.damage)
		await reaction_manager.resolve_event({
			"type": &"unit_damaged",
			"source": action.actor,
			"target": target_unit,
			"zone": target_unit.current_zone,
			"amount": action.damage,
			"log": "%s shoots %s for %d damage." % [
				action.actor.unit_name,
				target_unit.unit_name,
				action.damage
			]
		})
	elif action.target is ReactionObject:
		var target_object := action.target as ReactionObject
		if target_object == null or target_object.is_destroyed:
			return
		await reaction_manager.resolve_event({
			"type": &"object_hit",
			"source": action.actor,
			"target": target_object,
			"zone": target_object.current_zone,
			"log": "%s shoots %s." % [
				action.actor.unit_name,
				target_object.display_name
			]
		})
