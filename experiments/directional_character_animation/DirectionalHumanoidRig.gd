extends Node2D

## Reusable locomotion facade for the three-direction geometric cutout rig.
## Bone motion and geometry are authored in the scene and external animation library.

signal facing_changed(facing: StringName)
signal locomotion_changed(state: StringName)

const FACING_FRONT := &"front"
const FACING_BACK := &"back"
const FACING_SIDE_LEFT := &"side_left"
const FACING_SIDE_RIGHT := &"side_right"
const FAMILY_FRONT := &"front"
const FAMILY_BACK := &"back"
const FAMILY_SIDE := &"side"
const LOCOMOTION_IDLE := &"idle"
const LOCOMOTION_WALK := &"walk"
const MOTION_EPSILON_SQUARED := 0.0001
const DIRECTION_HYSTERESIS := 0.10
const DIRECTION_BLEND_SECONDS := 0.10
const LOCOMOTION_BLEND_SECONDS := 0.12
const MIN_PLAYBACK_SPEED := 0.25
const MAX_PLAYBACK_SPEED := 2.0
const DEBUG_LINE_METADATA := &"directional_bone_indicator"
const VISUAL_LAYER_METADATA := &"directional_visual_layer"
const DIRECTION_BLEND_VALUES := {
	FAMILY_BACK: -1.0,
	FAMILY_SIDE: 0.0,
	FAMILY_FRONT: 1.0,
}

@onready var _facing_root := get_node_or_null(^"FacingRoot") as Node2D
@onready var _skeleton := get_node_or_null(^"FacingRoot/Skeleton2D") as Skeleton2D
@onready var _animation_player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
@onready var _animation_tree := get_node_or_null(^"AnimationTree") as AnimationTree

var _debug_lines: Array[Line2D] = []
var _facing := FACING_FRONT
var _facing_family := FAMILY_FRONT
var _locomotion_state := LOCOMOTION_IDLE
var _direction_blend := 1.0
var _direction_blend_start := 1.0
var _direction_blend_target := 1.0
var _direction_blend_elapsed := DIRECTION_BLEND_SECONDS
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
	_is_operational = true
	_apply_directional_layers()
	_apply_animation_parameters()


func _process(delta: float) -> void:
	if not _is_operational:
		return
	_direction_blend = _advance_blend(
		_direction_blend_start,
		_direction_blend_target,
		_direction_blend,
		delta,
		DIRECTION_BLEND_SECONDS,
		true
	)
	_locomotion_blend = _advance_blend(
		_locomotion_blend_start,
		_locomotion_blend_target,
		_locomotion_blend,
		delta,
		LOCOMOTION_BLEND_SECONDS,
		false
	)
	_apply_animation_parameters()


## Updates idle/walk playback and derives facing from nonzero world velocity.
func set_motion(velocity: Vector2) -> void:
	if not _is_operational:
		return
	if velocity.length_squared() <= MOTION_EPSILON_SQUARED:
		_set_locomotion_state(LOCOMOTION_IDLE)
		return
	_set_locomotion_state(LOCOMOTION_WALK)
	_set_facing_from_direction(velocity.normalized())


## Updates facing without changing idle/walk state. Returns false for a zero direction.
func set_facing_direction(direction: Vector2) -> bool:
	if not _is_operational or direction.length_squared() <= MOTION_EPSILON_SQUARED:
		return false
	_set_facing_from_direction(direction.normalized())
	return true


## Immediately restores the default front-facing idle pose.
func reset_to_idle() -> void:
	if not _is_operational:
		return
	var previous_facing := _facing
	var previous_locomotion := _locomotion_state
	_facing = FACING_FRONT
	_facing_family = FAMILY_FRONT
	_locomotion_state = LOCOMOTION_IDLE
	_direction_blend = 1.0
	_direction_blend_start = 1.0
	_direction_blend_target = 1.0
	_direction_blend_elapsed = DIRECTION_BLEND_SECONDS
	_locomotion_blend = 0.0
	_locomotion_blend_start = 0.0
	_locomotion_blend_target = 0.0
	_locomotion_blend_elapsed = LOCOMOTION_BLEND_SECONDS
	_set_mirrored(false)
	_apply_directional_layers()
	_apply_animation_parameters()
	if previous_facing != _facing:
		facing_changed.emit(_facing)
	if previous_locomotion != _locomotion_state:
		locomotion_changed.emit(_locomotion_state)


