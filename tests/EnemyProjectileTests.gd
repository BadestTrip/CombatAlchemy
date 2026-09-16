extends Node2D

# Responsibility: Exercise enemy darts in a live Godot physics world.

const PROJECTILE_PATH := "res://combat/enemies/EnemyProjectile.tscn"
const PLAYER_SCENE := preload("res://combat/actors/PlayerActor.tscn")

var _projectile_scene: PackedScene
var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_tests()
	get_tree().paused = false
	for failure in _failures:
		print("FAIL: " + failure)
	if _failures.is_empty():
		print("EnemyProjectileTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
	else:
		print("EnemyProjectileTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
		get_tree().quit(1)


func _run_tests() -> void:
	_expect(ResourceLoader.exists(PROJECTILE_PATH), "EnemyProjectile scene exists")
	if not ResourceLoader.exists(PROJECTILE_PATH):
		return
	_projectile_scene = load(PROJECTILE_PATH) as PackedScene
	_expect(_projectile_scene != null, "EnemyProjectile scene loads")
	if _projectile_scene == null:
		return
	await _test_scene_and_unlaunched_state()
	for collision_kind in [&"body", &"hitbox", &"both", &"external_hitbox"]:
		await _test_fast_crossing_player(collision_kind)
	await _test_ignored_actors_do_not_hide_player()
	await _test_ignored_actors_do_not_hide_wall()
	await _test_player_before_wall()
	await _test_source_freed_in_flight()
	await _test_invalid_target(false)
	await _test_invalid_target(true)
	await _test_zero_health_target()
	await _test_missing_health_target()
	await _test_locked_normalized_direction()
	await _test_default_lifetime()
	await _test_expiry_limits_last_step()
	await _test_pause_freezes_flight_and_expiry()


func _test_scene_and_unlaunched_state() -> void:
	var world := _new_world()
	var projectile := _projectile_scene.instantiate() as Node2D
	_expect(projectile != null, "projectile root is Node2D")
	if projectile == null:
		await _cleanup(world)
		return
	var script := projectile.get_script() as Script
	_expect(script != null and script.get_global_name() == &"EnemyProjectile", "projectile exports EnemyProjectile class")
	_expect(projectile.has_method(&"launch"), "projectile exposes launch")
	_expect(projectile.process_mode == Node.PROCESS_MODE_INHERIT, "projectile inherits pause behavior")
	var polygon := projectile.get_node_or_null(^"DartVisual") as Polygon2D
	var line := projectile.get_node_or_null(^"Outline") as Line2D
	_expect(polygon != null and polygon.polygon.size() >= 3 and polygon.visible, "scene authors a visible dart polygon")
	_expect(line != null and line.points.size() >= 2 and line.width > 0.0 and line.visible, "scene authors a visible dart line")
	var sweep := projectile.get_node_or_null(^"SweepCast") as ShapeCast2D
	_expect(sweep != null and sweep.shape is CircleShape2D, "scene authors a circular sweep")
	if sweep != null:
		_expect(sweep.collision_mask == 3 and sweep.collide_with_areas and sweep.collide_with_bodies, "sweep includes actors, hitboxes, and world")
		var circle := sweep.shape as CircleShape2D
		_expect(circle != null and is_equal_approx(circle.radius, 8.0), "dart sweep has an eight-pixel radius")
	world.add_child(projectile)
	_expect(projectile.is_in_group(&"enemy_projectile"), "ready projectile joins lifecycle group")
	await _wait_frames(3)
	_expect(is_instance_valid(projectile) and projectile.position == Vector2.ZERO, "unlaunched scene neither flies nor expires")
	await _cleanup(world)


func _test_fast_crossing_player(collision_kind: StringName) -> void:
	var world := _new_world()
	var player := _new_player(world, Vector2(120.0, 0.0))
	var body_shape := player.get_node(^"CollisionShape2D") as CollisionShape2D
	body_shape.position = Vector2.ZERO
	body_shape.shape = _rectangle(Vector2(4.0, 40.0))
	var hitbox := player.get_node(^"ImpactHitbox") as ImpactHitbox
	(hitbox.get_node(^"CollisionShape2D") as CollisionShape2D).shape = _rectangle(Vector2(4.0, 40.0))
	if collision_kind == &"hitbox" or collision_kind == &"external_hitbox":
		player.collision_layer = 0
	if collision_kind == &"body" or collision_kind == &"external_hitbox":
		hitbox.collision_layer = 0
	if collision_kind == &"external_hitbox":
		var external := _new_hitbox()
		external.position = player.position
		world.add_child(external)
		external.effect_subject_path = external.get_path_to(player)
	var health := player.get_node(^"HealthComponent") as HealthComponent
	var damage_events: Array[int] = []
	health.damaged.connect(func(amount: int) -> void: damage_events.append(amount))
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, null, 17, 28800.0)
	await _wait_frames(1)
	_expect(health.current_health == 83, "%s: swept dart hits a four-pixel player crossed in one tick" % collision_kind)
	_expect(not is_instance_valid(projectile), "%s: player impact consumes dart immediately" % collision_kind)
	await _wait_frames(5)
	_expect(damage_events == [17], "%s: body/hitbox contacts apply damage exactly once" % collision_kind)
	await _cleanup(world)


func _test_ignored_actors_do_not_hide_player() -> void:
	var world := _new_world()
	var source := _new_actor(world, Vector2.ZERO)
	var player := _new_player(world, Vector2(360.0, 0.0))
	var other_player := _new_player(world, Vector2(220.0, 0.0))
	var ignored: Array[CharacterBody2D] = []
	for index in range(40):
		ignored.append(_new_actor(world, Vector2(20.0 + index * 4.0, 0.0)))
	var external := _new_hitbox()
	external.position = Vector2(280.0, 0.0)
	world.add_child(external)
	external.effect_subject_path = external.get_path_to(ignored[0])
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, source, 23, 36000.0)
	_set_single_sweep_result(projectile)
	# Added after launch: a one-time scene scan cannot filter these actors.
	var late_actor := _new_actor(world, Vector2(300.0, 0.0))
	await _wait_frames(1)
	_expect((player.get_node(^"HealthComponent") as HealthComponent).current_health == 77, "ignored colliders cannot hide player farther along the same sweep")
	_expect(not is_instance_valid(projectile), "dense ignored actors do not delay player impact to another tick")
	_expect((source.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "shooter and nested colliders stay immune")
	_expect((other_player.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "a non-target Player is ignored")
	for actor in ignored:
		_expect((actor.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "intervening actor takes no damage")
	_expect((late_actor.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "actor added after launch is ignored")
	await _cleanup(world)


func _test_ignored_actors_do_not_hide_wall() -> void:
	var world := _new_world()
	var source := Node2D.new()
	world.add_child(source)
	var source_body := _new_wall(source, Vector2.ZERO)
	var source_hitbox := _new_hitbox()
	source.add_child(source_hitbox)
	for index in range(24):
		_new_actor(world, Vector2(20.0 + index * 4.0, 0.0))
	var wall := _new_wall(world, Vector2(180.0, 0.0))
	var player := _new_player(world, Vector2(360.0, 0.0))
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, source, 31, 36000.0)
	_set_single_sweep_result(projectile)
	await _wait_frames(1)
	_expect(not is_instance_valid(projectile), "ignored actors cannot hide a four-pixel world wall")
	_expect((player.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "intervening world wall blocks damage to player")
	_expect((wall.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "world impact does not affect even a wall with health")
	_expect((source_body.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "non-character shooter descendants are excluded")
	await _cleanup(world)


func _test_player_before_wall() -> void:
	var world := _new_world()
	var player := _new_player(world, Vector2(120.0, 0.0))
	_new_wall(world, Vector2(360.0, 0.0))
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, null, 19, 36000.0)
	await _wait_frames(1)
	_expect((player.get_node(^"HealthComponent") as HealthComponent).current_health == 81, "player before a wall receives the first impact")
	_expect(not is_instance_valid(projectile), "nearest impact consumes the dart")
	await _cleanup(world)


func _test_source_freed_in_flight() -> void:
	var world := _new_world()
	var source := _new_actor(world, Vector2.ZERO)
	var player := _new_player(world, Vector2(180.0, 0.0))
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, source, 29, 1200.0)
	await _wait_frames(1)
	_expect(is_instance_valid(projectile) and projectile.global_position.x > 0.0, "projectile leaves shooter before source deletion")
	source.free()
	await _wait_frames(10)
	_expect((player.get_node(^"HealthComponent") as HealthComponent).current_health == 71, "source deletion does not interrupt flight or damage")
	_expect(not is_instance_valid(projectile), "source-free projectile still cleans up after impact")
	await _cleanup(world)


func _test_invalid_target(use_null: bool) -> void:
	var world := _new_world()
	var player: Node2D = null if use_null else _new_player(world, Vector2(600.0, 0.0))
	var other := _new_actor(world, Vector2(60.0, 0.0))
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, null, 41, 1200.0, 0.1)
	if is_instance_valid(player):
		player.free()
	await _wait_frames(1)
	_expect(is_instance_valid(projectile) and projectile.global_position.x > 0.0, "invalid target does not interrupt fixed-direction flight (null=%s)" % use_null)
	await _wait_frames(10)
	_expect(not is_instance_valid(projectile), "invalid target projectile expires (null=%s)" % use_null)
	_expect((other.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "invalid target cannot redirect damage to another actor (null=%s)" % use_null)
	await _cleanup(world)


func _test_zero_health_target() -> void:
	var world := _new_world()
	var player := _new_player(world, Vector2(120.0, 0.0))
	var health := player.get_node(^"HealthComponent") as HealthComponent
	var damage_events: Array[int] = []
	health.damaged.connect(func(amount: int) -> void: damage_events.append(amount))
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, null, 43, 1200.0, 0.2)
	await _wait_frames(1)
	health.current_health = 0
	await _wait_frames(16)
	_expect(health.current_health == 0 and damage_events.is_empty(), "target depleted during flight receives no damage")
	_expect(not is_instance_valid(projectile), "zero-health target cannot leave an immortal projectile")
	await _cleanup(world)


func _test_missing_health_target() -> void:
	var world := _new_world()
	var player := _new_player(world, Vector2(120.0, 0.0))
	player.get_node(^"HealthComponent").free()
	var nested_health := HealthComponent.new()
	player.get_node(^"ImpactHitbox").add_child(nested_health)
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, null, 43, 28800.0, 0.1)
	await _wait_frames(10)
	_expect(nested_health.current_health == 100, "projectile does not damage a nested health component")
	_expect(not is_instance_valid(projectile), "missing direct health component is safe and cleans up")
	await _cleanup(world)


func _test_locked_normalized_direction() -> void:
	var world := _new_world()
	world.position = Vector2(300.0, 200.0)
	world.rotation = PI / 2.0
	var player := _new_player(world, Vector2(0.0, -800.0))
	var projectile := _projectile_scene.instantiate() as Node2D
	world.add_child(projectile)
	projectile.call(&"launch", Vector2(30.0, 40.0), Vector2(3.0, 4.0), player, null, 11)
	_expect(projectile.global_position.is_equal_approx(Vector2(30.0, 40.0)), "launch uses world-space origin after add_child")
	await _wait_frames(3)
	_expect(projectile.global_position.is_equal_approx(Vector2(40.8, 54.4)), "normalized direction uses default 360 pixels per physics second")
	player.global_position = Vector2(-600.0, -600.0)
	await _wait_frames(3)
	_expect(projectile.global_position.is_equal_approx(Vector2(51.6, 68.8)), "moving target never changes captured direction")
	_expect(Vector2.RIGHT.rotated(projectile.global_rotation).is_equal_approx(Vector2(0.6, 0.8)), "authored dart faces the locked world-space direction")
	await _cleanup(world)


func _test_default_lifetime() -> void:
	var world := _new_world()
	var projectile := _projectile_scene.instantiate() as Node2D
	world.add_child(projectile)
	projectile.call(&"launch", Vector2.ZERO, Vector2.RIGHT, null, null, 1)
	await _wait_frames(209)
	_expect(is_instance_valid(projectile), "default lifetime lasts until almost 3.5 physics seconds")
	await _wait_frames(3)
	_expect(not is_instance_valid(projectile), "default 3.5-second lifetime expires")
	await _cleanup(world)


func _test_expiry_limits_last_step() -> void:
	var world := _new_world()
	var player := _new_player(world, Vector2(120.0, 0.0))
	await _wait_frames(2)
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, player, null, 47, 28800.0, 0.001)
	await _wait_frames(2)
	_expect(not is_instance_valid(projectile), "sub-tick lifetime cleans up")
	_expect((player.get_node(^"HealthComponent") as HealthComponent).current_health == 100, "dart cannot damage a target beyond its remaining lifetime")
	var stationary := _launch(world, Vector2.ZERO, Vector2.RIGHT, null, null, 1, 0.0, 0.05)
	await _wait_frames(5)
	_expect(not is_instance_valid(stationary), "zero-speed dart still expires")
	await _cleanup(world)


func _test_pause_freezes_flight_and_expiry() -> void:
	var world := _new_world()
	var projectile := _launch(world, Vector2.ZERO, Vector2.RIGHT, null, null, 1, 60.0, 0.15)
	await _wait_frames(2)
	var before_pause := projectile.global_position
	_expect(before_pause.is_equal_approx(Vector2(2.0, 0.0)), "live flight advances using physics delta")
	get_tree().paused = true
	await _wait_frames(20)
	_expect(is_instance_valid(projectile), "pause freezes lifetime beyond its normal expiry")
	if is_instance_valid(projectile):
		_expect(projectile.global_position.is_equal_approx(before_pause), "pause freezes projectile position")
	get_tree().paused = false
	await _wait_frames(2)
	_expect(is_instance_valid(projectile) and projectile.global_position.is_equal_approx(Vector2(4.0, 0.0)), "unpause resumes movement without catch-up")
	await _wait_frames(10)
	_expect(not is_instance_valid(projectile), "unpause resumes lifetime countdown")
	await _cleanup(world)


func _new_world() -> Node2D:
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	return world


func _new_player(world: Node2D, at: Vector2) -> PlayerCombatController:
	var player := PLAYER_SCENE.instantiate() as PlayerCombatController
	player.position = at
	(player.get_node(^"HealthComponent") as HealthComponent).reset_health(100)
	world.add_child(player)
	player.set_physics_process(false)
	return player


func _new_actor(world: Node2D, at: Vector2) -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	actor.position = at
	actor.collision_layer = 1
	actor.collision_mask = 0
	_add_shape(actor, Vector2(4.0, 40.0))
	_add_health(actor)
	var children := Node2D.new()
	actor.add_child(children)
	var hitbox := _new_hitbox()
	hitbox.effect_subject_path = ^"../.."
	children.add_child(hitbox)
	_new_wall(children, Vector2(2.0, 0.0))
	world.add_child(actor)
	return actor


func _new_wall(parent_node: Node2D, at: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = at
	wall.collision_layer = 1
	wall.collision_mask = 0
	_add_shape(wall, Vector2(4.0, 100.0))
	_add_health(wall)
	parent_node.add_child(wall)
	return wall


func _new_hitbox() -> ImpactHitbox:
	var hitbox := ImpactHitbox.new()
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	_add_shape(hitbox, Vector2(4.0, 40.0))
	return hitbox


func _add_health(actor: Node) -> void:
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	actor.add_child(health)


func _add_shape(body: CollisionObject2D, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	collision.shape = _rectangle(size)
	body.add_child(collision)


func _rectangle(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape


func _launch(
	world: Node2D,
	origin: Vector2,
	direction: Vector2,
	target: Node2D,
	source: Node,
	damage: int,
	speed: float = 360.0,
	lifetime: float = 3.5
) -> Node2D:
	var projectile := _projectile_scene.instantiate() as Node2D
	world.add_child(projectile)
	projectile.call(&"launch", origin, direction, target, source, damage, speed, lifetime)
	return projectile


func _set_single_sweep_result(projectile: Node2D) -> void:
	var sweep := projectile.get_node_or_null(^"SweepCast") as ShapeCast2D
	if sweep != null:
		sweep.max_results = 1


func _wait_frames(count: int) -> void:
	for _step in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _cleanup(world: Node2D) -> void:
	world.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
