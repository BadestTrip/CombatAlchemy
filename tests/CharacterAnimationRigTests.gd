extends Node

# Responsibility: Verify the isolated cutout rig's authored structure and public contract.

const RIG_SCENE_PATH := "res://experiments/character_animation/HumanoidCutoutRig.tscn"
const LAB_SCENE_PATH := "res://experiments/character_animation/CharacterAnimationLab.tscn"
const REQUIRED_BONE_PATHS: Array[NodePath] = [
	^"FacingRoot/Skeleton2D/Root",
	^"FacingRoot/Skeleton2D/Root/Spine",
	^"FacingRoot/Skeleton2D/Root/Spine/Head",
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L",
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L",
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L/Hand_L",
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R",
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R",
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/Hand_R",
	^"FacingRoot/Skeleton2D/Root/Thigh_L",
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L",
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/Foot_L",
	^"FacingRoot/Skeleton2D/Root/Thigh_R",
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R",
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/Foot_R",
]
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"RESET",
	&"idle",
	&"walk",
	&"drink",
	&"throw",
	&"hit",
]
const EXPECTED_ANIMATION_LENGTHS := {
	&"RESET": 0.1,
	&"idle": 1.6,
	&"walk": 0.8,
	&"drink": 1.0,
	&"throw": 0.75,
	&"hit": 0.45,
}

var _failures: Array[String] = []
var _check_count := 0
var _events: Array[StringName] = []


