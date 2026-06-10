extends Node
class_name ReactionManager

signal combat_event_emitted(event_data: Dictionary)
signal reaction_resolved(event_data: Dictionary)
signal object_destroyed(object: ReactionObject)
signal zone_hazard_added(zone: CombatZone, hazard_id: StringName)

@export var reaction_delay: float = 0.18

var combat_manager: CombatManager
var combat_log: CombatLog

var _event_queue: Array[Dictionary] = []
var _processed_signatures: Dictionary = {}
var _is_resolving: bool = false


func configure(manager: CombatManager, log: CombatLog) -> void:
	combat_manager = manager
	combat_log = log


func resolve_event(event_data: Dictionary) -> void:
	if event_data.is_empty():
		return

	_event_queue.append(event_data)
	if _is_resolving:
		return

	_is_resolving = true
	_processed_signatures.clear()

	# Reactions append follow-up events to this queue. Signatures stop cycles
	# within one action while allowing the same reaction in a later action.
	while not _event_queue.is_empty():
		var next_event: Dictionary = _event_queue.pop_front()
		var signature := _event_signature(next_event)
		if _processed_signatures.has(signature):
			continue
		_processed_signatures[signature] = true

		combat_event_emitted.emit(next_event)
		_write_event_log(next_event)
		_handle_event(next_event)
		reaction_resolved.emit(next_event)

		if reaction_delay > 0.0:
			await get_tree().create_timer(reaction_delay).timeout

	_is_resolving = false


func resolve_round_end() -> void:
	await resolve_event({
		"type": &"round_end",
		"log": "End-of-round hazards resolve."
	})


func _handle_event(event_data: Dictionary) -> void:
	var event_type := StringName(event_data.get("type", &""))
	match event_type:
		&"object_hit":
			_handle_object_hit(event_data)
		&"object_ignited":
			_handle_object_ignited(event_data)
		&"oil_spilled":
			_handle_oil_spilled(event_data)
		&"fire_created":
			_handle_fire_created(event_data)
		&"explosion_created":
			_handle_explosion(event_data)
		&"rope_cut":
			_handle_rope_cut(event_data)
		&"bridge_collapsed":
			_handle_bridge_collapse(event_data)
		&"unit_pushed":
			_handle_unit_pushed(event_data)
		&"round_end":
			_handle_round_end()


func _handle_object_hit(event_data: Dictionary) -> void:
	var object := event_data.get("target") as ReactionObject
	if object == null or not object.receive_event(event_data):
		return

	object.trigger_reaction(event_data)
	match object.object_type:
		&"oil_jar":
			_spill_oil_jar(object)
		&"campfire":
			_queue_event({
				"type": &"fire_created",
				"source": object,
				"zone": object.current_zone,
				"log": "%s flares up." % object.display_name
			})


func _spill_oil_jar(oil_jar: ReactionObject) -> void:
	var origin := oil_jar.current_zone
	if origin == null:
		return

	var affected: Array[CombatZone] = []
	affected.append(origin)
	affected.append_array(origin.adjacent_zones)
	oil_jar.destroy()
	object_destroyed.emit(oil_jar)

	var zone_names: PackedStringArray = []
	for zone: CombatZone in affected:
		if zone.has_hazard(&"collapsed"):
			continue
		zone.add_hazard(&"oil")
		zone_hazard_added.emit(zone, &"oil")
		zone_names.append(zone.display_name)
		_queue_event({
			"type": &"oil_spilled",
			"source": oil_jar,
			"zone": zone
		})

	if combat_log != null:
		combat_log.append_event(
			"Oil spills across %s." % ", ".join(zone_names),
			Color(0.86, 0.76, 0.35)
		)


func _handle_oil_spilled(event_data: Dictionary) -> void:
	var zone := event_data.get("zone") as CombatZone
	if zone != null and zone.has_hazard(&"fire"):
		_queue_event({
			"type": &"fire_created",
			"source": event_data.get("source"),
			"zone": zone,
			"log": "Oil catches fire in %s." % zone.display_name
		})


func _handle_fire_created(event_data: Dictionary) -> void:
	var zone := event_data.get("zone") as CombatZone
	if zone == null or zone.has_hazard(&"collapsed"):
		return

	var oil_caught := zone.has_hazard(&"oil")
	if oil_caught:
		zone.remove_hazard(&"oil")
	zone.add_hazard(&"fire")
	zone_hazard_added.emit(zone, &"fire")

	if oil_caught:
		if combat_log != null:
			combat_log.append_event(
				"Oil catches fire in %s." % zone.display_name,
				Color(1.0, 0.48, 0.18)
			)
		for adjacent_zone: CombatZone in zone.adjacent_zones:
			if adjacent_zone.has_hazard(&"oil"):
				_queue_event({
					"type": &"fire_created",
					"source": event_data.get("source"),
					"zone": adjacent_zone
				})

	for object: ReactionObject in zone.get_reaction_objects():
		if object.is_destroyed:
			continue
		match object.object_type:
			&"explosive_barrel":
				_queue_event({
					"type": &"object_ignited",
					"source": event_data.get("source"),
					"target": object,
					"zone": zone
				})
			&"weak_bridge":
				object.state = &"burning"


func _handle_object_ignited(event_data: Dictionary) -> void:
	var object := event_data.get("target") as ReactionObject
	if object == null or object.is_destroyed:
		return
	if object.object_type != &"explosive_barrel":
		return

	var zone := object.current_zone
	if zone == null:
		return
	object.trigger_reaction(event_data)
	object.destroy()
	object_destroyed.emit(object)
	_queue_event({
		"type": &"explosion_created",
		"source": object,
		"zone": zone,
		"log": "%s explodes in %s!" % [object.display_name, zone.display_name]
	})


