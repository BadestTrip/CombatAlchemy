extends Node

# Responsibility: Verify the isolated directional locomotion rig and movement lab.

const RIG_SCENE_PATH := "res://experiments/directional_character_animation/DirectionalHumanoidRig.tscn"
const RIG_SCRIPT_PATH := "res://experiments/directional_character_animation/DirectionalHumanoidRig.gd"
const LAB_SCENE_PATH := "res://experiments/directional_character_animation/DirectionalAnimationLab.tscn"
const REQUIRED_BONE_PATHS: Array[NodePath] = [
	^"FacingRoot/Skeleton2D/Root",
	^"FacingRoot/Skeleton2D/Root/Pelvis",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Neck",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Neck/Head",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_L/UpperArm_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_L/UpperArm_L/Forearm_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_L/UpperArm_L/Forearm_L/Wrist_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_L/UpperArm_L/Forearm_L/Wrist_L/Hand_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_R/UpperArm_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_R/UpperArm_R/Forearm_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_R/UpperArm_R/Forearm_R/Wrist_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/SpineLower/Chest/Clavicle_R/UpperArm_R/Forearm_R/Wrist_R/Hand_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_L/Shin_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_L/Shin_L/Ankle_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_L/Shin_L/Ankle_L/Foot_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_L/Shin_L/Ankle_L/Foot_L/Toe_L",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_R/Shin_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_R/Shin_R/Ankle_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_R/Shin_R/Ankle_R/Foot_R",
	^"FacingRoot/Skeleton2D/Root/Pelvis/Thigh_R/Shin_R/Ankle_R/Foot_R/Toe_R",
]
const REQUIRED_ANIMATIONS := {
	&"RESET": 0.1,
	&"idle_front": 1.6,
	&"idle_back": 1.6,
	&"idle_side": 1.6,
	&"walk_front": 0.72,
	&"walk_back": 0.72,
	&"walk_side": 0.72,
}
const WALK_PHASES: Array[float] = [0.0, 0.18, 0.36, 0.54, 0.72]
const REQUIRED_METHODS: Array[StringName] = [
	&"set_motion",
	&"set_facing_direction",
	&"reset_to_idle",
	&"set_playback_speed",
	&"set_debug_bones_visible",
	&"get_facing",
	&"get_locomotion_state",
]

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("DirectionalAnimationRigTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("DirectionalAnimationRigTests: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _run_tests() -> void:
	_expect(FileAccess.file_exists(RIG_SCENE_PATH), "directional rig scene exists")
	if not FileAccess.file_exists(RIG_SCENE_PATH):
		return
	var rig_scene := load(RIG_SCENE_PATH) as PackedScene
	_expect(rig_scene != null, "directional rig scene exists and parses")
	if rig_scene == null:
		return

	var rig := rig_scene.instantiate()
	_expect(rig != null, "directional rig scene instantiates")
	if rig == null:
		return
	add_child(rig)
	await get_tree().process_frame

	_test_structure(rig)
	_test_animation_resources(rig)
	await _test_public_behavior(rig)
	rig.queue_free()
	await get_tree().process_frame
	_test_missing_dependency_handling()
	await _test_lab()


func _test_structure(rig: Node) -> void:
	for bone_path in REQUIRED_BONE_PATHS:
		var bone := rig.get_node_or_null(bone_path) as Bone2D
		_expect(bone != null, "%s is an authored Bone2D" % bone_path)
		if bone != null:
			_expect(
				bone.rest.is_equal_approx(bone.transform),
				"%s stores its authored transform as its rest pose" % bone_path
			)

	var polygon_count := rig.find_children("*", "Polygon2D", true, false).size()
	_expect(polygon_count >= 18, "rig contains scene-authored geometric body parts")
	var indicators := rig.find_children("*", "Line2D", true, false)
	_expect(indicators.size() >= REQUIRED_BONE_PATHS.size(), "rig contains optional authored bone indicators")
	for indicator in indicators:
		_expect(not (indicator as Line2D).visible, "%s starts hidden" % rig.get_path_to(indicator))


func _test_animation_resources(rig: Node) -> void:
	var animation_player := rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_expect(animation_player != null, "AnimationPlayer exists")
	if animation_player == null:
		return

	for animation_name: StringName in REQUIRED_ANIMATIONS:
		_expect(animation_player.has_animation(animation_name), "%s clip exists" % animation_name)
		if not animation_player.has_animation(animation_name):
			continue
		var animation := animation_player.get_animation(animation_name)
		_expect(
			is_equal_approx(animation.length, REQUIRED_ANIMATIONS[animation_name]),
			"%s uses its required duration" % animation_name
		)
		var expected_loop := (
			Animation.LOOP_NONE
			if animation_name == &"RESET"
			else Animation.LOOP_LINEAR
		)
		_expect(animation.loop_mode == expected_loop, "%s uses its required loop mode" % animation_name)
		if animation_name.begins_with("walk_"):
			_expect(_animation_contains_phases(animation, WALK_PHASES), "%s authors every gait phase" % animation_name)

	var animation_tree := rig.get_node_or_null(^"AnimationTree") as AnimationTree
	_expect(animation_tree != null, "AnimationTree exists")
	if animation_tree == null:
		return
	_expect(animation_tree.active, "AnimationTree activates on startup")
	_expect(animation_tree.tree_root is AnimationNodeBlendTree, "AnimationTree root is a BlendTree")
	var blend_tree := animation_tree.tree_root as AnimationNodeBlendTree
	if blend_tree == null:
		return

	var idle_space := blend_tree.get_node(&"IdleDirection") as AnimationNodeBlendSpace1D
	var walk_space := blend_tree.get_node(&"WalkDirection") as AnimationNodeBlendSpace1D
	_expect(idle_space != null, "BlendTree contains IdleDirection")
	_expect(walk_space != null, "BlendTree contains WalkDirection")
	_expect(blend_tree.get_node(&"Locomotion") is AnimationNodeBlend2, "BlendTree contains Locomotion")
	_expect(blend_tree.get_node(&"TimeScale") is AnimationNodeTimeScale, "BlendTree contains TimeScale")
	if idle_space != null:
		_expect(
			idle_space.sync_mode == AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_CONSTANT,
			"idle directions use cyclic constant synchronization"
		)
		_expect(is_equal_approx(idle_space.cyclic_length, 1.6), "idle synchronization uses 1.6 seconds")
		_test_blend_points(idle_space, [&"back", &"side", &"front"])
	if walk_space != null:
		_expect(
			walk_space.sync_mode == AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_CONSTANT,
			"walk directions use cyclic constant synchronization"
		)
		_expect(is_equal_approx(walk_space.cyclic_length, 0.72), "walk synchronization uses 0.72 seconds")
		_test_blend_points(walk_space, [&"back", &"side", &"front"])


func _test_public_behavior(rig: Node) -> void:
	for method_name in REQUIRED_METHODS:
		_expect(rig.has_method(method_name), "%s is exposed" % method_name)
	_expect(rig.has_signal(&"facing_changed"), "facing_changed signal exists")
	_expect(rig.has_signal(&"locomotion_changed"), "locomotion_changed signal exists")

	_expect(rig.call(&"get_facing") as StringName == &"front", "rig starts facing front")
	_expect(rig.call(&"get_locomotion_state") as StringName == &"idle", "rig starts idle")

	rig.call(&"set_motion", Vector2.DOWN * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"front", "downward movement faces front")
	_expect(rig.call(&"get_locomotion_state") as StringName == &"walk", "nonzero movement walks")
	rig.call(&"set_motion", Vector2.UP * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"back", "upward movement faces back")
	rig.call(&"set_motion", Vector2.RIGHT * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"side_right", "rightward movement uses right side")
	rig.call(&"set_motion", Vector2.LEFT * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"side_left", "leftward movement uses left side")
	_expect((rig.get_node(^"FacingRoot") as Node2D).scale.x < 0.0, "left side mirrors FacingRoot")

	rig.call(&"set_motion", Vector2.RIGHT * 220.0)
	rig.call(&"set_motion", Vector2(1.0, -1.0).normalized() * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"side_right", "diagonal movement preserves side family")
	rig.call(&"set_motion", Vector2.UP * 220.0)
	rig.call(&"set_motion", Vector2(1.0, -1.0).normalized() * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"back", "diagonal movement preserves vertical family")

	rig.call(&"reset_to_idle")
	rig.call(&"set_motion", Vector2(1.0, -1.0).normalized() * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"back", "initial upward diagonal selects back")
	rig.call(&"set_motion", Vector2.ZERO)
	_expect(rig.call(&"get_locomotion_state") as StringName == &"idle", "zero velocity returns to idle")
	_expect(rig.call(&"get_facing") as StringName == &"back", "idle preserves the last facing")

	var facing_before := rig.call(&"get_facing") as StringName
	_expect(not (rig.call(&"set_facing_direction", Vector2.ZERO) as bool), "zero explicit facing is rejected")
	_expect(rig.call(&"get_facing") as StringName == facing_before, "rejected facing leaves state unchanged")

	var animation_tree := rig.get_node(^"AnimationTree") as AnimationTree
	rig.call(&"set_playback_speed", 0.01)
	_expect(is_equal_approx(animation_tree.get(&"parameters/TimeScale/scale") as float, 0.25), "speed clamps to 0.25")
	rig.call(&"set_playback_speed", 5.0)
	_expect(is_equal_approx(animation_tree.get(&"parameters/TimeScale/scale") as float, 2.0), "speed clamps to 2.0")
	rig.call(&"set_playback_speed", 1.0)

	rig.call(&"set_debug_bones_visible", true)
	for indicator in rig.find_children("*", "Line2D", true, false):
		_expect((indicator as Line2D).visible, "%s can be shown" % rig.get_path_to(indicator))
	rig.call(&"set_debug_bones_visible", false)
	for indicator in rig.find_children("*", "Line2D", true, false):
		_expect(not (indicator as Line2D).visible, "%s can be hidden" % rig.get_path_to(indicator))

	rig.call(&"set_motion", Vector2.DOWN * 220.0)
	await get_tree().create_timer(0.14).timeout
	var direction_before := animation_tree.get(&"parameters/WalkDirection/blend_position") as float
	rig.call(&"set_motion", Vector2.RIGHT * 220.0)
	var direction_immediate := animation_tree.get(&"parameters/WalkDirection/blend_position") as float
	await get_tree().create_timer(0.05).timeout
	var direction_midway := animation_tree.get(&"parameters/WalkDirection/blend_position") as float
	await get_tree().create_timer(0.08).timeout
	var direction_after := animation_tree.get(&"parameters/WalkDirection/blend_position") as float
	_expect(direction_before > 0.9, "front walk reaches its directional target")
	_expect(direction_immediate > 0.9, "direction change does not snap the blend position")
	_expect(direction_midway > 0.0 and direction_midway < 1.0, "direction change blends between families")
	_expect(absf(direction_after) < 0.05, "direction change reaches the side target")

	var locomotion_before_reversal := (
		animation_tree.get(&"parameters/Locomotion/blend_amount") as float
	)
	rig.call(&"set_motion", Vector2.LEFT * 220.0)
	var direction_after_reversal := (
		animation_tree.get(&"parameters/WalkDirection/blend_position") as float
	)
	var locomotion_after_reversal := (
		animation_tree.get(&"parameters/Locomotion/blend_amount") as float
	)
	_expect(
		is_equal_approx(direction_after, direction_after_reversal)
		and is_equal_approx(locomotion_before_reversal, locomotion_after_reversal),
		"side reversal keeps the active walk stream and its gait phase"
	)
	_expect((rig.get_node(^"FacingRoot") as Node2D).scale.x < 0.0, "side reversal mirrors immediately")


func _test_missing_dependency_handling() -> void:
	var rig_script := load(RIG_SCRIPT_PATH) as Script
	_expect(rig_script != null, "directional rig controller script parses")
	if rig_script == null:
		return
	var incomplete_rig := Node2D.new()
	incomplete_rig.set_script(rig_script)
	_expect(
		not (incomplete_rig.call(&"_validate_dependencies", false) as bool),
		"incomplete rigs are detected before playback"
	)
	incomplete_rig.call(&"set_motion", Vector2.RIGHT * 220.0)
	_expect(
		incomplete_rig.call(&"get_locomotion_state") as StringName == &"idle",
		"incomplete rigs keep playback disabled"
	)
	incomplete_rig.free()


func _test_lab() -> void:
	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	_expect(lab_scene != null, "directional animation lab exists and parses")
	if lab_scene == null:
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var lab := lab_scene.instantiate()
	viewport.add_child(lab)
	await get_tree().process_frame

	var actor := lab.get_node_or_null(^"DirectionalLabActor") as CharacterBody2D
	var camera := lab.get_node_or_null(^"DirectionalLabActor/Camera2D") as Camera2D
	_expect(actor != null, "lab contains one movable CharacterBody2D")
	_expect(camera != null and camera.enabled, "lab camera follows the actor")
	if camera != null:
		_expect(not camera.position_smoothing_enabled, "lab camera follow has no smoothing")
		_expect(camera.limit_left == 0 and camera.limit_top == 0, "camera uses the room's top-left limits")
		_expect(camera.limit_right == 3200 and camera.limit_bottom == 1800, "camera uses the room's bottom-right limits")
	_expect(lab.get_node_or_null(^"HUD/StatusPanel/StatusRow/LocomotionValue") is Label, "lab displays locomotion")
	_expect(lab.get_node_or_null(^"HUD/StatusPanel/StatusRow/FacingValue") is Label, "lab displays facing")
	_expect(lab.find_children("*", "Button", true, false).is_empty(), "lab has no action or toolbar buttons")
	_expect(lab.find_children("*", "Range", true, false).is_empty(), "lab has no tuning sliders")

	lab.queue_free()
	viewport.queue_free()
	await get_tree().process_frame


func _test_blend_points(space: AnimationNodeBlendSpace1D, expected_names: Array[StringName]) -> void:
	_expect(space.get_blend_point_count() == 3, "direction blend space has exactly three points")
	for index in expected_names.size():
		_expect(space.get_blend_point_name(index) == expected_names[index], "%s blend point is ordered correctly" % expected_names[index])
		_expect(
			is_equal_approx(space.get_blend_point_position(index), float(index - 1)),
			"%s blend point uses its required coordinate" % expected_names[index]
		)


func _animation_contains_phases(animation: Animation, phases: Array[float]) -> bool:
	for track_index in animation.get_track_count():
		var key_times: Array[float] = []
		for key_index in animation.track_get_key_count(track_index):
			key_times.append(animation.track_get_key_time(track_index, key_index))
		var contains_all := true
		for phase in phases:
			if not _contains_approx(key_times, phase):
				contains_all = false
				break
		if contains_all:
			return true
	return false


func _contains_approx(values: Array[float], expected: float) -> bool:
	for value in values:
		if is_equal_approx(value, expected):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
