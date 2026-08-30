extends Node2D

# Responsibility: Verify one physical potion entity preserves identity and resolves once.

const DAMAGE_POTION := preload("res://combat/potions/resources/DamagePotion.tres")
const POTION_ENTITY_SCENE := preload("res://combat/potions/PotionEntity.tscn")

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _test_state_transitions_preserve_identity()
	await _test_drink_resolves_once()
	await _test_placement_arming_and_stationary_overlap()
	await _test_source_requires_exit_before_reentry()
	await _test_unsupported_placement_consumes_without_applying()
	await _test_placed_and_flying_lifetimes_discard()
	if _failures.is_empty():
		print("PotionEntityTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("PotionEntityTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _test_state_transitions_preserve_identity() -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var source := Node2D.new()
	var holder := Marker2D.new()
	var world := Node2D.new()
	fixture.add_child(source)
	fixture.add_child(holder)
	fixture.add_child(world)

	var thrown_potion := _new_damage_potion()
	var thrown := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(thrown)
	_expect(thrown.initialize(thrown_potion, source), "entity initializes once")
	_expect(thrown.get_potion() == thrown_potion, "entity retains the exact potion instance")
	_expect(thrown.get_state() == PotionEntity.State.HELD, "initialized entity starts held")
	_expect(not thrown.initialize(thrown_potion, source), "entity cannot initialize twice")
	_expect(thrown.attach_to(holder), "held entity attaches to a holder")
	_expect(thrown.get_parent() == holder and thrown.position == Vector2.ZERO, "attached entity uses holder local origin")
	var thrown_id := thrown.get_instance_id()
	_expect(
		thrown.throw_into(world, Vector2(20.0, 30.0), Vector2.RIGHT),
		"held entity enters flight"
	)
	_expect(
		thrown.get_instance_id() == thrown_id and thrown.get_parent() == world,
		"throw reparents the same entity node"
	)
	_expect(thrown.get_state() == PotionEntity.State.FLYING, "thrown entity reports flying state")
	_expect(
		not thrown.place_into(world, Vector2.ZERO)
		and not thrown.attach_to(holder)
		and thrown.get_state() == PotionEntity.State.FLYING,
		"invalid flying transitions fail without changing state"
	)

	var placed_potion := _new_damage_potion()
	var placed := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(placed)
	_expect(placed.initialize(placed_potion, source), "fresh entity initializes for placement")
	_expect(placed.attach_to(holder), "fresh held entity attaches for placement")
	var placed_id := placed.get_instance_id()
	_expect(
		placed.place_into(world, Vector2(40.0, 50.0)),
		"held entity enters placement"
	)
	_expect(
		placed.get_instance_id() == placed_id and placed.get_parent() == world,
		"placement reparents the same entity node"
	)
	_expect(placed.get_state() == PotionEntity.State.PLACED, "placed entity reports placed state")
	_expect(
		not placed.throw_into(world, Vector2.ZERO, Vector2.RIGHT)
		and not placed.drink(source)
		and placed.get_state() == PotionEntity.State.PLACED,
		"invalid placed transitions fail without changing state"
	)

	fixture.queue_free()
	await get_tree().process_frame


func _test_source_requires_exit_before_reentry() -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var world := Node2D.new()
	fixture.add_child(world)
	var source := _new_actor(true)
	world.add_child(source)
	var health := source.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(entity)
	entity.set_physics_process(false)
	var resolved_contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(_context: PotionImpactContext, _applied_count: int) -> void:
		resolved_contexts.append(_context)
	)

	_expect(entity.initialize(potion, source), "source-overlap entity initializes")
	_expect(entity.place_into(world, Vector2.ZERO), "entity places over its source")
	await get_tree().physics_frame
	await get_tree().physics_frame
	entity.call(&"_physics_process", 0.36)
	_expect(
		health.current_health == 100 and entity.get_state() == PotionEntity.State.PLACED,
		"initially overlapping source remains ineligible after arming"
	)
	source.position = Vector2(100.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(resolved_contexts.is_empty(), "source exit does not resolve the potion")
	source.position = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(health.current_health == 70, "source becomes eligible after exit and re-entry")
	_expect(resolved_contexts.size() == 1, "source re-entry resolves once")

	fixture.queue_free()
	await get_tree().process_frame


func _test_unsupported_placement_consumes_without_applying() -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var world := Node2D.new()
	fixture.add_child(world)
	var source := Node2D.new()
	fixture.add_child(source)
	var unsupported := _new_actor(false)
	world.add_child(unsupported)
	var potion := _new_damage_potion()
	var entity := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(entity)
	entity.set_physics_process(false)
	var applied_counts: Array[int] = []
	entity.resolved.connect(func(_context: PotionImpactContext, applied_count: int) -> void:
		applied_counts.append(applied_count)
	)

	_expect(entity.initialize(potion, source), "unsupported-overlap entity initializes")
	_expect(entity.place_into(world, Vector2.ZERO), "entity places over unsupported hitbox")
	await get_tree().physics_frame
	await get_tree().physics_frame
	entity.call(&"_physics_process", 0.36)
	_expect(applied_counts == [0], "unsupported actor hitbox reports zero applied effects")
	_expect(potion.is_consumed(), "unsupported actor hitbox consumes the potion")
	_expect(entity.get_state() == PotionEntity.State.CONSUMED, "unsupported hit consumes the entity")

	fixture.queue_free()
	await get_tree().process_frame


func _test_drink_resolves_once() -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var actor := _new_actor(true)
	fixture.add_child(actor)
	var health := actor.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(entity)
	var contexts: Array[PotionImpactContext] = []
	var applied_counts: Array[int] = []
	entity.resolved.connect(func(context: PotionImpactContext, applied_count: int) -> void:
		contexts.append(context)
		applied_counts.append(applied_count)
	)

	_expect(entity.initialize(potion, actor), "drink entity initializes")
	_expect(entity.drink(actor), "held entity drinks against an actor")
	_expect(health.current_health == 70, "drink changes actor health exactly once")
	_expect(entity.get_state() == PotionEntity.State.CONSUMED, "drink consumes the entity")
	_expect(contexts.size() == 1 and applied_counts == [1], "drink emits one applied resolution")
	_expect(
		contexts[0].delivery_method == PotionDelivery.DRINK,
		"drink resolution records drink delivery"
	)
	_expect(not entity.drink(actor) and health.current_health == 70, "repeated drink is rejected")
	_expect(contexts.size() == 1, "repeated drink emits no additional resolution")

	fixture.queue_free()
	await get_tree().process_frame


func _test_placement_arming_and_stationary_overlap() -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var world := Node2D.new()
	fixture.add_child(world)
	var source := Node2D.new()
	fixture.add_child(source)
	var target := _new_actor(true)
	world.add_child(target)
	var health := target.get_node(^"HealthComponent") as HealthComponent
	var potion := _new_damage_potion()
	var entity := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(entity)
	entity.set_physics_process(false)
	var contexts: Array[PotionImpactContext] = []
	entity.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void:
		contexts.append(context)
	)

	_expect(entity.initialize(potion, source), "stationary-overlap entity initializes")
	_expect(entity.place_into(world, Vector2.ZERO), "entity places beside a stationary actor")
	await get_tree().physics_frame
	await get_tree().physics_frame
	entity.call(&"_physics_process", 0.34)
	_expect(health.current_health == 100, "placement does not resolve before 0.35 seconds")
	_expect(entity.get_state() == PotionEntity.State.PLACED, "unarmed placement remains placed")
	entity.call(&"_physics_process", 0.02)
	_expect(health.current_health == 70, "stationary overlap resolves when arming completes")
	_expect(contexts.size() == 1, "armed stationary overlap resolves once")
	_expect(
		contexts[0].delivery_method == PotionDelivery.PLACE,
		"placement resolution records place delivery"
	)

	fixture.queue_free()
	await get_tree().process_frame


