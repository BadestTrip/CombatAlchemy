extends Node2D

## Reusable playback facade for the authored humanoid cutout rig.
## The scene owns bones and visuals; the external library owns animation clips.

signal state_changed(state: StringName)
signal animation_event(event_name: StringName)
signal state_finished(state: StringName)

const AVAILABLE_STATES: Array[StringName] = [
	&"RESET",
	&"idle",
	&"walk",
	&"drink",
	&"throw",
	&"hit",
]
const MIN_PLAYBACK_SPEED := 0.25
const MAX_PLAYBACK_SPEED := 2.0
const DEBUG_LINE_METADATA := &"cutout_bone_indicator"
const SOCKET_PATHS := {
	&"hand_left": ^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L/Hand_L/HandSocket_L",
	&"hand_right": ^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/Hand_R/HandSocket_R",
}

## Keeps authored left/right Sprite2D anatomy from being reflected with FacingRoot.
@export var preserve_authored_sprite_handedness := false

@onready var _facing_root: Node2D = %FacingRoot
@onready var _debug_bones: Node2D = %DebugBones
@onready var _animation_player: AnimationPlayer = %AnimationPlayer
@onready var _animation_tree: AnimationTree = %AnimationTree

var _playback: AnimationNodeStateMachinePlayback
var _last_reported_state: StringName = &""
var _debug_lines: Array[Line2D] = []
var _handed_sprites: Array[Sprite2D] = []
var _authored_sprite_scales: Dictionary = {}


func _ready() -> void:
	if not _validate_dependencies():
		set_process(false)
		return

	_cache_debug_lines()
	_cache_handed_sprites()
	set_debug_bones_visible(false)
	_animation_tree.active = true
	_animation_tree.animation_finished.connect(_on_animation_finished)
	_playback = _animation_tree.get(&"parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
	if _playback == null:
		push_error("HumanoidCutoutRig requires a StateMachine node named 'StateMachine'.")
		set_process(false)
		return
	_playback.start(&"idle", true)
	_report_state_if_changed(true)


func _process(_delta: float) -> void:
	_report_state_if_changed()


## Requests an authored state. Returns false without changing playback for unknown states.
func play_state(state: StringName) -> bool:
	if state not in AVAILABLE_STATES or _playback == null:
		return false
	if _playback.get_current_node() == state:
		_playback.start(state, true)
	else:
		_playback.travel(state, true)
	_report_state_if_changed(true)
	return true


## Immediately restores neutral looping playback.
func reset_to_idle() -> void:
	if _playback == null:
		return
	_playback.start(&"idle", true)
	_report_state_if_changed(true)


## Mirrors only the visual-facing container, leaving root gameplay transforms unchanged.
func set_mirrored(is_mirrored: bool) -> void:
	if _facing_root == null:
		return
	var horizontal_sign := -1.0 if is_mirrored else 1.0
	_facing_root.scale.x = absf(_facing_root.scale.x) * horizontal_sign
	_apply_sprite_handedness(is_mirrored)


## Changes all state playback through the authored TimeScale node.
func set_playback_speed(multiplier: float) -> void:
	if _animation_tree == null:
		return
	_animation_tree.set(
		&"parameters/TimeScale/scale",
		clampf(multiplier, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
	)


## Shows or hides the non-gameplay bone overlay authored into the rig scene.
func set_debug_bones_visible(is_visible: bool) -> void:
	if _debug_bones != null:
		_debug_bones.visible = is_visible
	for line in _debug_lines:
		line.visible = is_visible


## Returns the state currently owned by AnimationTree, including automatic transitions.
func get_current_state() -> StringName:
	if _playback == null:
		return &""
	return _playback.get_current_node()


## Returns a copy so callers cannot mutate the rig's supported-state contract.
func get_available_states() -> Array[StringName]:
	var states: Array[StringName] = []
	states.assign(AVAILABLE_STATES)
	return states


## Returns a stable authored attachment socket, or null for an unknown socket id.
func get_socket(socket_id: StringName) -> Marker2D:
	if not SOCKET_PATHS.has(socket_id):
		return null
	var socket_path: NodePath = SOCKET_PATHS[socket_id]
	return get_node_or_null(socket_path) as Marker2D


## Called by method tracks in HumanoidAnimationLibrary.tres.
func _emit_animation_event(event_name: StringName) -> void:
	animation_event.emit(event_name)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name in AVAILABLE_STATES:
		state_finished.emit(animation_name)


func _validate_dependencies() -> bool:
	var valid := true
	if _facing_root == null:
		push_error("HumanoidCutoutRig is missing FacingRoot.")
		valid = false
	if _debug_bones == null:
		push_error("HumanoidCutoutRig is missing DebugBones.")
		valid = false
	if _animation_player == null:
		push_error("HumanoidCutoutRig is missing AnimationPlayer.")
		valid = false
	if _animation_tree == null or _animation_tree.tree_root == null:
		push_error("HumanoidCutoutRig is missing its authored AnimationTree.")
		valid = false
	return valid


func _cache_debug_lines() -> void:
	_debug_lines.clear()
	for candidate in _facing_root.find_children("*", "Line2D", true, false):
		var line := candidate as Line2D
		if line != null and line.has_meta(DEBUG_LINE_METADATA):
			_debug_lines.append(line)


func _cache_handed_sprites() -> void:
	_handed_sprites.clear()
	_authored_sprite_scales.clear()
	if not preserve_authored_sprite_handedness:
		return
	for candidate in _facing_root.find_children("*", "Sprite2D", true, false):
		var sprite := candidate as Sprite2D
		if sprite == null:
			continue
		_handed_sprites.append(sprite)
		_authored_sprite_scales[sprite] = sprite.scale


func _apply_sprite_handedness(is_mirrored: bool) -> void:
	if not preserve_authored_sprite_handedness:
		return
	var local_horizontal_sign := -1.0 if is_mirrored else 1.0
	for sprite in _handed_sprites:
		if not is_instance_valid(sprite) or not _authored_sprite_scales.has(sprite):
			continue
		var authored_scale: Vector2 = _authored_sprite_scales[sprite]
		sprite.scale = Vector2(
			authored_scale.x * local_horizontal_sign,
			authored_scale.y
		)


func _report_state_if_changed(force_emit := false) -> void:
	var current_state := get_current_state()
	if current_state.is_empty():
		return
	if not force_emit and current_state == _last_reported_state:
		return
	_last_reported_state = current_state
	state_changed.emit(current_state)
