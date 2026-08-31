extends Node2D

# Responsibility: Verify flying and placed PotionEntity collisions consume one potion cleanly.

const DAMAGE_POTION := preload("res://combat/potions/resources/DamagePotion.tres")
const POTION_ENTITY_SCENE := preload("res://combat/potions/PotionEntity.tscn")
const TARGET_SCENE := preload("res://combat/actors/TargetActor.tscn")

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _test_actor_area_collision_resolves_once()
	await _test_plain_wall_collision()
	await _test_high_speed_thin_wall_collision()
	await _test_high_speed_thin_actor_area_collision()
	await _test_caster_body_and_child_hitbox_are_excluded()
	await _test_flight_expiration_consumes_instance()
	await _test_placed_target_waits_for_arming()
	await _test_placed_caster_requires_exit_and_reentry()
	await _test_placed_unsupported_target_is_consumed()
	for delay in [0.35, 0.0]:
		await _test_idle_placement_source_requires_exit_and_reentry(delay)
		await _test_idle_placement_source_starts_outside(delay)
		await _test_idle_placement_non_source_already_overlaps(delay)
	if _failures.is_empty():
		print("PotionEntityCollisionTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PotionEntityCollisionTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _test_actor_area_collision_resolves_once() -> void:
	var caster := Node2D.new()
	var target := TARGET_SCENE.instantiate() as Node2D
	_expect(target != null, "target scene instantiates")
	if target == null:
		return
	add_child(caster)
	add_child(target)
	var health := target.get_node_or_null(^"HealthComponent") as HealthComponent
	_expect(health != null, "target exposes its health component")
	if health == null:
		_cleanup([caster, target])
		return
	health.current_health = 100
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, caster)
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: contexts.append(context))
	_expect(entity.throw_into(self, target.global_position, Vector2.RIGHT), "held entity enters flight")
	await _wait_for_consumption(entity)
	_expect(health.current_health == 70, "actor-area overlap applies damage exactly once")
	_expect(contexts.size() == 1 and contexts[0].collider == target.get_node(^"ImpactHitbox"), "actor-area emits one hitbox resolution")
	_expect(potion.is_consumed(), "actor-area impact consumes its potion instance")
	_expect(not is_instance_valid(entity), "actor-area impact consumes the entity")
	_cleanup([caster, target])


func _test_plain_wall_collision() -> void:
	var caster := Node2D.new()
	var wall := _new_wall(Vector2(80.0, 80.0), Vector2.ZERO)
	add_child(caster)
	add_child(wall)
	await get_tree().physics_frame
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, caster)
	var colliders: Array[Node] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: colliders.append(context.collider))
	var flight_area := entity.get_node_or_null(^"FlightArea") as Area2D
	_expect(flight_area != null and (flight_area.collision_mask & 1) != 0, "flight mask includes plain world bodies")
	_expect(flight_area != null and flight_area.monitorable, "flight area remains monitorable")
	_expect(entity.throw_into(self, wall.global_position, Vector2.RIGHT), "entity launches into a plain wall")
	await _wait_for_consumption(entity)
	_expect(colliders == [wall], "plain wall is the entity's only impact")
	_expect(potion.is_consumed(), "plain wall consumes a potion without a receiver")
	_expect(not is_instance_valid(entity), "plain wall consumes the entity")
	_cleanup([caster, wall])


func _test_high_speed_thin_wall_collision() -> void:
	var caster := Node2D.new()
	var wall := _new_wall(Vector2(4.0, 100.0), Vector2(100.0, 0.0))
	add_child(caster)
	add_child(wall)
	await get_tree().physics_frame
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, caster)
	var colliders: Array[Node] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: colliders.append(context.collider))
	entity.flight_speed = 2000.0
	entity.set_physics_process(false)
	_expect(entity.throw_into(self, Vector2.ZERO, Vector2.RIGHT), "high-speed entity launches toward 4-pixel wall")
	entity.call(&"_physics_process", 0.1)
	await get_tree().process_frame
	_expect(colliders == [wall], "swept travel detects the 4-pixel wall crossed this frame")
	_expect(potion.is_consumed(), "thin wall consumes its potion instance")
	_expect(not is_instance_valid(entity), "thin wall consumes the high-speed entity")
	_cleanup([caster, wall])


