extends Node

# Responsibility: Verify PlayerActor's gameplay-facing animation integration.

const PLAYER_SCENE_PATH := "res://combat/actors/PlayerActor.tscn"
const FRAME_RATE := 60.0

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("PlayerAnimationControllerTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("PlayerAnimationControllerTests: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _run_tests() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	_expect(player_scene != null, "PlayerActor scene exists and parses")
	if player_scene == null:
		return

	var player := player_scene.instantiate() as CharacterBody2D
	_expect(player != null, "PlayerActor instantiates as CharacterBody2D")
	if player == null:
		return
	add_child(player)
	await get_tree().process_frame

	var rig := player.get_node_or_null(^"PlayerVisual") as Node2D
	var adapter := player.get_node_or_null(^"PlayerAnimationController")
	var health := player.get_node_or_null(^"HealthComponent") as HealthComponent
	var health_bar := player.get_node_or_null(^"ActorHealthBar") as Control
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	_expect(rig != null and rig.has_method(&"play_state"), "PlayerVisual is the reusable cutout rig")
	_expect(adapter != null, "PlayerActor contains PlayerAnimationController")
	_expect(health != null, "PlayerActor retains HealthComponent")
	_expect(health_bar != null, "PlayerActor retains its health bar")
	_expect(camera != null, "PlayerActor retains its camera")
	if rig == null or adapter == null or health == null or health_bar == null or camera == null:
		player.queue_free()
		return

	_expect(rig.position.is_equal_approx(Vector2(0.0, -64.0)), "player rig uses the authored vertical alignment")
	_expect(rig.scale.is_equal_approx(Vector2(0.5, 0.5)), "player rig uses the authored gameplay scale")
	_expect(is_equal_approx(health_bar.offset_top, -166.0), "player health bar clears the rig silhouette")
	_expect(is_equal_approx(health_bar.offset_bottom, -118.0), "player health bar keeps its existing height")
	_expect(camera.zoom.is_equal_approx(Vector2.ONE), "player camera preserves the existing gameplay framing")

	var required_methods: Array[StringName] = [
		&"request_potion_action",
		&"is_busy",
		&"get_action_origin",
	]
	var adapter_contract_valid := true
	for method_name in required_methods:
		var has_method := adapter.has_method(method_name)
		_expect(has_method, "animation adapter exposes %s" % method_name)
		adapter_contract_valid = adapter_contract_valid and has_method
	for signal_name in [&"action_event", &"action_interrupted", &"action_finished"]:
		var has_signal := adapter.has_signal(signal_name)
		_expect(has_signal, "animation adapter exposes %s" % signal_name)
		adapter_contract_valid = adapter_contract_valid and has_signal
	if not adapter_contract_valid:
		player.queue_free()
		return

	var right_socket := rig.call(&"get_socket", &"hand_right") as Marker2D
	_expect(right_socket != null, "player rig exposes the right-hand socket")
	var held_flask := right_socket.get_node_or_null(^"HeldPotionFlask") if right_socket != null else null
	_expect(held_flask != null, "right-hand socket owns the scene-backed held flask")
	if held_flask == null:
		player.queue_free()
		return
	_expect(held_flask.has_method(&"show_potion"), "held flask exposes show_potion")
	_expect(held_flask.has_method(&"hide_potion"), "held flask exposes hide_potion")
	_expect(not held_flask.visible, "held flask starts hidden")

	var action_events: Array[Dictionary] = []
	var interruptions: Array[StringName] = []
	var finished_actions: Array[StringName] = []
	adapter.connect(&"action_event", func(event_name: StringName, direction: Vector2) -> void:
		action_events.append({"event": event_name, "direction": direction})
	)
	adapter.connect(&"action_interrupted", func(action: StringName) -> void:
		interruptions.append(action)
	)
	adapter.connect(&"action_finished", func(action: StringName) -> void:
		finished_actions.append(action)
	)

	player.emit_signal(&"movement_changed", Vector2.LEFT * 120.0)
	_expect(await _wait_for_state(rig, &"walk", 0.4), "leftward velocity enters walk")
	var facing_root := rig.get_node(^"FacingRoot") as Node2D
	_expect(facing_root.scale.x < 0.0, "leftward movement mirrors the player")
	await _advance(0.2)
	var animation_tree := rig.get_node(^"AnimationTree") as AnimationTree
	var playback := animation_tree.get(&"parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
	var walk_position_before_repeat := playback.get_current_play_position()
	player.emit_signal(&"movement_changed", Vector2.LEFT * 120.0)
	player.emit_signal(&"movement_changed", Vector2.LEFT * 120.0)
	await get_tree().process_frame
	_expect(
		playback.get_current_play_position() > walk_position_before_repeat,
		"repeated walk velocity does not restart the clip"
	)
	player.emit_signal(&"movement_changed", Vector2.UP * 120.0)
	await _advance(0.05)
	_expect(facing_root.scale.x < 0.0, "vertical movement preserves the last facing")
	player.emit_signal(&"movement_changed", Vector2.RIGHT * 120.0)
	await _advance(0.05)
	_expect(facing_root.scale.x > 0.0, "rightward movement restores unmirrored facing")
	player.emit_signal(&"movement_changed", Vector2.ZERO)
	_expect(await _wait_for_state(rig, &"idle", 0.4), "zero velocity returns to idle")

	var health_color := Color(0.8, 0.2, 0.8, 1.0)
	_expect(
		adapter.call(&"request_potion_action", &"drink", Vector2.ZERO, health_color) as bool,
		"drink action is accepted while idle"
	)
	_expect(player.call(&"is_movement_locked") as bool, "drink locks movement")
	_expect(adapter.call(&"is_busy") as bool, "drink marks the adapter busy")
	_expect(held_flask.visible, "drink shows the held flask")
	var liquid := held_flask.get_node_or_null(^"Liquid") as Polygon2D
	_expect(liquid != null and liquid.color.is_equal_approx(health_color), "held flask uses the prepared potion color")
	_expect(
		not (adapter.call(&"request_potion_action", &"throw", Vector2.RIGHT, Color.WHITE) as bool),
		"a second action is rejected while drink is active"
	)
	await _advance(0.45)
	_expect(action_events.is_empty(), "drink does not commit before its authored event")
	await _advance(0.25)
	_expect(action_events.size() == 1 and action_events[0]["event"] == &"drink_commit", "drink forwards one commit event")
	_expect(not held_flask.visible, "drink hides the held flask at commit")
	_expect(await _wait_until_not_busy(adapter, 0.8), "drink automatically finishes")
	_expect(not (player.call(&"is_movement_locked") as bool), "drink recovery unlocks movement")
	_expect(finished_actions == [&"drink"], "drink reports one completed action")

	action_events.clear()
	finished_actions.clear()
	var throw_direction := Vector2(-4.0, 2.0).normalized()
	var damage_color := Color(0.0, 0.7, 0.65, 1.0)
	_expect(
		adapter.call(&"request_potion_action", &"throw", throw_direction, damage_color) as bool,
		"throw action is accepted while idle"
	)
	_expect(facing_root.scale.x < 0.0, "throw faces the captured aim direction")
	_expect((adapter.call(&"get_action_origin") as Vector2).is_equal_approx(right_socket.global_position), "action origin follows the right hand")
	await _advance(0.35)
	_expect(action_events.is_empty(), "throw does not release before its authored event")
	await _advance(0.25)
	_expect(action_events.size() == 1 and action_events[0]["event"] == &"throw_release", "throw forwards one release event")
	if action_events.size() == 1:
		_expect((action_events[0]["direction"] as Vector2).is_equal_approx(throw_direction), "throw event preserves captured aim")
	_expect(not held_flask.visible, "throw hides the held flask at release")
	_expect(await _wait_until_not_busy(adapter, 0.8), "throw automatically finishes")
	_expect(not (player.call(&"is_movement_locked") as bool), "throw recovery unlocks movement")

	action_events.clear()
	interruptions.clear()
	finished_actions.clear()
	_expect(
		adapter.call(&"request_potion_action", &"drink", Vector2.ZERO, health_color) as bool,
		"drink can start for interruption testing"
	)
	await _advance(0.2)
	health.take_damage(1)
	await _advance(0.1)
	_expect(interruptions == [&"drink"], "pre-commit damage interrupts the drink once")
	_expect(action_events.is_empty(), "interrupted drink emits no commit event")
	_expect(not held_flask.visible, "interruption hides the held flask")
	_expect(player.call(&"is_movement_locked") as bool, "hit keeps movement locked")
	_expect(await _wait_until_not_busy(adapter, 0.9), "hit automatically recovers")
	_expect(not (player.call(&"is_movement_locked") as bool), "hit recovery unlocks movement")
	_expect(action_events.is_empty(), "interrupted drink never commits after hit recovery")

	action_events.clear()
	finished_actions.clear()
	_expect(
		adapter.call(&"request_potion_action", &"drink", Vector2.ZERO, health_color) as bool,
		"drink can start for missing-event recovery testing"
	)
	_expect(held_flask.visible, "missing-event test starts with a visible held flask")
	adapter.call(&"_on_rig_state_finished", &"drink")
	await get_tree().process_frame
	_expect(not (adapter.call(&"is_busy") as bool), "missing-event completion releases the adapter")
	_expect(not (player.call(&"is_movement_locked") as bool), "missing-event completion unlocks movement")
	_expect(not held_flask.visible, "missing-event completion hides the held flask")
	_expect(action_events.is_empty(), "missing-event completion cannot synthesize a commit")
	_expect(finished_actions == [&"drink"], "missing-event completion reports the unfinished action")

	_expect(not (adapter.call(&"request_potion_action", &"unknown", Vector2.ZERO, Color.WHITE) as bool), "unknown action is rejected")
	player.queue_free()
	await get_tree().process_frame


func _wait_for_state(rig: Node, expected_state: StringName, timeout: float) -> bool:
	var frame_count := ceili(timeout * FRAME_RATE)
	for _frame in range(frame_count):
		if (rig.call(&"get_current_state") as StringName) == expected_state:
			return true
		await get_tree().process_frame
	return (rig.call(&"get_current_state") as StringName) == expected_state


func _advance(duration: float) -> void:
	for _frame in range(ceili(duration * FRAME_RATE)):
		await get_tree().process_frame


func _wait_until_not_busy(adapter: Node, timeout: float) -> bool:
	var frame_count := ceili(timeout * FRAME_RATE)
	for _frame in range(frame_count):
		if not (adapter.call(&"is_busy") as bool):
			return true
		await get_tree().process_frame
	return not (adapter.call(&"is_busy") as bool)


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