func _handle_explosion(event_data: Dictionary) -> void:
	var origin := event_data.get("zone") as CombatZone
	if origin == null:
		return

	var affected: Array[CombatZone] = []
	affected.append(origin)
	affected.append_array(origin.adjacent_zones)

	for zone: CombatZone in affected:
		for unit: CombatUnit in zone.get_living_units():
			unit.take_damage(4)
			_queue_event({
				"type": &"unit_damaged",
				"source": event_data.get("source"),
				"target": unit,
				"zone": zone,
				"amount": 4,
				"log": "%s takes 4 explosion damage." % unit.unit_name
			})

		for object: ReactionObject in zone.get_reaction_objects():
			if object.is_destroyed:
				continue
			match object.object_type:
				&"explosive_barrel":
					_queue_event({
						"type": &"object_ignited",
						"source": event_data.get("source"),
						"target": object,
						"zone": zone
					})
				&"weak_bridge":
					_queue_event({
						"type": &"bridge_collapsed",
						"source": event_data.get("source"),
						"target": object,
						"zone": zone
					})
				&"oil_jar":
					_queue_event({
						"type": &"object_hit",
						"source": event_data.get("source"),
						"target": object,
						"zone": zone
					})


func _handle_rope_cut(event_data: Dictionary) -> void:
	var rope_log := event_data.get("target") as ReactionObject
	if rope_log == null or rope_log.is_destroyed:
		return

	var target_zone := combat_manager.get_zone(rope_log.target_zone_id)
	if target_zone == null:
		return

	rope_log.trigger_reaction(event_data)
	rope_log.destroy()
	object_destroyed.emit(rope_log)
	if combat_log != null:
		combat_log.append_event(
			"Rope Log crashes into %s." % target_zone.display_name,
			Color(0.78, 0.58, 0.32)
		)

	for unit: CombatUnit in target_zone.get_living_units():
		unit.take_damage(3)
		_queue_event({
			"type": &"unit_damaged",
			"source": rope_log,
			"target": unit,
			"zone": target_zone,
			"amount": 3,
			"log": "%s takes 3 damage from the falling log." % unit.unit_name
		})


func _handle_bridge_collapse(event_data: Dictionary) -> void:
	var bridge := event_data.get("target") as ReactionObject
	if bridge == null or bridge.is_destroyed:
		return

	var zone := bridge.current_zone
	if zone == null:
		return

	bridge.trigger_reaction(event_data)
	bridge.destroy()
	object_destroyed.emit(bridge)
	zone.add_hazard(&"collapsed")
	zone_hazard_added.emit(zone, &"collapsed")
	if combat_log != null:
		combat_log.append_event(
			"Weak Bridge collapses in %s." % zone.display_name,
			Color(0.95, 0.55, 0.28)
		)

	for unit: CombatUnit in zone.get_living_units():
		unit.take_damage(3)
		_queue_event({
			"type": &"unit_damaged",
			"source": bridge,
			"target": unit,
			"zone": zone,
			"amount": 3,
			"log": "%s takes 3 collapse damage." % unit.unit_name
		})


func _handle_unit_pushed(event_data: Dictionary) -> void:
	var unit := event_data.get("target") as CombatUnit
	var zone := event_data.get("zone") as CombatZone
	if unit == null or zone == null or not unit.is_alive:
		return

	if zone.has_hazard(&"fire"):
		unit.take_damage(2)
		_queue_event({
			"type": &"unit_damaged",
			"source": event_data.get("source"),
			"target": unit,
			"zone": zone,
			"amount": 2,
			"log": "%s is pushed into fire for 2 damage." % unit.unit_name
		})

	for object: ReactionObject in zone.get_reaction_objects():
		if not object.is_destroyed and object.object_type == &"campfire":
			_queue_event({
				"type": &"fire_created",
				"source": unit,
				"zone": zone,
				"log": "%s crashes into the Campfire." % unit.unit_name
			})


func _handle_round_end() -> void:
	for zone: CombatZone in combat_manager.zones:
		if zone.has_hazard(&"fire"):
			for unit: CombatUnit in zone.get_living_units():
				unit.take_damage(1)
				_queue_event({
					"type": &"unit_damaged",
					"source": zone,
					"target": unit,
					"zone": zone,
					"amount": 1,
					"log": "%s takes 1 fire damage in %s." % [
						unit.unit_name,
						zone.display_name
					]
				})

			for object: ReactionObject in zone.get_reaction_objects():
				if (
					not object.is_destroyed
					and object.object_type == &"weak_bridge"
					and object.state == &"burning"
				):
					_queue_event({
						"type": &"bridge_collapsed",
						"source": zone,
						"target": object,
						"zone": zone
					})


func _queue_event(event_data: Dictionary) -> void:
	if not event_data.is_empty():
		_event_queue.append(event_data)


func _write_event_log(event_data: Dictionary) -> void:
	if combat_log == null:
		return
	var message := String(event_data.get("log", ""))
	if not message.is_empty():
		combat_log.append_event(message)


func _event_signature(event_data: Dictionary) -> String:
	var event_type := String(event_data.get("type", "unknown"))
	var source_id := _instance_id_for(event_data.get("source"))
	var target_id := _instance_id_for(event_data.get("target"))
	var zone := event_data.get("zone") as CombatZone
	var zone_id := String(zone.zone_id) if zone != null else "none"
	return "%s:%d:%d:%s" % [event_type, source_id, target_id, zone_id]


func _instance_id_for(value: Variant) -> int:
	if value is Object and is_instance_valid(value):
		return (value as Object).get_instance_id()
	return 0