func _test_high_speed_thin_actor_area_collision() -> void:
	var caster := Node2D.new()
	var subject := Node2D.new()
	subject.position = Vector2(100.0, 0.0)
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100
	subject.add_child(health)
	var hitbox := _new_hitbox(Vector2(4.0, 100.0))
	subject.add_child(hitbox)
	add_child(caster)
	add_child(subject)
	await get_tree().physics_frame
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, caster)
	var colliders: Array[Node] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: colliders.append(context.collider))
	entity.flight_speed = 2000.0
	entity.set_physics_process(false)
	_expect(entity.throw_into(self, Vector2.ZERO, Vector2.RIGHT), "high-speed entity launches toward a thin actor area")
	entity.call(&"_physics_process", 0.1)
	await get_tree().process_frame
	_expect(health.current_health == 70, "swept actor-area impact applies the supported health effect")
	_expect(colliders == [hitbox], "swept travel detects the thin actor hitbox")
	_expect(potion.is_consumed(), "thin actor-area impact consumes the potion instance")
	_expect(not is_instance_valid(entity), "thin actor hitbox consumes the high-speed entity")
	_cleanup([caster, subject])


func _test_caster_body_and_child_hitbox_are_excluded() -> void:
	var caster := CharacterBody2D.new()
	caster.collision_layer = 1
	caster.collision_mask = 0
	var caster_shape := CollisionShape2D.new()
	var caster_circle := CircleShape2D.new()
	caster_circle.radius = 28.0
	caster_shape.shape = caster_circle
	caster.add_child(caster_shape)
	var hitbox := _new_hitbox(Vector2(48.0, 48.0))
	caster.add_child(hitbox)
	var wall := _new_wall(Vector2(8.0, 100.0), Vector2(100.0, 0.0))
	add_child(caster)
	add_child(wall)
	await get_tree().physics_frame
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, caster)
	var colliders: Array[Node] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: colliders.append(context.collider))
	entity.flight_speed = 1000.0
	entity.set_physics_process(false)
	_expect(entity.throw_into(self, caster.global_position, Vector2.RIGHT), "entity launches from inside its caster")
	await get_tree().physics_frame
	await get_tree().process_frame
	_expect(is_instance_valid(entity), "caster body and child hitbox do not consume their entity")
	_expect(colliders.is_empty(), "caster overlap emits no accepted impact")
	entity.call(&"_physics_process", 0.15)
	await get_tree().process_frame
	_expect(colliders == [wall], "first non-caster collider receives the impact")
	_expect(potion.is_consumed(), "first non-caster collider consumes the potion instance")
	_expect(not is_instance_valid(entity), "first non-caster collider consumes the entity")
	_cleanup([caster, wall])


func _test_flight_expiration_consumes_instance() -> void:
	var caster := Node2D.new()
	add_child(caster)
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, caster)
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: contexts.append(context))
	entity.flight_speed = 0.0
	entity.flight_lifetime = 0.1
	entity.set_physics_process(false)
	_expect(entity.throw_into(self, Vector2.ZERO, Vector2.RIGHT), "flight-expiration entity enters flight")
	entity.call(&"_physics_process", 0.11)
	await get_tree().process_frame
	_expect(potion.is_consumed(), "flight expiration discards its potion instance")
	_expect(contexts.is_empty(), "flight expiration applies no effect resolution")
	_expect(not is_instance_valid(entity), "flight expiration consumes the entity")
	_cleanup([caster])


