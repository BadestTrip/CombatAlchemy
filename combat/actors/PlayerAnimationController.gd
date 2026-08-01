class_name PlayerAnimationController
extends Node

# Responsibility: Adapt player movement, health, and potion actions to the reusable cutout rig.

signal action_event(event_name: StringName, committed_direction: Vector2)
signal action_interrupted(action: StringName)
signal action_finished(action: StringName)

const ACTION_DRINK := &"drink"
const ACTION_THROW := &"throw"
const ACTION_HIT := &"hit"
const EVENT_DRINK_COMMIT := &"drink_commit"
const EVENT_THROW_RELEASE := &"throw_release"
const LOCOMOTION_IDLE := &"idle"
const LOCOMOTION_WALK := &"walk"
const MOVEMENT_EPSILON_SQUARED := 0.0001

## Path to the HumanoidCutoutRig instance that owns authored playback.
@export var rig_path: NodePath
## Path to the PlayerCombatController that owns movement and aiming.
@export var player_controller_path: NodePath
## Path to the HealthComponent whose real damage events trigger hit reactions.
@export var health_component_path: NodePath
## Scene-backed prop attached to the rig's right-hand socket.
@export var held_flask_scene: PackedScene = preload("res://combat/actors/HeldPotionFlask.tscn")

var _rig: Node
var _player_controller: PlayerCombatController
var _health_component: HealthComponent
var _right_hand_socket: Marker2D
var _held_flask: Node2D
var _active_action: StringName = &""
var _requested_state: StringName = &""
var _committed_direction := Vector2.ZERO
var _action_committed := false
var _last_velocity := Vector2.ZERO


func _ready() -> void:
	_rig = get_node_or_null(rig_path)
	_player_controller = get_node_or_null(player_controller_path) as PlayerCombatController
	_health_component = get_node_or_null(health_component_path) as HealthComponent
	if _rig != null and _rig.has_method(&"get_socket"):
		_right_hand_socket = _rig.call(&"get_socket", &"hand_right") as Marker2D
	if not _validate_dependencies():
		return

	var flask_instance := held_flask_scene.instantiate() as Node2D
	if flask_instance == null:
		push_error("PlayerAnimationController could not instantiate HeldPotionFlask.")
		return
	if not flask_instance.has_method(&"show_potion") or not flask_instance.has_method(&"hide_potion"):
		push_error("PlayerAnimationController requires the HeldPotionFlask public API.")
		flask_instance.queue_free()
		return
	_right_hand_socket.add_child(flask_instance)
	_held_flask = flask_instance
	_held_flask.call(&"hide_potion")

	_player_controller.movement_changed.connect(_on_movement_changed)
	_health_component.damaged.connect(_on_damaged)
	_rig.connect(&"state_changed", _on_rig_state_changed)
	_rig.connect(&"animation_event", _on_rig_animation_event)
	_rig.connect(&"state_finished", _on_rig_state_finished)
	_requested_state = _rig.call(&"get_current_state") as StringName


## Starts a drink or throw when no other authored action owns the player.
func request_potion_action(
	action: StringName,
	aim_direction: Vector2,
	potion_color: Color
) -> bool:
	if action not in [ACTION_DRINK, ACTION_THROW] or is_busy() or _held_flask == null:
		return false

	var resolved_direction := Vector2.ZERO
	if action == ACTION_THROW:
		resolved_direction = (
			aim_direction.normalized()
			if aim_direction.length_squared() > MOVEMENT_EPSILON_SQUARED
			else _get_current_facing_direction()
		)
		_apply_horizontal_facing(resolved_direction.x)

	_active_action = action
	_committed_direction = resolved_direction
	_action_committed = false
	if not (_rig.call(&"play_state", action) as bool):
		_clear_active_action()
		return false

	_requested_state = action
	_player_controller.set_movement_locked(true)
	_held_flask.call(&"show_potion", potion_color)
	return true


## Returns whether drink, throw, or hit currently owns movement and animation.
func is_busy() -> bool:
	return not _active_action.is_empty()


## Returns the animated right-hand position used for potion release.
func get_action_origin() -> Vector2:
	return _right_hand_socket.global_position if _right_hand_socket != null else Vector2.ZERO


