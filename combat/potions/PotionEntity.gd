class_name PotionEntity
extends Node2D

# Responsibility: Represent one potion as the same scene node while held, flying, or placed.

enum State { HELD, FLYING, PLACED, CONSUMED }

signal state_changed(state: State)
signal resolved(context: PotionImpactContext, applied_effect_count: int)

@export_range(0.0, 2000.0, 1.0) var flight_speed := 650.0
@export_range(0.01, 10.0, 0.01) var flight_lifetime := 2.5
@export_range(0.0, 2.0, 0.01) var arming_delay := 0.35
@export_range(0.1, 120.0, 0.1) var placed_lifetime := 20.0

@onready var _bottle_visual: Polygon2D = $BottleVisual
@onready var _outline: Line2D = $Outline
@onready var _flight_area: Area2D = $FlightArea
@onready var _sweep_cast: ShapeCast2D = $SweepCast
@onready var _placement_trigger: Area2D = $PlacementTrigger

var _potion: PotionInstance
var _source: Node
var _state: State = State.HELD
var _initialized := false
var _direction := Vector2.RIGHT
var _flight_elapsed := 0.0
var _arming_elapsed := 0.0
var _placed_elapsed := 0.0
var _armed := false
var _source_can_trigger := false
var _source_gate_initialized := false
var _source_overlap_ids: Dictionary = {}


## Binds one unused runtime potion to this scene node.
func initialize(potion: PotionInstance, source: Node) -> bool:
	if (
		_initialized
		or potion == null
		or not potion.is_valid()
		or potion.is_consumed()
	):
		return false
	_potion = potion
	_source = source
	_initialized = true
	_set_visual_color(potion.get_color())
	_set_state(State.HELD)
	return true


## Moves a held entity to a holder socket at local origin.
func attach_to(holder: Node2D) -> bool:
	if not _can_transition_from_held() or not _can_reparent_to(holder):
		return false
	reparent(holder, true)
	position = Vector2.ZERO
	return true


## Applies a held potion directly to a target.
func drink(target: Node) -> bool:
	if not _can_transition_from_held() or target == null or not is_instance_valid(target):
		return false
	var target_position := global_position
	if target is Node2D:
		target_position = (target as Node2D).global_position
	var context := PotionImpactContext.new().configure(
		target,
		target,
		_source,
		target_position,
		Vector2.UP,
		PotionDelivery.DRINK
	)
	return _consume(context)


## Releases a held entity into flight without replacing the scene node.
func throw_into(
	world_parent: Node2D,
	origin: Vector2,
	direction: Vector2
) -> bool:
	if not _can_transition_from_held() or not _can_reparent_to(world_parent):
		return false
	reparent(world_parent, true)
	global_position = origin
	_direction = (
		direction.normalized()
		if direction.length_squared() > 0.000001
		else Vector2.RIGHT
	)
	_flight_elapsed = 0.0
	_sweep_cast.collision_mask = _flight_area.collision_mask
	_configure_source_exceptions()
	_set_state(State.FLYING)
	return true


## Releases a held entity as an armed proximity potion without replacing the scene node.
func place_into(world_parent: Node2D, world_position: Vector2) -> bool:
	if not _can_transition_from_held() or not _can_reparent_to(world_parent):
		return false
	reparent(world_parent, true)
	global_position = world_position
	_arming_elapsed = 0.0
	_placed_elapsed = 0.0
	_armed = false
	_source_overlap_ids.clear()
	_source_can_trigger = _source == null or not is_instance_valid(_source)
	_source_gate_initialized = _source_can_trigger
	_set_state(State.PLACED)
	return true


## Consumes an initialized entity without applying effects.
func discard() -> bool:
	if not _initialized or _state != State.HELD:
		return false
	return _consume()


func get_state() -> State:
	return _state


func get_potion() -> PotionInstance:
	return _potion


func _physics_process(delta: float) -> void:
	match _state:
		State.FLYING:
			_process_flight(delta)
		State.PLACED:
			_process_placement(delta)