func _test_placed_target_waits_for_arming() -> void:
	var source := Node2D.new()
	var target := _new_actor(true)
	add_child(source)
	add_child(target)
	var health := target.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, source)
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: contexts.append(context))
	entity.set_physics_process(false)
	_expect(entity.place_into(self, Vector2.ZERO), "entity places beside stationary target")
	await get_tree().physics_frame
	await get_tree().physics_frame
	entity.call(&"_physics_process", 0.34)
	_expect(health.current_health == 100, "placement does not resolve before 0.35 seconds")
	_expect(entity.get_state() == PotionEntity.State.PLACED, "unarmed placement remains placed")
	entity.call(&"_physics_process", 0.02)
	await get_tree().process_frame
	_expect(health.current_health == 70, "stationary overlap resolves when arming completes")
	_expect(contexts.size() == 1 and contexts[0].delivery_method == PotionDelivery.PLACE, "placed collision resolves once with place delivery")
	_expect(potion.is_consumed(), "placed target overlap consumes potion instance")
	_expect(not is_instance_valid(entity), "placed target overlap consumes entity")
	_cleanup([source, target])


func _test_placed_caster_requires_exit_and_reentry() -> void:
	var source := _new_actor(true)
	add_child(source)
	var health := source.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, source)
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void: contexts.append(context))
	entity.set_physics_process(false)
	_expect(entity.place_into(self, Vector2.ZERO), "entity places over its caster")
	await get_tree().physics_frame
	await get_tree().physics_frame
	entity.call(&"_physics_process", 0.36)
	_expect(health.current_health == 100 and is_instance_valid(entity), "initial caster overlap remains ineligible after arming")
	source.position = Vector2(100.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(contexts.is_empty(), "caster exit does not resolve the placed potion")
	source.position = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_expect(health.current_health == 70, "caster becomes eligible after exit and re-entry")
	_expect(contexts.size() == 1, "caster re-entry resolves exactly once")
	_expect(potion.is_consumed(), "caster re-entry consumes potion instance")
	_expect(not is_instance_valid(entity), "caster re-entry consumes entity")
	_cleanup([source])


func _test_placed_unsupported_target_is_consumed() -> void:
	var source := Node2D.new()
	var unsupported := _new_actor(false)
	add_child(source)
	add_child(unsupported)
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, source)
	var applied_counts: Array[int] = []
	entity.resolved.connect(func(_context: PotionImpactContext, applied_count: int) -> void: applied_counts.append(applied_count))
	entity.set_physics_process(false)
	_expect(entity.place_into(self, Vector2.ZERO), "entity places over unsupported target")
	await get_tree().physics_frame
	await get_tree().physics_frame
	entity.call(&"_physics_process", 0.36)
	await get_tree().process_frame
	_expect(applied_counts == [0], "unsupported placed target reports zero applied effects")
	_expect(potion.is_consumed(), "unsupported placed target consumes potion instance")
	_expect(not is_instance_valid(entity), "unsupported placed target consumes entity")
	_cleanup([source, unsupported])


func _test_idle_placement_source_requires_exit_and_reentry(delay: float) -> void:
	# Start in idle, before the trigger has participated in any collision update.
	# Production physics stays enabled throughout placement, arming, and re-entry.
	await get_tree().process_frame
	var source := _new_actor(true)
	add_child(source)
	var health := source.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, source)
	entity.arming_delay = delay
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _count: int) -> void: contexts.append(context))
	_expect(entity.is_physics_processing(), "idle placement uses production physics")
	_expect(entity.place_into(self, Vector2.ZERO), "idle placement starts over source (delay %.2f)" % delay)
	await _wait_live_physics_frames(30)
	_expect(health.current_health == 100, "idle placement protects stationary initial source after arming (delay %.2f)" % delay)
	_expect(not potion.is_consumed() and is_instance_valid(entity), "idle placement keeps initial source bottle available (delay %.2f)" % delay)
	_expect(contexts.is_empty(), "idle placement emits no initial source resolution (delay %.2f)" % delay)
	source.position = Vector2(100.0, 0.0)
	await _wait_live_physics_frames(3)
	_expect(contexts.is_empty(), "idle placement source exit does not resolve (delay %.2f)" % delay)
	source.position = Vector2.ZERO
	await _wait_live_physics_frames(3)
	_expect(health.current_health == 70, "idle placement source re-entry applies damage (delay %.2f)" % delay)
	_expect(contexts.size() == 1 and contexts[0].subject == source and contexts[0].delivery_method == PotionDelivery.PLACE, "idle placement source re-entry resolves once with place delivery (delay %.2f)" % delay)
	_expect(potion.is_consumed() and not is_instance_valid(entity), "idle placement source re-entry consumes bottle (delay %.2f)" % delay)
	await _cleanup([source])