func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("CharacterAnimationRigTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("CharacterAnimationRigTests: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _run_tests() -> void:
	var rig_scene := load(RIG_SCENE_PATH) as PackedScene
	_expect(rig_scene != null, "rig scene exists and parses")
	if rig_scene == null:
		return

	var rig := rig_scene.instantiate()
	_expect(rig != null, "rig scene instantiates")
	if rig == null:
		return

	add_child(rig)
	await get_tree().process_frame
	_test_authored_structure(rig)
	_test_public_contract(rig)
	await _test_action_events_and_returns(rig)
	rig.queue_free()
	await get_tree().process_frame
	await _test_lab_layout()


func _test_authored_structure(rig: Node) -> void:
	for bone_path in REQUIRED_BONE_PATHS:
		_expect(rig.get_node_or_null(bone_path) is Bone2D, "%s is an authored Bone2D" % bone_path)

	_expect(
		rig.get_node_or_null(^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L/Hand_L/HandSocket_L") is Marker2D,
		"left hand socket exists"
	)
	_expect(
		rig.get_node_or_null(^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/Hand_R/HandSocket_R") is Marker2D,
		"right hand socket exists"
	)

	var animation_player := rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_expect(animation_player != null, "AnimationPlayer exists")
	if animation_player != null:
		for animation_name in REQUIRED_ANIMATIONS:
			_expect(animation_player.has_animation(animation_name), "%s clip exists" % animation_name)
			_expect(
				is_equal_approx(animation_player.get_animation(animation_name).length, EXPECTED_ANIMATION_LENGTHS[animation_name]),
				"%s uses its documented duration" % animation_name
			)
		_expect(
			animation_player.get_animation(&"idle").loop_mode == Animation.LOOP_LINEAR,
			"idle loops"
		)
		_expect(
			animation_player.get_animation(&"walk").loop_mode == Animation.LOOP_LINEAR,
			"walk loops"
		)
		for action_name in [&"drink", &"throw", &"hit"]:
			_expect(
				animation_player.get_animation(action_name).loop_mode == Animation.LOOP_NONE,
				"%s is a one-shot" % action_name
			)
		_expect(_animation_has_event(animation_player.get_animation(&"drink"), &"drink_commit", 0.55), "drink_commit is authored at 0.55 seconds")
		_expect(_animation_has_event(animation_player.get_animation(&"throw"), &"throw_release", 0.45), "throw_release is authored at 0.45 seconds")
		_expect(_animation_has_event(animation_player.get_animation(&"hit"), &"hit_peak", 0.18), "hit_peak is authored at 0.18 seconds")

	var animation_tree := rig.get_node_or_null(^"AnimationTree") as AnimationTree
	_expect(animation_tree != null, "AnimationTree exists")
	if animation_tree == null:
		return
	_expect(animation_tree.active, "AnimationTree is active after rig startup")
	_expect(animation_tree.tree_root is AnimationNodeBlendTree, "AnimationTree root is a BlendTree")
	var blend_tree := animation_tree.tree_root as AnimationNodeBlendTree
	if blend_tree == null:
		return
	_expect(blend_tree.get_node(&"StateMachine") is AnimationNodeStateMachine, "BlendTree contains StateMachine")
	_expect(blend_tree.get_node(&"TimeScale") is AnimationNodeTimeScale, "BlendTree contains TimeScale")
	var state_machine := blend_tree.get_node(&"StateMachine") as AnimationNodeStateMachine
	if state_machine != null:
		for animation_name in REQUIRED_ANIMATIONS:
			_expect(state_machine.has_node(animation_name), "state machine contains %s" % animation_name)
		_expect(_has_transition(state_machine, &"idle", &"walk", 0.12), "idle transitions to walk over 0.12 seconds")
		_expect(_has_transition(state_machine, &"walk", &"idle", 0.12), "walk transitions to idle over 0.12 seconds")
		for action_name in [&"drink", &"throw", &"hit"]:
			_expect(_has_transition(state_machine, &"idle", action_name, 0.08), "idle enters %s over 0.08 seconds" % action_name)
			_expect(_has_transition(state_machine, action_name, &"idle", 0.10, true), "%s auto-returns to idle over 0.10 seconds" % action_name)


func _test_public_contract(rig: Node) -> void:
	_expect(rig.has_signal(&"state_changed"), "state_changed signal exists")
	_expect(rig.has_signal(&"animation_event"), "animation_event signal exists")
	var available_states: Array[StringName] = rig.call(&"get_available_states")
	_expect(available_states == REQUIRED_ANIMATIONS, "available states use the documented stable order")
	_expect(rig.call(&"play_state", &"walk") as bool, "valid state request succeeds")
	_expect(not (rig.call(&"play_state", &"missing") as bool), "invalid state request is rejected")

	var facing_root := rig.get_node(^"FacingRoot") as Node2D
	var skeleton := rig.get_node(^"FacingRoot/Skeleton2D") as Skeleton2D
	var rig_scale_before := (rig as Node2D).scale
	var skeleton_scale_before := skeleton.scale
	rig.call(&"set_mirrored", true)
	_expect(facing_root.scale.x < 0.0, "mirroring flips FacingRoot")
	_expect((rig as Node2D).scale == rig_scale_before, "mirroring does not change the rig root")
	_expect(skeleton.scale == skeleton_scale_before, "mirroring does not change Skeleton2D")
	rig.call(&"set_mirrored", false)
	_expect(facing_root.scale.x > 0.0, "mirroring can be disabled")

	var animation_tree := rig.get_node(^"AnimationTree") as AnimationTree
	rig.call(&"set_playback_speed", 0.01)
	_expect(is_equal_approx(animation_tree.get(&"parameters/TimeScale/scale") as float, 0.25), "speed clamps to 0.25")
	rig.call(&"set_playback_speed", 5.0)
	_expect(is_equal_approx(animation_tree.get(&"parameters/TimeScale/scale") as float, 2.0), "speed clamps to 2.0")

	rig.call(&"set_debug_bones_visible", true)
	_expect((rig.get_node(^"FacingRoot/DebugBones") as CanvasItem).visible, "bone overlay can be shown")
	var root_indicator := rig.get_node(^"FacingRoot/Skeleton2D/Root/BoneIndicator") as Line2D
	_expect(root_indicator.visible, "authored bone lines follow the overlay toggle")
	rig.call(&"set_debug_bones_visible", false)
	_expect(not (rig.get_node(^"FacingRoot/DebugBones") as CanvasItem).visible, "bone overlay can be hidden")
	_expect(not root_indicator.visible, "authored bone lines can be hidden")


func _test_action_events_and_returns(rig: Node) -> void:
	rig.animation_event.connect(_on_animation_event)
	rig.call(&"set_playback_speed", 2.0)
	await _expect_action_cycle(rig, &"drink", &"drink_commit", 0.7)
	await _expect_action_cycle(rig, &"throw", &"throw_release", 0.6)
	await _expect_action_cycle(rig, &"hit", &"hit_peak", 0.45)


func _expect_action_cycle(rig: Node, state: StringName, expected_event: StringName, wait_seconds: float) -> void:
	_events.clear()
	_expect(rig.call(&"play_state", state) as bool, "%s can be requested" % state)
	await get_tree().create_timer(wait_seconds).timeout
	_expect(expected_event in _events, "%s emits %s" % [state, expected_event])
	_expect(rig.call(&"get_current_state") as StringName == &"idle", "%s automatically returns to idle" % state)


func _test_lab_layout() -> void:
	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	_expect(lab_scene != null, "lab scene exists and parses")
	if lab_scene == null:
		return
	var test_viewport := SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	add_child(test_viewport)
	var lab := lab_scene.instantiate()
	test_viewport.add_child(lab)
	await get_tree().process_frame
	var viewport_size := Vector2(test_viewport.size)
	var background := lab.get_node(^"Background") as Control
	var rig := lab.get_node(^"StageAnchor/HumanoidCutoutRig") as Node2D
	var toolbar := lab.get_node(^"UI/ToolbarMargin") as Control
	var controls_row := lab.get_node(^"UI/ToolbarMargin/ToolbarPanel/ToolbarPadding/ToolbarColumn/ControlsRow") as Control
	_expect(background.size.is_equal_approx(viewport_size), "lab background fills the viewport")
	_expect(is_equal_approx(rig.global_position.x, viewport_size.x * 0.5), "lab rig stays horizontally centered")
	_expect(rig.global_position.y > 0.0 and rig.global_position.y < viewport_size.y * 0.75, "lab rig remains on the visible stage")
	_expect(toolbar.position.x >= 0.0 and toolbar.position.x + toolbar.size.x <= viewport_size.x, "lab toolbar stays within a 1280-pixel viewport")
	_expect(controls_row.size.x <= toolbar.size.x, "lab controls do not overflow the small toolbar")
	lab.queue_free()
	test_viewport.queue_free()
	await get_tree().process_frame


func _has_transition(
	state_machine: AnimationNodeStateMachine,
	from_state: StringName,
	to_state: StringName,
	expected_crossfade: float,
	requires_auto_advance := false
) -> bool:
	for index in state_machine.get_transition_count():
		if state_machine.get_transition_from(index) != from_state:
			continue
		if state_machine.get_transition_to(index) != to_state:
			continue
		var transition := state_machine.get_transition(index)
		if not is_equal_approx(transition.xfade_time, expected_crossfade):
			continue
		if requires_auto_advance and transition.advance_mode != AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO:
			continue
		return true
	return false


func _animation_has_event(animation: Animation, event_name: StringName, event_time: float) -> bool:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD:
			continue
		for key_index in animation.track_get_key_count(track_index):
			if not is_equal_approx(animation.track_get_key_time(track_index, key_index), event_time):
				continue
			var method_data := animation.track_get_key_value(track_index, key_index) as Dictionary
			if method_data.get("method", &"") != &"_emit_animation_event":
				continue
			var arguments: Variant = method_data.get("args", [])
			if arguments is Array and not arguments.is_empty() and String(arguments[0]) == String(event_name):
				return true
	return false


func _on_animation_event(event_name: StringName) -> void:
	_events.append(event_name)


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
