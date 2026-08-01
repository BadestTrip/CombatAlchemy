extends Node2D

# Responsibility: Verify a real physics overlap consumes a potion projectile cleanly.

const DAMAGE_POTION = preload("res://combat/potions/resources/DamagePotion.tres")
const PROJECTILE_SCENE = preload("res://combat/potions/PotionProjectile.tscn")
const TARGET_SCENE = preload("res://combat/actors/TargetActor.tscn")

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _test_projectile_collision()
	if _failures.is_empty():
		print("PotionProjectileCollisionTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("PotionProjectileCollisionTests: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_projectile_collision() -> void:
	var target := TARGET_SCENE.instantiate() as Node2D
	var projectile := PROJECTILE_SCENE.instantiate() as PotionProjectile
	_expect(target != null, "target scene instantiates")
	_expect(projectile != null, "projectile scene instantiates")
	if target == null or projectile == null:
		return

	add_child(target)
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	_expect(health != null, "target exposes its health component")
	if health == null:
		target.queue_free()
		projectile.queue_free()
		return

	health.current_health = 100
	add_child(projectile)
	_expect(
		projectile.launch(DAMAGE_POTION, target.global_position, Vector2.RIGHT),
		"valid damage projectile launches"
	)

	for _physics_step in range(4):
		await get_tree().physics_frame
		await get_tree().process_frame
		if health.current_health == 70 and not is_instance_valid(projectile):
			break

	_expect(health.current_health == 70, "overlap applies the damage recipe exactly once")
	_expect(not is_instance_valid(projectile), "projectile is consumed after its first accepted hit")
	target.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