func _test_idle_placement_source_starts_outside(delay: float) -> void:
	await get_tree().process_frame
	var source := _new_actor(true)
	source.position = Vector2(100.0, 0.0)
	add_child(source)
	var health := source.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, source)
	entity.arming_delay = delay
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _count: int) -> void: contexts.append(context))
	_expect(entity.place_into(self, Vector2.ZERO), "idle placement starts outside source (delay %.2f)" % delay)
	await _wait_live_physics_frames(30)
	_expect(health.current_health == 100 and not potion.is_consumed(), "outside source does not trigger at arming (delay %.2f)" % delay)
	source.position = Vector2.ZERO
	await _wait_live_physics_frames(3)
	_expect(health.current_health == 70, "initially outside source triggers on first entry (delay %.2f)" % delay)
	_expect(contexts.size() == 1 and contexts[0].subject == source, "initially outside source resolves once (delay %.2f)" % delay)
	_expect(potion.is_consumed() and not is_instance_valid(entity), "initially outside source entry consumes bottle (delay %.2f)" % delay)
	await _cleanup([source])


func _test_idle_placement_non_source_already_overlaps(delay: float) -> void:
	await get_tree().process_frame
	var source := _new_actor(true)
	var target := _new_actor(true)
	target.position = Vector2(20.0, 0.0)
	add_child(source)
	add_child(target)
	var source_health := source.get_node(^"HealthComponent") as HealthComponent
	var target_health := target.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := _new_entity(potion, source)
	entity.arming_delay = delay
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _count: int) -> void: contexts.append(context))
	_expect(entity.place_into(self, Vector2.ZERO), "idle placement starts over source and target (delay %.2f)" % delay)
	if delay > 0.0:
		await _wait_live_physics_frames(10)
		_expect(target_health.current_health == 100 and not potion.is_consumed(), "live placement waits for arming before stationary target (delay %.2f)" % delay)
	await _wait_live_physics_frames(30)
	_expect(source_health.current_health == 100, "overlapping source stays immune beside target (delay %.2f)" % delay)
	_expect(target_health.current_health == 70, "already overlapping non-source triggers while source stays inside (delay %.2f)" % delay)
	_expect(contexts.size() == 1 and contexts[0].subject == target, "stationary non-source receives the only resolution (delay %.2f)" % delay)
	_expect(potion.is_consumed() and not is_instance_valid(entity), "stationary non-source consumes bottle (delay %.2f)" % delay)
	await _cleanup([source, target])


func _wait_live_physics_frames(count: int) -> void:
	for _step in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _new_entity(potion: PotionInstance, caster: Node) -> PotionEntity:
	var entity := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	add_child(entity)
	_expect(entity != null, "potion entity scene instantiates")
	if entity != null:
		_expect(entity.initialize(potion, caster), "entity initializes for collision")
	return entity


func _new_damage_potion() -> PotionInstance:
	return PotionInstance.create(DAMAGE_POTION, [PotionReagent.GREEN, PotionReagent.GREEN, PotionReagent.BLUE])


func _new_wall(size: Vector2, wall_position: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = wall_position
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)
	return wall


func _new_actor(with_health: bool) -> Node2D:
	var actor := Node2D.new()
	if with_health:
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		health.max_health = 100
		health.current_health = 100
		actor.add_child(health)
	actor.add_child(_new_hitbox(Vector2(24.0, 24.0)))
	return actor


func _new_hitbox(size: Vector2) -> ImpactHitbox:
	var hitbox := ImpactHitbox.new()
	hitbox.name = "ImpactHitbox"
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.monitorable = true
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	hitbox.add_child(shape)
	return hitbox


func _wait_for_consumption(entity: Node) -> void:
	for _physics_step in range(4):
		await get_tree().physics_frame
		await get_tree().process_frame
		if not is_instance_valid(entity):
			return


func _cleanup(nodes: Array[Node]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
