extends Node

# Responsibility: Verify the active combat player wraps the canonical locomotion model.

const PLAYER_ACTOR_SCENE_PATH := "res://combat/actors/PlayerActor.tscn"
const PLAYER_MODEL_SCENE_PATH := "res://characters/player/PlayerModel.tscn"

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("PlayerActorTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("PlayerActorTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _run_tests() -> void:
	var player_scene := load(PLAYER_ACTOR_SCENE_PATH) as PackedScene
	_expect(player_scene != null, "PlayerActor scene parses")
	if player_scene == null:
		return

	var player := player_scene.instantiate() as PlayerCombatController
	_expect(player != null, "PlayerActor instantiates as PlayerCombatController")
	if player == null:
		return

	var model := player.get_node_or_null(^"PlayerModel")
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	var body_collision := player.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	var health := player.get_node_or_null(^"HealthComponent") as HealthComponent
	var target := player.get_node_or_null(^"PotionTarget") as PotionTarget
	var health_bar := player.get_node_or_null(^"ActorHealthBar") as Control
	_expect(
		model != null and model.scene_file_path == PLAYER_MODEL_SCENE_PATH,
		"PlayerActor instances the canonical model"
	)
	_expect(
		player.get_node_or_null(^"PlayerAnimationController") == null,
		"PlayerActor has no retired action adapter"
	)
	_expect(camera != null and camera.zoom.is_equal_approx(Vector2(4, 4)), "camera framing is retained")
	_expect(
		body_collision != null and body_collision.shape is CapsuleShape2D,
		"compact capsule collision is retained"
	)
	_expect(health != null and health.current_health == 70, "player health is retained")
	_expect(target != null and health_bar != null, "potion target and health bar are retained")

	if model == null:
		player.free()
		return

	add_child(player)
	await get_tree().process_frame
	await _test_movement(player, model)
	_test_throw_origin(player, model)
	_test_throw_origin_fallback()
	_release_movement_actions()
	player.queue_free()
	await get_tree().process_frame


func _test_movement(player: PlayerCombatController, model: Node) -> void:
	_release_movement_actions()
	Input.action_press(&"move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_right")
	_expect(player.velocity.x > 0.0, "right input moves the active player")
	_expect(
		model != null and (model.call(&"get_locomotion_state") as StringName) == &"walk",
		"right input forwards walk motion to the canonical model"
	)
	_expect(
		model != null and (model.call(&"get_facing") as StringName) == &"side_right",
		"right input forwards side-right facing to the canonical model"
	)
	await get_tree().physics_frame
	_expect(
		model != null and (model.call(&"get_locomotion_state") as StringName) == &"idle",
		"released input forwards idle motion to the canonical model"
	)

	Input.action_press(&"move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_left")
	var facing_root := model.get_node_or_null(^"FacingRoot") as Node2D if model != null else null
	_expect(player.velocity.x < 0.0, "left input moves the active player")
	_expect(
		model != null and (model.call(&"get_facing") as StringName) == &"side_left",
		"left input forwards side-left facing to the canonical model"
	)
	_expect(
		facing_root != null and facing_root.scale.x > 0.0,
		"left-facing motion preserves the authored non-mirrored anatomy"
	)
	await get_tree().physics_frame


func _test_throw_origin(player: PlayerCombatController, model: Node) -> void:
	player.global_position = Vector2(320.0, 180.0)
	var hand_right := model.call(&"get_socket", &"hand_right") as Marker2D if model != null else null
	_expect(hand_right != null, "canonical model exposes the right-hand socket")
	_expect(
		hand_right != null and player.get_throw_origin().is_equal_approx(hand_right.global_position),
		"throw origin uses the canonical right-hand socket"
	)


func _test_throw_origin_fallback() -> void:
	var player_without_model := PlayerCombatController.new()
	player_without_model.global_position = Vector2(-75.0, 40.0)
	_expect(
		player_without_model.get_throw_origin().is_equal_approx(player_without_model.global_position),
		"throw origin falls back to the actor position without a model"
	)
	player_without_model.free()


func _release_movement_actions() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
