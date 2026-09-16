extends Node2D

# Responsibility: Verify real input spawning and potion delivery in the active combat scene.

const COMBAT := preload("res://combat/CombatScene.tscn")
const POTION := preload("res://combat/potions/PotionEntity.tscn")
const DAMAGE := preload("res://combat/potions/resources/DamagePotion.tres")
const HEAL := preload("res://combat/potions/resources/HealthPotion.tres")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	await _run_tests()
	for failure in _failures:
		push_error(failure)
	print("EnemyCombatTests: %s (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run_tests() -> void:
	var combat := COMBAT.instantiate()
	add_child(combat)
	var spawner := combat.get_node_or_null("Arena/EnemyTestSpawner")
	_expect(spawner != null, "combat contains an enemy test spawner")
	_expect(combat.get_node_or_null("Arena/Foe") == null, "stationary foe is replaced")
	_expect(combat.get_node_or_null("Arena/Friend") != null, "passive Friend remains available")
	if spawner == null:
		combat.queue_free()
		return
	var player := combat.get_node("Arena/Player") as Node2D
	var enemies := combat.get_node("Arena/Enemies")
	_expect(enemies.get_child_count() == 0, "combat starts without hostiles")
	_expect(InputMap.has_action("spawn_skirmisher") and InputMap.has_action("spawn_pursuer"), "spawn actions are registered")
	await _frames(3)
	_key(KEY_H)
	await _frames(2)
	_expect(enemies.get_child_count() == 1, "H spawns one skirmisher")
	var ranged := enemies.get_child(0) as Node2D
	ranged.set_physics_process(false)
	_expect(ranged.get_node("Brain").get_script().get_global_name() == &"SkirmisherBrain", "H chooses ranged archetype")
	_key(KEY_H, true)
	await _frames(2)
	_expect(enemies.get_child_count() == 1, "held key repeat cannot spawn additional enemies")
	_key(KEY_H)
	await _frames(2)
	_expect(enemies.get_child_count() == 1, "occupied spawn is rejected instead of overlapping actors")
	get_tree().paused = true
	_key(KEY_J)
	await get_tree().create_timer(0.05, true).timeout
	_expect(enemies.get_child_count() == 1, "spawn input is ignored while paused")
	get_tree().paused = false
	_key(KEY_J)
	await _frames(2)
	_expect(enemies.get_child_count() == 2, "J spawns a pursuer")
	var melee := enemies.get_child(1) as Node2D
	melee.set_physics_process(false)
	_expect(melee.get_node("Brain").get_script().get_global_name() == &"PursuerBrain", "J chooses melee archetype")
	_expect(melee.global_position.x < player.global_position.x and ranged.global_position.x > player.global_position.x, "archetypes use their separate marked spawn locations")
	var ranged_health := ranged.get_node("HealthComponent") as HealthComponent
	ranged_health.take_damage(30)
	var healing := _new_potion(player, HEAL, [&"red", &"red", &"blue"])
	healing.throw_into(self, ranged.global_position - Vector2(100, 0), Vector2.RIGHT)
	await _until_gone(healing)
	_expect(ranged_health.current_health == 60, "thrown healing potion heals living hostile")
	for index in range(2):
		var thrown := _new_potion(player, DAMAGE, [&"green", &"green", &"blue"])
		thrown.throw_into(self, ranged.global_position - Vector2(100, 0), Vector2.RIGHT)
		await _until_gone(thrown)
	await _frames(2)
	_expect(not is_instance_valid(ranged), "thrown damage potions remove defeated skirmisher")
	var melee_health := melee.get_node("HealthComponent") as HealthComponent
	for index in range(3):
		var placed := _new_potion(player, DAMAGE, [&"green", &"green", &"blue"])
		placed.place_into(self, melee.global_position)
		if index == 0:
			await _frames(10)
			_expect(melee_health.current_health == 90, "placed damage potion waits for arming")
		await _until_gone(placed)
	await _frames(2)
	_expect(not is_instance_valid(melee), "placed damage potions remove defeated pursuer")
	_key(KEY_J)
	await _frames(2)
	_expect(enemies.get_child_count() == 1, "cleared spawn accepts another enemy")
	var pursuer := enemies.get_child(0) as Node2D
	player.set_physics_process(false)
	pursuer.global_position = player.global_position + Vector2(80, 0)
	await _frames(35)
	var player_health := player.get_node("HealthComponent") as HealthComponent
	_expect(player_health.current_health == 60, "live pursuer windup deals one health-only hit")
	player_health.take_damage(999)
	await _frames(3)
	_expect(pursuer.get_node("Movement").desired_velocity.is_zero_approx(), "enemy stops pursuing a zero-HP player")
	var drink := _new_potion(player, HEAL, [&"red", &"red", &"blue"])
	drink.drink(player)
	await _frames(2)
	_expect(player_health.current_health == 30, "zero-HP player remains healable")
	_expect(pursuer.get_node("Attack").is_busy(), "enemy reacquires healed player")
	combat.queue_free()
	await _frames(2)


func _new_potion(source: Node, recipe: PotionRecipeData, layers: Array[StringName]) -> PotionEntity:
	var entity := POTION.instantiate() as PotionEntity
	add_child(entity)
	_expect(entity.initialize(PotionInstance.create(recipe, layers), source), "test uses a valid real potion entity")
	return entity


func _until_gone(node: Node) -> void:
	for frame in range(100):
		if not is_instance_valid(node):
			return
		await get_tree().physics_frame
	_expect(not is_instance_valid(node), "potion resolves within the test deadline")


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame


func _key(key: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.physical_keycode = key
	Input.parse_input_event(release)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