func _on_movement_changed(current_velocity: Vector2) -> void:
	_last_velocity = current_velocity
	if is_busy():
		return
	_apply_locomotion(current_velocity)


func _apply_locomotion(current_velocity: Vector2) -> void:
	if absf(current_velocity.x) > 0.01:
		_apply_horizontal_facing(current_velocity.x)
	var desired_state := (
		LOCOMOTION_WALK
		if current_velocity.length_squared() > MOVEMENT_EPSILON_SQUARED
		else LOCOMOTION_IDLE
	)
	_request_state_once(desired_state)


func _request_state_once(state: StringName) -> void:
	if _requested_state == state:
		return
	if _rig.call(&"play_state", state) as bool:
		_requested_state = state


func _apply_horizontal_facing(horizontal_direction: float) -> void:
	if absf(horizontal_direction) <= 0.01:
		return
	_rig.call(&"set_mirrored", horizontal_direction < 0.0)


func _get_current_facing_direction() -> Vector2:
	var facing_root := _rig.get_node_or_null(^"FacingRoot") as Node2D
	if facing_root != null and facing_root.scale.x < 0.0:
		return Vector2.LEFT
	return Vector2.RIGHT


func _on_rig_animation_event(event_name: StringName) -> void:
	var expected_event := &""
	if _active_action == ACTION_DRINK:
		expected_event = EVENT_DRINK_COMMIT
	elif _active_action == ACTION_THROW:
		expected_event = EVENT_THROW_RELEASE
	if expected_event.is_empty() or event_name != expected_event or _action_committed:
		return

	_action_committed = true
	if _held_flask != null:
		_held_flask.call(&"hide_potion")
	action_event.emit(event_name, _committed_direction)


func _on_rig_state_changed(state: StringName) -> void:
	if not is_busy():
		_requested_state = state


func _on_rig_state_finished(state: StringName) -> void:
	if state != _active_action:
		return

	var completed_action := _active_action
	_clear_active_action()
	_player_controller.set_movement_locked(false)
	action_finished.emit(completed_action)
	_apply_locomotion(_last_velocity)


func _on_damaged(amount: int) -> void:
	if amount <= 0 or _active_action == ACTION_HIT:
		return

	var interrupted_action := _active_action
	var lost_uncommitted_potion := (
		interrupted_action in [ACTION_DRINK, ACTION_THROW]
		and not _action_committed
	)
	if _held_flask != null:
		_held_flask.call(&"hide_potion")
	if lost_uncommitted_potion:
		action_interrupted.emit(interrupted_action)
	_start_hit()


func _start_hit() -> void:
	_active_action = ACTION_HIT
	_committed_direction = Vector2.ZERO
	_action_committed = false
	_player_controller.set_movement_locked(true)
	if _rig.call(&"play_state", ACTION_HIT) as bool:
		_requested_state = ACTION_HIT
		return
	_clear_active_action()
	_player_controller.set_movement_locked(false)


func _clear_active_action() -> void:
	if _held_flask != null:
		_held_flask.call(&"hide_potion")
	_active_action = &""
	_committed_direction = Vector2.ZERO
	_action_committed = false


func _validate_dependencies() -> bool:
	var missing_dependencies: Array[String] = []
	if _rig == null:
		missing_dependencies.append("HumanoidCutoutRig")
	elif not _has_rig_api():
		missing_dependencies.append("HumanoidCutoutRig public API")
	if _player_controller == null:
		missing_dependencies.append("PlayerCombatController")
	if _health_component == null:
		missing_dependencies.append("HealthComponent")
	if _right_hand_socket == null:
		missing_dependencies.append("right-hand socket")
	if held_flask_scene == null:
		missing_dependencies.append("HeldPotionFlask scene")
	if missing_dependencies.is_empty():
		return true
	push_error("PlayerAnimationController requires: %s." % ", ".join(missing_dependencies))
	return false


func _has_rig_api() -> bool:
	var required_methods: Array[StringName] = [
		&"play_state",
		&"get_current_state",
		&"get_socket",
		&"set_mirrored",
	]
	for method_name in required_methods:
		if not _rig.has_method(method_name):
			return false

	var required_signals: Array[StringName] = [
		&"state_changed",
		&"animation_event",
		&"state_finished",
	]
	for signal_name in required_signals:
		if not _rig.has_signal(signal_name):
			return false
	return true