func _test_placed_and_flying_lifetimes_discard() -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var world := Node2D.new()
	fixture.add_child(world)
	var source := Node2D.new()
	fixture.add_child(source)

	var placed_potion := _new_damage_potion()
	var placed := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(placed)
	placed.set_physics_process(false)
	placed.arming_delay = 5.0
	placed.placed_lifetime = 0.1
	var placed_contexts: Array[PotionImpactContext] = []
	placed.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void:
		placed_contexts.append(context)
	)
	_expect(placed.initialize(placed_potion, source), "placed-expiry entity initializes")
	_expect(placed.place_into(world, Vector2.ZERO), "placed-expiry entity enters placed state")
	placed.call(&"_physics_process", 0.11)
	_expect(placed_potion.is_consumed(), "placed lifetime discards its potion")
	_expect(placed.get_state() == PotionEntity.State.CONSUMED, "placed lifetime consumes entity")
	_expect(placed_contexts.is_empty(), "placed lifetime applies no effects")

	var flying_potion := _new_damage_potion()
	var flying := POTION_ENTITY_SCENE.instantiate() as PotionEntity
	fixture.add_child(flying)
	flying.set_physics_process(false)
	flying.flight_speed = 0.0
	flying.flight_lifetime = 0.1
	var flying_contexts: Array[PotionImpactContext] = []
	flying.resolved.connect(func(context: PotionImpactContext, _applied_count: int) -> void:
		flying_contexts.append(context)
	)
	_expect(flying.initialize(flying_potion, source), "flight-expiry entity initializes")
	_expect(
		flying.throw_into(world, Vector2.ZERO, Vector2.RIGHT),
		"flight-expiry entity enters flying state"
	)
	flying.call(&"_physics_process", 0.11)
	_expect(flying_potion.is_consumed(), "flying lifetime discards its potion")
	_expect(flying.get_state() == PotionEntity.State.CONSUMED, "flying lifetime consumes entity")
	_expect(flying_contexts.is_empty(), "flying lifetime applies no effects")

	fixture.queue_free()
	await get_tree().process_frame


func _new_damage_potion() -> PotionInstance:
	return PotionInstance.create(
		DAMAGE_POTION,
		[PotionReagent.GREEN, PotionReagent.GREEN, PotionReagent.BLUE]
	)


func _new_actor(with_health: bool) -> Node2D:
	var actor := Node2D.new()
	if with_health:
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		health.max_health = 100
		health.current_health = 100
		actor.add_child(health)
	var hitbox := ImpactHitbox.new()
	hitbox.name = "ImpactHitbox"
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.monitorable = true
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	collision_shape.shape = circle
	hitbox.add_child(collision_shape)
	actor.add_child(hitbox)
	return actor


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
