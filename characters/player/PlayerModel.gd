extends Node2D

## Public locomotion facade for the balanced 15-bone geometric rig.
## AnimationPlayer owns authored clips; AnimationTree owns synchronized facing changes.

signal facing_changed(facing: StringName)
signal locomotion_changed(state: StringName)

const FACING_FRONT := &"front"
const FACING_BACK := &"back"
const FACING_SIDE_LEFT := &"side_left"
const FACING_SIDE_RIGHT := &"side_right"
const FAMILY_VERTICAL := &"vertical"
const FAMILY_SIDE := &"side"
const LOCOMOTION_IDLE := &"idle"
const LOCOMOTION_WALK := &"walk"
const REQUIRED_FACINGS: Array[StringName] = [
	FACING_FRONT,
	FACING_BACK,
	FACING_SIDE_LEFT,
	FACING_SIDE_RIGHT,
]
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"RESET",
	&"idle_front",
	&"idle_back",
	&"idle_side_left",
	&"idle_side_right",
	&"walk_front",
	&"walk_back",
	&"walk_side_left",
	&"walk_side_right",
]
const MOTION_EPSILON_SQUARED := 0.0001
const DIRECTION_HYSTERESIS := 0.10
const LOCOMOTION_BLEND_SECONDS := 0.12
const MIN_PLAYBACK_SPEED := 0.25
const MAX_PLAYBACK_SPEED := 2.0
const DEBUG_LINE_METADATA := &"compact_bone_indicator"
const HAND_LEFT_SOCKET_PATH := ^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_L/Forearm_L/Hand_L/HandSocket_L"
const HAND_RIGHT_SOCKET_PATH := ^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_R/Forearm_R/Hand_R/HandSocket_R"

@onready var _facing_root: Node2D = get_node_or_null(^"FacingRoot") as Node2D
@onready var _skeleton: Skeleton2D = get_node_or_null(^"FacingRoot/Skeleton2D") as Skeleton2D
@onready var _animation_player: AnimationPlayer = get_node_or_null(^"AnimationPlayer") as AnimationPlayer
@onready var _animation_tree: AnimationTree = get_node_or_null(^"AnimationTree") as AnimationTree

var _idle_playback: AnimationNodeStateMachinePlayback
var _walk_playback: AnimationNodeStateMachinePlayback
var _debug_lines: Array[Line2D] = []
var _facing := FACING_FRONT
var _facing_family := FAMILY_VERTICAL
var _locomotion_state := LOCOMOTION_IDLE
var _locomotion_blend := 0.0
var _locomotion_blend_start := 0.0
var _locomotion_blend_target := 0.0
var _locomotion_blend_elapsed := LOCOMOTION_BLEND_SECONDS
var _is_operational := false


func _ready() -> void:
	_cache_debug_lines()
	set_debug_bones_visible(false)
	if not _validate_dependencies(true):
		set_process(false)
		return

	_animation_tree.active = true
	_idle_playback = _animation_tree.get(&"parameters/IdleDirection/playback") as AnimationNodeStateMachinePlayback
	_walk_playback = _animation_tree.get(&"parameters/WalkDirection/playback") as AnimationNodeStateMachinePlayback
	if _idle_playback == null or _walk_playback == null:
		push_error("CompactDirectionalHumanoidRig could not acquire direction state-machine playback.")
		_animation_tree.active = false
		set_process(false)
		return

	_is_operational = true
	_ensure_positive_facing_scale()
	_idle_playback.start(FACING_FRONT)
	_walk_playback.start(FACING_FRONT)
	_apply_animation_parameters()


func _process(delta: float) -> void:
	if not _is_operational:
		return
	if not is_equal_approx(_locomotion_blend, _locomotion_blend_target):
		_locomotion_blend_elapsed = minf(
			_locomotion_blend_elapsed + delta,
			LOCOMOTION_BLEND_SECONDS
		)
		var weight := smoothstep(
			0.0,
			1.0,
			_locomotion_blend_elapsed / LOCOMOTION_BLEND_SECONDS
		)
		_locomotion_blend = lerpf(
			_locomotion_blend_start,
			_locomotion_blend_target,
			weight
		)
		_apply_animation_parameters()


## Updates idle/walk playback and derives an authored facing from world velocity.
func set_motion(velocity: Vector2) -> void:
	if not _is_operational:
		return
	if velocity.length_squared() <= MOTION_EPSILON_SQUARED:
		_set_locomotion_state(LOCOMOTION_IDLE)
		return
	_set_locomotion_state(LOCOMOTION_WALK)
	_set_facing_from_direction(velocity.normalized())


## Updates facing without changing locomotion. Near-zero requests are rejected.
func set_facing_direction(direction: Vector2) -> bool:
	if not _is_operational or direction.length_squared() <= MOTION_EPSILON_SQUARED:
		return false
	_set_facing_from_direction(direction.normalized())
	return true


## Immediately restores front-facing idle without waiting for a blend.
func reset_to_idle() -> void:
	if not _is_operational:
		return
	var previous_facing := _facing
	var previous_locomotion := _locomotion_state
	_facing = FACING_FRONT
	_facing_family = FAMILY_VERTICAL
	_locomotion_state = LOCOMOTION_IDLE
	_locomotion_blend = 0.0
	_locomotion_blend_start = 0.0
	_locomotion_blend_target = 0.0
	_locomotion_blend_elapsed = LOCOMOTION_BLEND_SECONDS
	_ensure_positive_facing_scale()
	_idle_playback.start(FACING_FRONT)
	_walk_playback.start(FACING_FRONT)
	_apply_animation_parameters()
	if previous_facing != _facing:
		facing_changed.emit(_facing)
	if previous_locomotion != _locomotion_state:
		locomotion_changed.emit(_locomotion_state)