func _process_flight(delta: float) -> void:
	var travel := _direction * flight_speed * delta
	if _sweep_for_impact(travel):
		return
	global_position += travel
	_flight_elapsed += delta
	if _flight_elapsed >= flight_lifetime:
		_consume()


func _process_placement(delta: float) -> void:
	_placed_elapsed += delta
	_arming_elapsed += delta
	if _placed_elapsed >= placed_lifetime:
		_consume()
		return
	if not _source_gate_initialized:
		_initialize_source_gate()
	if not _armed and _arming_elapsed >= arming_delay:
		_armed = true
		_resolve_nearest_placement_overlap()


func _on_flight_area_entered(area: Area2D) -> void:
	_try_flight_impact(area)


func _on_flight_body_entered(body: Node2D) -> void:
	_try_flight_impact(body)


func _try_flight_impact(
	collider: Node,
	impact_position: Vector2 = global_position
) -> void:
	if _state != State.FLYING or collider == null or _belongs_to_source(collider):
		return
	var context := _new_impact_context(
		collider,
		impact_position,
		_direction,
		PotionDelivery.THROW
	)
	_consume(context)


func _sweep_for_impact(travel: Vector2) -> bool:
	if travel.is_zero_approx() or _sweep_cast == null:
		return false
	_sweep_cast.target_position = _sweep_cast.to_local(_sweep_cast.global_position + travel)
	_sweep_cast.force_shapecast_update()

	var closest_collider: Node
	var closest_point := global_position + travel
	var closest_distance_squared := INF
	for collision_index in range(_sweep_cast.get_collision_count()):
		var collider := _sweep_cast.get_collider(collision_index) as Node
		if collider == null or _belongs_to_source(collider):
			continue
		var collision_point := _sweep_cast.get_collision_point(collision_index)
		var distance_squared := global_position.distance_squared_to(collision_point)
		if distance_squared < closest_distance_squared:
			closest_collider = collider
			closest_point = collision_point
			closest_distance_squared = distance_squared
	if closest_collider == null:
		return false
	_try_flight_impact(closest_collider, closest_point)
	return true


func _configure_source_exceptions() -> void:
	_sweep_cast.clear_exceptions()
	if _source != null and is_instance_valid(_source):
		_add_collision_exception_tree(_source)


func _add_collision_exception_tree(node: Node) -> void:
	if node is CollisionObject2D:
		_sweep_cast.add_exception(node as CollisionObject2D)
	for child in node.get_children():
		_add_collision_exception_tree(child)


func _on_placement_area_entered(area: Area2D) -> void:
	_on_placement_collider_entered(area)


func _on_placement_body_entered(body: Node2D) -> void:
	_on_placement_collider_entered(body)


func _on_placement_area_exited(area: Area2D) -> void:
	_on_placement_collider_exited(area)


func _on_placement_body_exited(body: Node2D) -> void:
	_on_placement_collider_exited(body)


func _on_placement_collider_entered(collider: Node) -> void:
	if _state != State.PLACED or collider == null:
		return
	if _belongs_to_source(collider) and not _source_can_trigger:
		_source_overlap_ids[collider.get_instance_id()] = true
		return
	if _armed:
		_resolve_placement_collider(collider)


func _on_placement_collider_exited(collider: Node) -> void:
	if _state != State.PLACED or collider == null or not _belongs_to_source(collider):
		return
	_source_overlap_ids.erase(collider.get_instance_id())
	if _source_gate_initialized and _source_overlap_ids.is_empty():
		_source_can_trigger = true


func _initialize_source_gate() -> void:
	if not _placement_trigger.monitoring:
		return
	_source_overlap_ids.clear()
	for area in _placement_trigger.get_overlapping_areas():
		if _belongs_to_source(area):
			_source_overlap_ids[area.get_instance_id()] = true
	for body in _placement_trigger.get_overlapping_bodies():
		if _belongs_to_source(body):
			_source_overlap_ids[body.get_instance_id()] = true
	_source_can_trigger = _source_overlap_ids.is_empty()
	_source_gate_initialized = true


