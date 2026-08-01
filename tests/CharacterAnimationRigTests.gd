extends Node

# Responsibility: Verify the isolated cutout rig's authored structure and public contract.

const RIG_SCENE_PATH := "res://characters/animation/HumanoidCutoutRig.tscn"
const RESEARCHER_RIG_SCENE_PATH := "res://characters/animation/ResearcherCutoutRig.tscn"
const PLAYER_SCENE_PATH := "res://combat/actors/PlayerActor.tscn"
const LAB_SCENE_PATH := "res://experiments/character_animation/CharacterAnimationLab.tscn"
const REQUIRED_BONE_PATHS: Array[NodePath] = [
	^"FacingRoot/Skeleton2D/Root",
	^"FacingRoot/Skeleton2D/Root/CoatTail_L",
	^"FacingRoot/Skeleton2D/Root/CoatTail_C",
	^"FacingRoot/Skeleton2D/Root/CoatTail_R",
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
const COAT_BONE_SPECS := {
	^"FacingRoot/Skeleton2D/Root/CoatTail_L": {
		"position": Vector2(-14.0, 8.0),
		"length": 76.0,
		"rotation_degrees": 3.0,
	},
	^"FacingRoot/Skeleton2D/Root/CoatTail_C": {
		"position": Vector2(0.0, 10.0),
		"length": 84.0,
		"rotation_degrees": 0.0,
	},
	^"FacingRoot/Skeleton2D/Root/CoatTail_R": {
		"position": Vector2(14.0, 8.0),
		"length": 72.0,
		"rotation_degrees": -3.0,
	},
}
const COAT_ROTATION_TRACKS: Array[NodePath] = [
	^"FacingRoot/Skeleton2D/Root/CoatTail_L:rotation",
	^"FacingRoot/Skeleton2D/Root/CoatTail_C:rotation",
	^"FacingRoot/Skeleton2D/Root/CoatTail_R:rotation",
]
const COAT_REST_DEGREES := {
	^"FacingRoot/Skeleton2D/Root/CoatTail_L:rotation": 3.0,
	^"FacingRoot/Skeleton2D/Root/CoatTail_C:rotation": 0.0,
	^"FacingRoot/Skeleton2D/Root/CoatTail_R:rotation": -3.0,
}
const COAT_MOTION_RANGES := {
	&"idle": Vector2(0.5, 1.5),
	&"walk": Vector2(2.0, 5.0),
	&"drink": Vector2(1.0, 2.0),
	&"throw": Vector2(8.0, 10.0),
	&"hit": Vector2(10.0, 10.0),
}
const RESEARCHER_SPRITE_LAYERS := {
	^"FacingRoot/Skeleton2D/Root/CoatTail_L/CoatTailArt": 0,
	^"FacingRoot/Skeleton2D/Root/CoatTail_C/CoatTailArt": 0,
	^"FacingRoot/Skeleton2D/Root/CoatTail_R/CoatTailArt": 0,
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/UpperArmArt": 1,
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L/ForearmArt": 1,
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L/Hand_L/HandArt": 1,
	^"FacingRoot/Skeleton2D/Root/Thigh_L/ThighArt": 1,
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/ShinArt": 1,
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/Foot_L/BootArt": 1,
	^"FacingRoot/Skeleton2D/Root/PelvisArt": 2,
	^"FacingRoot/Skeleton2D/Root/Spine/TorsoArt": 2,
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/UpperArmArt": 3,
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/ForearmArt": 3,
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/Hand_R/HandArt": 3,
	^"FacingRoot/Skeleton2D/Root/Thigh_R/ThighArt": 3,
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/ShinArt": 3,
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/Foot_R/BootArt": 3,
	^"FacingRoot/Skeleton2D/Root/Spine/Head/HeadArt": 4,
	^"FacingRoot/Skeleton2D/Root/Spine/Head/HatArt": 4,
	^"FacingRoot/Skeleton2D/Root/Spine/ChestEquipmentArt": 5,
	^"FacingRoot/Skeleton2D/Root/Spine/SatchelArt": 5,
}
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
	await _test_researcher_skin()
	await _test_player_uses_researcher_skin()
	await _test_lab_layout()


func _test_authored_structure(rig: Node) -> void:
	for bone_path in REQUIRED_BONE_PATHS:
		_expect(rig.get_node_or_null(bone_path) is Bone2D, "%s is an authored Bone2D" % bone_path)
	for coat_path: NodePath in COAT_BONE_SPECS:
		var coat_bone := rig.get_node_or_null(coat_path) as Bone2D
		if coat_bone == null:
			continue
		var spec: Dictionary = COAT_BONE_SPECS[coat_path]
		_expect(coat_bone.position.is_equal_approx(spec["position"]), "%s uses its documented position" % coat_path)
		_expect(is_equal_approx(coat_bone.length, spec["length"]), "%s uses its documented length" % coat_path)
		_expect(
			is_equal_approx(coat_bone.rotation_degrees, spec["rotation_degrees"]),
			"%s uses its documented rest rotation" % coat_path
		)
		_expect(
			coat_bone.rest.origin.is_equal_approx(spec["position"]),
			"%s stores its position in the rest transform" % coat_path
		)
		_expect(
			is_equal_approx(rad_to_deg(coat_bone.rest.get_rotation()), spec["rotation_degrees"]),
			"%s stores its rotation in the rest transform" % coat_path
		)
		var indicator := coat_bone.get_node_or_null(^"BoneIndicator") as Line2D
		_expect(indicator != null, "%s has an authored debug line" % coat_path)
		if indicator != null:
			_expect(indicator.z_index == 20, "%s debug line uses layer 20" % coat_path)

	_expect(
		rig.get_node_or_null(^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L/Hand_L/HandSocket_L") is Marker2D,
		"left hand socket exists"
	)
	_expect(
		rig.get_node_or_null(^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/Hand_R/HandSocket_R") is Marker2D,
		"right hand socket exists"
	)
	_expect(rig.call(&"get_socket", &"hand_left") is Marker2D, "left socket is exposed by id")
	_expect(rig.call(&"get_socket", &"hand_right") is Marker2D, "right socket is exposed by id")
	_expect(rig.call(&"get_socket", &"missing") == null, "unknown socket id is rejected")

	var animation_player := rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_expect(animation_player != null, "AnimationPlayer exists")
	if animation_player != null:
		for animation_name in REQUIRED_ANIMATIONS:
			_expect(animation_player.has_animation(animation_name), "%s clip exists" % animation_name)
			_expect(
				is_equal_approx(animation_player.get_animation(animation_name).length, EXPECTED_ANIMATION_LENGTHS[animation_name]),
				"%s uses its documented duration" % animation_name
			)
			for track_path in COAT_ROTATION_TRACKS:
				var coat_track_index := animation_player.get_animation(animation_name).find_track(track_path, Animation.TYPE_VALUE)
				_expect(
					coat_track_index >= 0,
					"%s animates %s" % [animation_name, track_path]
				)
				if coat_track_index < 0:
					continue
				var max_delta := _get_max_rotation_delta_degrees(
					animation_player.get_animation(animation_name),
					coat_track_index,
					COAT_REST_DEGREES[track_path]
				)
				if animation_name == &"RESET":
					_expect(is_zero_approx(max_delta), "RESET keeps %s at rest" % track_path)
					continue
				var motion_range: Vector2 = COAT_MOTION_RANGES[animation_name]
				_expect(
					max_delta >= motion_range.x - 0.01 and max_delta <= motion_range.y + 0.01,
					"%s moves %s within its documented range" % [animation_name, track_path]
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
		_expect(_has_transition(state_machine, &"drink", &"hit", 0.04), "drink can be interrupted by hit over 0.04 seconds")
		_expect(_has_transition(state_machine, &"throw", &"hit", 0.04), "throw can be interrupted by hit over 0.04 seconds")

	for visual in rig.find_children("*", "Polygon2D", true, false):
		var canvas_visual := visual as CanvasItem
		_expect(canvas_visual.z_index >= 0, "%s does not use a negative visual layer" % rig.get_path_to(canvas_visual))


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


func _test_researcher_skin() -> void:
	var researcher_scene := load(RESEARCHER_RIG_SCENE_PATH) as PackedScene
	_expect(researcher_scene != null, "researcher rig scene exists and parses")
	if researcher_scene == null:
		return
	var rig := researcher_scene.instantiate()
	_expect(rig != null, "researcher rig scene instantiates")
	if rig == null:
		return
	add_child(rig)
	await get_tree().process_frame

	_expect(rig.has_method(&"play_state"), "researcher skin preserves play_state")
	_expect(rig.has_method(&"get_socket"), "researcher skin preserves get_socket")
	_expect(rig.call(&"get_socket", &"hand_left") is Marker2D, "researcher skin preserves left socket")
	_expect(rig.call(&"get_socket", &"hand_right") is Marker2D, "researcher skin preserves right socket")
	_expect(rig.call(&"get_available_states") as Array[StringName] == REQUIRED_ANIMATIONS, "researcher skin preserves animation states")

	for placeholder in rig.find_children("*", "Polygon2D", true, false):
		_expect(not (placeholder as Polygon2D).visible, "%s placeholder is hidden by the researcher skin" % rig.get_path_to(placeholder))

	for sprite_path: NodePath in RESEARCHER_SPRITE_LAYERS:
		var sprite := rig.get_node_or_null(sprite_path) as Sprite2D
		_expect(sprite != null, "%s is an authored Sprite2D" % sprite_path)
		if sprite == null:
			continue
		_expect(sprite.z_index == RESEARCHER_SPRITE_LAYERS[sprite_path], "%s uses its documented visual layer" % sprite_path)
		_expect(sprite.position.is_zero_approx(), "%s rotates around its controlling bone" % sprite_path)
		_expect(sprite.texture is AtlasTexture, "%s uses an AtlasTexture region" % sprite_path)
		var atlas_texture := sprite.texture as AtlasTexture
		if atlas_texture == null:
			continue
		_expect(atlas_texture.region.size.x > 0.0 and atlas_texture.region.size.y > 0.0, "%s has a nonempty atlas region" % sprite_path)
		_expect(atlas_texture.atlas != null, "%s has a source atlas" % sprite_path)
		_expect(sprite.has_meta(&"joint_pivot_px"), "%s documents its joint pivot" % sprite_path)
		if sprite.has_meta(&"joint_pivot_px"):
			var pivot := sprite.get_meta(&"joint_pivot_px") as Vector2
			var expected_offset := atlas_texture.region.size * 0.5 - pivot
			_expect(sprite.offset.is_equal_approx(expected_offset), "%s offset places its joint pivot at the bone origin" % sprite_path)
		if atlas_texture.atlas != null:
			var image := atlas_texture.atlas.get_image()
			_expect(image != null and image.detect_alpha() != Image.ALPHA_NONE, "%s source atlas contains transparency" % sprite_path)

	for canvas_item in rig.find_children("*", "CanvasItem", true, false):
		_expect((canvas_item as CanvasItem).z_index >= 0, "%s has a nonnegative effective visual layer" % rig.get_path_to(canvas_item))
	rig.queue_free()
	await get_tree().process_frame


func _test_player_uses_researcher_skin() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	_expect(player_scene != null, "player scene exists and parses")
	if player_scene == null:
		return
	var player := player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	var player_rig := player.get_node_or_null(^"PlayerVisual")
	_expect(player_rig != null, "player has its authored visual rig")
	if player_rig != null:
		_expect(player_rig.scene_file_path == RESEARCHER_RIG_SCENE_PATH, "player instances the researcher skin")
	player.queue_free()
	await get_tree().process_frame


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
	_expect(rig.scene_file_path == RESEARCHER_RIG_SCENE_PATH, "animation lab instances the researcher skin")
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


func _get_max_rotation_delta_degrees(
	animation: Animation,
	track_index: int,
	rest_degrees: float
) -> float:
	var max_delta := 0.0
	for key_index in animation.track_get_key_count(track_index):
		var key_radians := animation.track_get_key_value(track_index, key_index) as float
		max_delta = maxf(max_delta, absf(rad_to_deg(key_radians) - rest_degrees))
	return max_delta


func _on_animation_event(event_name: StringName) -> void:
	_events.append(event_name)


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