## Scales authored playback without changing movement speed.
func set_playback_speed(multiplier: float) -> void:
	if _animation_tree == null:
		return
	_animation_tree.set(
		&"parameters/TimeScale/scale",
		clampf(multiplier, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
	)


## Shows or hides the developer-only authored bone lines.
func set_debug_bones_visible(is_visible: bool) -> void:
	for line in _debug_lines:
		line.visible = is_visible


## Returns front, back, side_left, or side_right.
func get_facing() -> StringName:
	return _facing


## Returns idle or walk.
func get_locomotion_state() -> StringName:
	return _locomotion_state


func _set_facing_from_direction(direction: Vector2) -> void:
	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	var selected_family := _facing_family

	if abs_x > abs_y + DIRECTION_HYSTERESIS:
		selected_family = FAMILY_SIDE
	elif abs_y > abs_x + DIRECTION_HYSTERESIS:
		selected_family = FAMILY_FRONT if direction.y > 0.0 else FAMILY_BACK
	elif _facing_family != FAMILY_SIDE:
		selected_family = FAMILY_FRONT if direction.y > 0.0 else FAMILY_BACK

	var selected_facing := selected_family
	if selected_family == FAMILY_SIDE:
		selected_facing = FACING_SIDE_LEFT if direction.x < 0.0 else FACING_SIDE_RIGHT
	_set_facing(selected_facing, selected_family)


func _set_facing(new_facing: StringName, new_family: StringName) -> void:
	var facing_did_change := new_facing != _facing
	var family_did_change := new_family != _facing_family
	_facing = new_facing
	_facing_family = new_family
	_set_mirrored(_facing == FACING_SIDE_LEFT)

	if family_did_change:
		_direction_blend_start = _direction_blend
		_direction_blend_target = DIRECTION_BLEND_VALUES[_facing_family]
		_direction_blend_elapsed = 0.0
		_apply_directional_layers()
	if facing_did_change:
		facing_changed.emit(_facing)


func _set_locomotion_state(new_state: StringName) -> void:
	if new_state == _locomotion_state:
		return
	_locomotion_state = new_state
	_locomotion_blend_start = _locomotion_blend
	_locomotion_blend_target = 1.0 if new_state == LOCOMOTION_WALK else 0.0
	_locomotion_blend_elapsed = 0.0
	locomotion_changed.emit(_locomotion_state)


func _advance_blend(
	start_value: float,
	target_value: float,
	current_value: float,
	delta: float,
	duration: float,
	is_direction: bool
) -> float:
	if is_equal_approx(current_value, target_value):
		return target_value
	if is_direction:
		_direction_blend_elapsed = minf(_direction_blend_elapsed + delta, duration)
		var direction_weight := smoothstep(0.0, 1.0, _direction_blend_elapsed / duration)
		return lerpf(start_value, target_value, direction_weight)
	_locomotion_blend_elapsed = minf(_locomotion_blend_elapsed + delta, duration)
	var locomotion_weight := smoothstep(0.0, 1.0, _locomotion_blend_elapsed / duration)
	return lerpf(start_value, target_value, locomotion_weight)


func _apply_animation_parameters() -> void:
	if _animation_tree == null:
		return
	_animation_tree.set(&"parameters/IdleDirection/blend_position", _direction_blend)
	_animation_tree.set(&"parameters/WalkDirection/blend_position", _direction_blend)
	_animation_tree.set(&"parameters/Locomotion/blend_amount", _locomotion_blend)


func _set_mirrored(is_mirrored: bool) -> void:
	if _facing_root == null:
		return
	_facing_root.scale.x = -1.0 if is_mirrored else 1.0


func _apply_directional_layers() -> void:
	if _skeleton == null:
		return
	var near_side := &"left" if _facing_family == FAMILY_BACK else &"right"
	for candidate in _skeleton.find_children("*", "Polygon2D", true, false):
		var visual := candidate as Polygon2D
		if visual == null or not visual.has_meta(VISUAL_LAYER_METADATA):
			continue
		var layer_role := visual.get_meta(VISUAL_LAYER_METADATA) as StringName
		if layer_role == &"face":
			visual.z_index = 5
		elif layer_role == &"head":
			visual.z_index = 4
		elif layer_role == &"core":
			visual.z_index = 2
		elif layer_role == near_side:
			visual.z_index = 3
		else:
			visual.z_index = 1


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
		missing.append("Skeleton2D")
	if _animation_player == null:
		missing.append("AnimationPlayer")
	if _animation_tree == null or _animation_tree.tree_root == null:
		missing.append("AnimationTree")
	elif _animation_tree.tree_root is AnimationNodeBlendTree:
		var blend_tree := _animation_tree.tree_root as AnimationNodeBlendTree
		for node_name in [&"IdleDirection", &"WalkDirection", &"Locomotion", &"TimeScale"]:
			if blend_tree.get_node(node_name) == null:
				missing.append("AnimationTree/%s" % node_name)
	else:
		missing.append("AnimationTree BlendTree root")
	if not missing.is_empty() and report_errors:
		push_error("DirectionalHumanoidRig requires: %s." % ", ".join(missing))
	return missing.is_empty()