func _resolve_nearest_placement_overlap() -> void:
	if _state != State.PLACED or not _armed:
		return
	var closest_collider: Node2D
	var closest_distance_squared := INF
	var overlapping_colliders: Array[Node2D] = []
	overlapping_colliders.append_array(_placement_trigger.get_overlapping_areas())
	overlapping_colliders.append_array(_placement_trigger.get_overlapping_bodies())
	for collider in overlapping_colliders:
		if not _is_eligible_placement_collider(collider):
			continue
		var distance_squared := global_position.distance_squared_to(collider.global_position)
		if distance_squared < closest_distance_squared:
			closest_collider = collider
			closest_distance_squared = distance_squared
	if closest_collider != null:
		_resolve_placement_collider(closest_collider)


func _resolve_placement_collider(collider: Node) -> void:
	if not _is_eligible_placement_collider(collider):
		return
	var subject := _effect_subject_for(collider)
	var subject_position := global_position
	if subject is Node2D:
		subject_position = (subject as Node2D).global_position
	elif collider is Node2D:
		subject_position = (collider as Node2D).global_position
	var direction := subject_position - global_position
	if direction.length_squared() <= 0.000001:
		direction = Vector2.UP
	var context := PotionImpactContext.new().configure(
		subject,
		collider,
		_source,
		subject_position,
		direction,
		PotionDelivery.PLACE
	)
	_consume(context)


func _is_eligible_placement_collider(collider: Node) -> bool:
	if (
		_state != State.PLACED
		or not _armed
		or collider == null
		or not is_instance_valid(collider)
	):
		return false
	return not _belongs_to_source(collider) or _source_can_trigger


func _new_impact_context(
	collider: Node,
	impact_position: Vector2,
	direction: Vector2,
	delivery_method: StringName
) -> PotionImpactContext:
	return PotionImpactContext.new().configure(
		_effect_subject_for(collider),
		collider,
		_source,
		impact_position,
		direction,
		delivery_method
	)


func _effect_subject_for(collider: Node) -> Node:
	var subject := collider
	if collider != null and collider.has_method(&"get_effect_subject"):
		var configured_subject := collider.call(&"get_effect_subject") as Node
		if configured_subject != null:
			subject = configured_subject
	return subject


func _belongs_to_source(collider: Node) -> bool:
	if _source == null or not is_instance_valid(_source):
		return false
	return collider == _source or _source.is_ancestor_of(collider)


func _can_transition_from_held() -> bool:
	return (
		_initialized
		and _state == State.HELD
		and _potion != null
		and not _potion.is_consumed()
	)


func _can_reparent_to(new_parent: Node2D) -> bool:
	return (
		new_parent != null
		and is_instance_valid(new_parent)
		and new_parent != self
		and not is_ancestor_of(new_parent)
		and get_parent() != null
	)


func _consume(context: PotionImpactContext = null) -> bool:
	if not _initialized or _state == State.CONSUMED or _potion == null:
		return false
	var applied_effect_count := 0
	if context != null:
		applied_effect_count = _potion.apply(context)
	else:
		_potion.discard()
	_set_state(State.CONSUMED)
	if context != null:
		resolved.emit(context, applied_effect_count)
	queue_free()
	return true


func _set_state(next_state: State) -> void:
	var changed := _state != next_state
	_state = next_state
	match _state:
		State.HELD:
			_flight_area.set_deferred(&"monitoring", false)
			_placement_trigger.set_deferred(&"monitoring", false)
			_sweep_cast.enabled = false
		State.FLYING:
			_flight_area.set_deferred(&"monitoring", true)
			_placement_trigger.set_deferred(&"monitoring", false)
			_sweep_cast.enabled = true
		State.PLACED:
			_flight_area.set_deferred(&"monitoring", false)
			_placement_trigger.set_deferred(&"monitoring", true)
			_sweep_cast.enabled = false
		State.CONSUMED:
			_flight_area.set_deferred(&"monitoring", false)
			_placement_trigger.set_deferred(&"monitoring", false)
			_sweep_cast.enabled = false
	if changed:
		state_changed.emit(_state)


func _set_visual_color(color: Color) -> void:
	_bottle_visual.color = color
	_outline.default_color = color.lightened(0.25)
