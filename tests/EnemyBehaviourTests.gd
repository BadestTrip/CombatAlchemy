extends Node

# Responsibility: Exercise real enemy decisions, action timing, and lifecycle isolation.

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	await _run_tests()
	for failure in _failures:
		push_error(failure)
	print("EnemyBehaviourTests: %s (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run_tests() -> void:
	for kind in ["Pursuer", "Skirmisher"]:
		_expect(ResourceLoader.exists("res://combat/enemies/%s.tscn" % kind), "%s scene exists" % kind)
	if not _failures.is_empty():
		return
	var target := _make_target()
	var pursuer := _make_enemy("Pursuer", target)
	var second := _make_enemy("Pursuer", target)
	var ranged := _make_enemy("Skirmisher", target)
	if pursuer == null or second == null or ranged == null:
		return
	var attack: Node = pursuer.get_node("Attack")
	var health := target.get_node("HealthComponent") as HealthComponent
	_decide(pursuer, target, Vector2(950, 0))
	_expect(pursuer.get_node("Brain").get_state() == &"idle", "unnoticed target does not trigger chase")
	_decide(pursuer, target, Vector2(800, 0))
	_expect(pursuer.get_node("Brain").get_state() == &"chase", "notice starts pursuit")
	_expect(pursuer.get_node("Movement").desired_velocity.x > 0.0, "pursuit requests movement toward player")
	_decide(pursuer, target, Vector2(1100, 0))
	_expect(pursuer.get_node("Brain").get_state() == &"chase", "engaged target stays acquired beyond notice range")
	_decide(pursuer, target, Vector2(1201, 0))
	_expect(pursuer.get_node("Brain").get_state() == &"idle", "disengage distance releases target")
	_decide(pursuer, target, Vector2(90, 0))
	_expect(attack.is_busy(), "close target starts melee windup")
	_expect(pursuer.get_node("Movement").desired_velocity.is_zero_approx(), "windup locks enemy movement")
	_expect(not attack.try_start(target), "repeated attack requests cannot restart windup")
	_expect(not second.get_node("Attack").is_busy(), "shared profile does not share attack state")
	attack.advance(0.49)
	_expect(health.current_health == 100, "melee does not deal damage before windup ends")
	attack.advance(0.01)
	_expect(health.current_health == 90, "melee commits once at the authored windup time")
	attack.advance(0.20)
	_expect(health.current_health == 90, "recovery does not repeat damage")
	_expect(attack.is_busy(), "recovery prevents immediate repeated attacks")
	attack.advance(0.65)
	_expect(not attack.is_busy(), "recovery finishes")
	_expect(attack.try_start(target), "next melee attack accepted after recovery")
	target.position = Vector2(0, 90)
	attack.advance(0.5)
	_expect(health.current_health == 90, "dodging outside locked sector avoids melee damage")
	attack.advance(0.85)
	target.position = Vector2(90, 0)
	attack.try_start(target)
	target.position = Vector2(160, 0)
	attack.advance(0.5)
	_expect(health.current_health == 90, "leaving melee reach avoids damage")
	attack.cancel()
	_decide(pursuer, target, Vector2(90, 0))
	(pursuer.get_node("HealthComponent") as HealthComponent).take_damage(1)
	attack.advance(0.5)
	_expect(health.current_health == 80, "ordinary incoming damage does not interrupt attack")
	attack.cancel()
	_decide(pursuer, target, Vector2(90, 0))
	health.take_damage(1000)
	pursuer._physics_process(0.01)
	_expect(not attack.is_busy(), "zero-HP target cancels uncommitted attack")
	_expect(pursuer.get_node("Movement").desired_velocity.is_zero_approx(), "zero-HP player is not pursued")
	health.heal(30)
	_decide(pursuer, target, Vector2(300, 0))
	_expect(pursuer.get_node("Brain").get_state() == &"chase", "healing player resumes enemy engagement")
	_test_skirmisher(ranged, target)
	await _test_pause(pursuer, target)
	attack.cancel()
	_decide(pursuer, target, Vector2(90, 0))
	(pursuer.get_node("HealthComponent") as HealthComponent).take_damage(1000)
	_expect(not attack.is_busy(), "enemy depletion immediately cancels windup")
	_expect(pursuer.is_queued_for_deletion(), "defeated enemy queues removal")
	await get_tree().process_frame
	_expect(not is_instance_valid(pursuer), "defeated enemy is removed")
	_decide(second, target, Vector2(90, 0))
	target.queue_free()
	await get_tree().process_frame
	second._physics_process(0.02)
	_expect(not second.get_node("Attack").is_busy(), "freed target safely cancels attack")
	second.queue_free()
	ranged.queue_free()
	await get_tree().process_frame


func _test_skirmisher(enemy: Node2D, target: Node2D) -> void:
	var attack: Node = enemy.get_node("Attack")
	_decide(enemy, target, Vector2(700, 0))
	_expect(enemy.get_node("Brain").get_state() == &"approach", "ranged enemy approaches from far away")
	_decide(enemy, target, Vector2(450, 0))
	_expect(enemy.get_node("Brain").get_state() == &"approach", "approach continues through hysteresis band")
	_decide(enemy, target, Vector2(420, 0))
	_expect(attack.is_busy(), "ranged enemy holds and attacks at approach stop distance")
	attack.cancel()
	_decide(enemy, target, Vector2(250, 0))
	_expect(enemy.get_node("Brain").get_state() == &"retreat", "close player makes skirmisher retreat")
	_expect(enemy.get_node("Movement").desired_velocity.x < 0.0, "retreat moves away from player")
	_decide(enemy, target, Vector2(310, 0))
	_expect(enemy.get_node("Brain").get_state() == &"retreat", "retreat persists through hysteresis band")
	_decide(enemy, target, Vector2(340, 0))
	_expect(attack.is_busy(), "skirmisher shoots after regaining space")
	var shots_before := get_tree().get_nodes_in_group("enemy_projectile").size()
	attack.advance(0.64)
	_expect(get_tree().get_nodes_in_group("enemy_projectile").size() == shots_before, "ranged windup does not fire early")
	target.position = enemy.position + Vector2(0, 340)
	attack.advance(0.01)
	var shots := get_tree().get_nodes_in_group("enemy_projectile")
	_expect(shots.size() == shots_before + 1, "windup releases exactly one projectile")
	attack.advance(0.4)
	_expect(get_tree().get_nodes_in_group("enemy_projectile").size() == shots.size(), "recovery cannot duplicate projectile")
	for shot in shots:
		shot.queue_free()
	attack.cancel()


func _test_pause(enemy: Node2D, target: Node2D) -> void:
	var attack: Node = enemy.get_node("Attack")
	attack.cancel()
	_decide(enemy, target, Vector2(90, 0))
	var health := target.get_node("HealthComponent") as HealthComponent
	var before := health.current_health
	enemy.set_physics_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.7, true).timeout
	_expect(health.current_health == before and attack.is_busy(), "pause freezes attack timing")
	get_tree().paused = false
	enemy.set_physics_process(false)
	attack.advance(0.5)
	_expect(health.current_health == before - 10, "attack continues after pause")
	attack.cancel()


func _make_target() -> Node2D:
	var target := Node2D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	target.add_child(health)
	add_child(target)
	return target


func _make_enemy(kind: String, target: Node2D) -> Node2D:
	var scene := load("res://combat/enemies/%s.tscn" % kind) as PackedScene
	_expect(scene != null, "%s scene parses" % kind)
	if scene == null:
		return null
	var enemy := scene.instantiate() as Node2D
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_target(target)
	return enemy


func _decide(enemy: Node2D, target: Node2D, offset: Vector2) -> void:
	target.position = enemy.position + offset
	enemy._physics_process(0.0)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
