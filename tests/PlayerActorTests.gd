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
	var hitbox := player.get_node_or_null(^"ImpactHitbox") as ImpactHitbox
	var hitbox_collision := hitbox.get_node_or_null(^"CollisionShape2D") as CollisionShape2D if hitbox != null else null
	var health_bar := player.get_node_or_null(^"ActorHealthBar") as Control
	_expect(
		model != null and model.scene_file_path == PLAYER_MODEL_SCENE_PATH,
		"PlayerActor instances the canonical model"
	)
	_expect(
		player.get_node_or_null(^"PlayerAnimationController") == null,
		"PlayerActor has no retired action adapter"
	)
	_expect(is_equal_approx(player.speed, 220.0), "player movement speed is retained")
	_expect(player.player_model_path == ^"PlayerModel", "player model binding path is retained")
	_expect(
		camera != null
		and camera.position.is_equal_approx(Vector2(0.0, -55.0))
		and camera.zoom.is_equal_approx(Vector2(2.0, 2.0))
		and camera.position_smoothing_enabled
		and is_equal_approx(camera.position_smoothing_speed, 8.0),
		"camera position, zoom, and smoothing are retained"
	)
	_expect(
		body_collision != null and body_collision.shape is CapsuleShape2D,
		"compact capsule collision is retained"
	)
	var body_capsule := body_collision.shape as CapsuleShape2D if body_collision != null else null
	_expect(
		body_capsule != null
		and is_equal_approx(body_capsule.radius, 31.0)
		and is_equal_approx(body_capsule.height, 120.0)
		and body_collision.position.is_equal_approx(Vector2(0.0, -22.0)),
		"capsule size and offset are retained"
	)
	_expect(health != null and health.current_health == 70, "player health is retained")
	var hitbox_circle := hitbox_collision.shape as CircleShape2D if hitbox_collision != null else null
	_expect(
		hitbox != null
		and hitbox.get_effect_subject() == player
		and hitbox.collision_layer == 2
		and hitbox.collision_mask == 0
		and hitbox_circle != null
		and is_equal_approx(hitbox_circle.radius, 42.0),
		"neutral impact hitbox ownership, layer, mask, and radius are retained"
	)
	_expect(
		health_bar != null
		and is_equal_approx(health_bar.offset_left, -70.0)
		and is_equal_approx(health_bar.offset_top, -166.0)
		and is_equal_approx(health_bar.offset_right, 70.0)
		and is_equal_approx(health_bar.offset_bottom, -118.0)
		and health_bar.get(&"display_name") == "Player"
		and health_bar.get(&"health_component_path") == ^"../HealthComponent",
		"health-bar offsets and bindings are retained"
	)

	if model == null:
		player.free()
		return

	add_child(player)
	await get_tree().process_frame
	await _test_movement(player, model)
	_test_throw_origin(player, model)
	_test_place_position(player)
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
	_expect(player.has_method(&"get_potion_holder"), "player exposes a potion holder")
	var potion_holder := (
		player.call(&"get_potion_holder") as Marker2D
		if player.has_method(&"get_potion_holder")
		else null
	)
	_expect(potion_holder == hand_right, "potion holder is the canonical right-hand socket")
	_expect(
		hand_right != null and player.get_throw_origin().is_equal_approx(hand_right.global_position),
		"throw origin uses the canonical right-hand socket"
	)


func _test_place_position(player: PlayerCombatController) -> void:
	_expect(player.has_method(&"get_place_position"), "player exposes potion placement geometry")
	if not player.has_method(&"get_place_position"):
		return
	var direction := player.get_throw_direction()
	var place_position := player.call(&"get_place_position") as Vector2
	var place_distance := player.get(&"place_distance") as float
	_expect(is_equal_approx(place_distance, 64.0), "player retains the default place distance")
	_expect(direction.is_normalized(), "placement aim direction is normalized")
	_expect(
		place_position.is_equal_approx(player.global_position + direction * place_distance),
		"place position is exactly place_distance along normalized aim"
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