## Scales authored playback without changing world movement speed.
func set_playback_speed(multiplier: float) -> void:
	if _animation_tree == null:
		return
	_animation_tree.set(
		&"parameters/TimeScale/scale",
		clampf(multiplier, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
	)


## Toggles the developer-only bone overlay.
func set_debug_bones_visible(is_visible: bool) -> void:
	for line in _debug_lines:
		line.visible = is_visible


## Returns front, back, side_left, or side_right.
func get_facing() -> StringName:
	return _facing


## Returns idle or walk.
func get_locomotion_state() -> StringName:
	return _locomotion_state


func get_socket(socket_id: StringName) -> Marker2D:
	match socket_id:
		&"hand_left":
			return get_node_or_null(HAND_LEFT_SOCKET_PATH) as Marker2D
		&"hand_right":
			return get_node_or_null(HAND_RIGHT_SOCKET_PATH) as Marker2D
		_:
			return null


func _set_facing_from_direction(direction: Vector2) -> void:
	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	var selected_family := _facing_family

	if abs_x > abs_y + DIRECTION_HYSTERESIS:
		selected_family = FAMILY_SIDE
	elif abs_y > abs_x + DIRECTION_HYSTERESIS:
		selected_family = FAMILY_VERTICAL

	var selected_facing: StringName
	if selected_family == FAMILY_SIDE:
		selected_facing = FACING_SIDE_LEFT if direction.x < 0.0 else FACING_SIDE_RIGHT
	else:
		selected_facing = FACING_FRONT if direction.y > 0.0 else FACING_BACK
	_set_facing(selected_facing, selected_family)


func _set_facing(new_facing: StringName, new_family: StringName) -> void:
	if new_facing == _facing:
		_facing_family = new_family
		return
	_facing = new_facing
	_facing_family = new_family
	_ensure_positive_facing_scale()
	_idle_playback.travel(_facing)
	_walk_playback.travel(_facing)
	facing_changed.emit(_facing)


func _set_locomotion_state(new_state: StringName) -> void:
	if new_state == _locomotion_state:
		return
	_locomotion_state = new_state
	_locomotion_blend_start = _locomotion_blend
	_locomotion_blend_target = 1.0 if new_state == LOCOMOTION_WALK else 0.0
	_locomotion_blend_elapsed = 0.0
	locomotion_changed.emit(_locomotion_state)


func _apply_animation_parameters() -> void:
	if _animation_tree == null:
		return
	_animation_tree.set(&"parameters/Locomotion/blend_amount", _locomotion_blend)


func _ensure_positive_facing_scale() -> void:
	if _facing_root == null:
		return
	var positive_x := absf(_facing_root.scale.x)
	_facing_root.scale.x = positive_x if positive_x > 0.001 else 1.0


func _cache_debug_lines() -> void:
	_debug_lines.clear()
	if _facing_root == null:
		return
	for candidate in _facing_root.find_children("*", "Line2D", true, false):
		var line := candidate as Line2D
		if line != null and line.has_meta(DEBUG_LINE_METADATA):
			_debug_lines.append(line)


func _validate_dependencies(report_errors: bool) -> bool:
	var missing: Array[String] = []
	if _facing_root == null:
		missing.append("FacingRoot")
	if _skeleton == null:
		missing.append("FacingRoot/Skeleton2D")
	if get_socket(&"hand_left") == null:
		missing.append("HandSocket_L")
	if get_socket(&"hand_right") == null:
		missing.append("HandSocket_R")
	if _animation_player == null:
		missing.append("AnimationPlayer")
	else:
		for animation_name in REQUIRED_ANIMATIONS:
			if not _animation_player.has_animation(animation_name):
				missing.append("AnimationPlayer/%s" % animation_name)

	if _animation_tree == null or _animation_tree.tree_root == null:
		missing.append("AnimationTree")
	elif _animation_tree.tree_root is AnimationNodeBlendTree:
		var blend_tree := _animation_tree.tree_root as AnimationNodeBlendTree
		var idle_machine := blend_tree.get_node(&"IdleDirection") as AnimationNodeStateMachine
		var walk_machine := blend_tree.get_node(&"WalkDirection") as AnimationNodeStateMachine
		if idle_machine == null:
			missing.append("AnimationTree/IdleDirection")
		else:
			_validate_facing_states(idle_machine, "IdleDirection", missing)
		if walk_machine == null:
			missing.append("AnimationTree/WalkDirection")
		else:
			_validate_facing_states(walk_machine, "WalkDirection", missing)
		if not blend_tree.get_node(&"Locomotion") is AnimationNodeBlend2:
			missing.append("AnimationTree/Locomotion")
		if not blend_tree.get_node(&"TimeScale") is AnimationNodeTimeScale:
			missing.append("AnimationTree/TimeScale")
	else:
		missing.append("AnimationTree BlendTree root")

	if not missing.is_empty() and report_errors:
		push_error("CompactDirectionalHumanoidRig requires: %s." % ", ".join(missing))
	return missing.is_empty()


func _validate_facing_states(
	machine: AnimationNodeStateMachine,
	machine_name: String,
	missing: Array[String]
) -> void:
	for facing in REQUIRED_FACINGS:
		if not machine.has_node(facing):
			missing.append("AnimationTree/%s/%s" % [machine_name, facing])
