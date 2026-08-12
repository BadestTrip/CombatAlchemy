extends Node

# Responsibility: Verify the isolated balanced compact directional rig and comparison lab.

const BASE_PATH := "res://experiments/compact_directional_character_animation/"
const RIG_SCENE_PATH := BASE_PATH + "CompactDirectionalHumanoidRig.tscn"
const RIG_SCRIPT_PATH := BASE_PATH + "CompactDirectionalHumanoidRig.gd"
const ANIMATION_LIBRARY_PATH := BASE_PATH + "CompactDirectionalHumanoidAnimationLibrary.tres"
const COMPARISON_LAB_PATH := BASE_PATH + "DirectionalRigComparisonLab.tscn"
const REQUIRED_BONE_PATHS: Array[NodePath] = [
	^"FacingRoot/Skeleton2D/Root",
	^"FacingRoot/Skeleton2D/Root/Torso",
	^"FacingRoot/Skeleton2D/Root/Torso/Head",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_L",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_L/Forearm_L",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_L/Forearm_L/Hand_L",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_R",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_R/Forearm_R",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_R/Forearm_R/Hand_R",
	^"FacingRoot/Skeleton2D/Root/Thigh_L",
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L",
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/Foot_L",
	^"FacingRoot/Skeleton2D/Root/Thigh_R",
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R",
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/Foot_R",
]
const REQUIRED_ANIMATIONS := {
	&"RESET": 0.1,
	&"idle_front": 1.6,
	&"idle_back": 1.6,
	&"idle_side_left": 1.6,
	&"idle_side_right": 1.6,
	&"walk_front": 0.72,
	&"walk_back": 0.72,
	&"walk_side_left": 0.72,
	&"walk_side_right": 0.72,
}
const FACINGS: Array[StringName] = [&"front", &"back", &"side_left", &"side_right"]
const WALK_PHASES: Array[float] = [0.0, 0.09, 0.18, 0.27, 0.36, 0.45, 0.54, 0.63, 0.72]
const IDLE_PHASES: Array[float] = [0.0, 0.4, 0.8, 1.2, 1.6]
const REQUIRED_GAIT_TRACKS: Array[NodePath] = [
	^"FacingRoot/Skeleton2D/Root:position",
	^"FacingRoot/Skeleton2D/Root/Torso:rotation",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_L:rotation",
	^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_R:rotation",
	^"FacingRoot/Skeleton2D/Root/Thigh_L:rotation",
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L:rotation",
	^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/Foot_L:rotation",
	^"FacingRoot/Skeleton2D/Root/Thigh_R:rotation",
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R:rotation",
	^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/Foot_R:rotation",
]
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
		print("CompactDirectionalAnimationRigTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("CompactDirectionalAnimationRigTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _run_tests() -> void:
	_expect(FileAccess.file_exists(RIG_SCENE_PATH), "compact directional rig scene exists")
	if not FileAccess.file_exists(RIG_SCENE_PATH):
		return

	var rig_scene := load(RIG_SCENE_PATH) as PackedScene
	_expect(rig_scene != null, "compact directional rig scene parses")
	if rig_scene == null:
		return

	var rig := rig_scene.instantiate()
	_expect(rig != null, "compact directional rig instantiates")
	if rig == null:
		return

	_test_authored_structure(rig)
	add_child(rig)
	await get_tree().process_frame
	_test_animation_resources(rig)
	await _test_public_behavior(rig)
	rig.queue_free()
	await get_tree().process_frame
	_test_missing_dependency_handling()
	await _test_comparison_lab()


func _test_authored_structure(rig: Node) -> void:
	var skeleton := rig.get_node_or_null(^"FacingRoot/Skeleton2D") as Skeleton2D
	_expect(skeleton != null, "compact rig contains Skeleton2D")
	if skeleton == null:
		return

	var bones := skeleton.find_children("*", "Bone2D", true, false)
	_expect(bones.size() == 15, "compact rig contains exactly 15 bones")
	for bone_path in REQUIRED_BONE_PATHS:
		var bone := rig.get_node_or_null(bone_path) as Bone2D
		_expect(bone != null, "%s is an authored Bone2D" % bone_path)
		if bone != null:
			_expect(bone.rest.is_equal_approx(bone.transform), "%s stores its authored rest pose" % bone_path)

	_expect(
		rig.get_node_or_null(^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_L/Forearm_L/Hand_L/HandSocket_L") is Marker2D,
		"left hand socket is authored beneath Hand_L"
	)
	_expect(
		rig.get_node_or_null(^"FacingRoot/Skeleton2D/Root/Torso/UpperArm_R/Forearm_R/Hand_R/HandSocket_R") is Marker2D,
		"right hand socket is authored beneath Hand_R"
	)

	var indicators := rig.find_children("*", "Line2D", true, false)
	_expect(indicators.size() >= REQUIRED_BONE_PATHS.size(), "compact rig contains authored bone indicators")
	for indicator in indicators:
		_expect(not (indicator as Line2D).visible, "%s starts hidden" % rig.get_path_to(indicator))

	var facing_root := rig.get_node(^"FacingRoot") as Node2D
	var body_visuals: Array[Polygon2D] = []
	for candidate in rig.find_children("*", "Polygon2D", true, false):
		var polygon := candidate as Polygon2D
		if polygon != null and polygon.has_meta(&"compact_body_visual"):
			body_visuals.append(polygon)
	_expect(body_visuals.size() >= 15, "all compact body parts are scene-authored Polygon2D nodes")
	var bounds := _calculate_visual_bounds(facing_root, body_visuals)
	_expect(absf(bounds.size.x - 100.0) <= 1.0, "neutral compact geometry is 100 px wide")
	_expect(absf(bounds.size.y - 116.0) <= 1.0, "neutral compact geometry is 116 px high")
	_expect(absf(bounds.position.y + 78.0) <= 1.0, "neutral geometry extends about 78 px above Root")
	_expect(absf(bounds.end.y - 38.0) <= 1.0, "neutral geometry extends about 38 px below Root")


func _test_animation_resources(rig: Node) -> void:
	var animation_player := rig.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_expect(animation_player != null, "AnimationPlayer exists")
	if animation_player == null:
		return
	_expect(FileAccess.file_exists(ANIMATION_LIBRARY_PATH), "external animation library exists")
	var external_library := animation_player.get_animation_library(&"")
	_expect(external_library != null, "AnimationPlayer owns its named external library")
	if external_library != null:
		_expect(external_library.resource_path == ANIMATION_LIBRARY_PATH, "AnimationPlayer references the external library instead of embedding clips")

	for animation_name: StringName in REQUIRED_ANIMATIONS:
		_expect(animation_player.has_animation(animation_name), "%s clip exists" % animation_name)
		if not animation_player.has_animation(animation_name):
			continue
		var animation := animation_player.get_animation(animation_name)
		_expect(is_equal_approx(animation.length, REQUIRED_ANIMATIONS[animation_name]), "%s uses its required duration" % animation_name)
		var expected_loop := Animation.LOOP_NONE if animation_name == &"RESET" else Animation.LOOP_LINEAR
		_expect(animation.loop_mode == expected_loop, "%s uses its required loop mode" % animation_name)
		if animation_name.begins_with("walk_"):
			_test_walk_animation(animation_name, animation)
		elif animation_name.begins_with("idle_"):
			_test_idle_animation(animation_name, animation)

	var animation_tree := rig.get_node_or_null(^"AnimationTree") as AnimationTree
	_expect(animation_tree != null, "AnimationTree exists")
	if animation_tree == null:
		return
	_expect(animation_tree.active, "AnimationTree activates on startup")
	_expect(animation_tree.tree_root is AnimationNodeBlendTree, "AnimationTree root is a BlendTree")
	var blend_tree := animation_tree.tree_root as AnimationNodeBlendTree
	if blend_tree == null:
		return

	var idle_machine := blend_tree.get_node(&"IdleDirection") as AnimationNodeStateMachine
	var walk_machine := blend_tree.get_node(&"WalkDirection") as AnimationNodeStateMachine
	_expect(idle_machine != null, "BlendTree contains the idle direction state machine")
	_expect(walk_machine != null, "BlendTree contains the walk direction state machine")
	_expect(blend_tree.get_node(&"Locomotion") is AnimationNodeBlend2, "BlendTree contains Locomotion Blend2")
	_expect(blend_tree.get_node(&"TimeScale") is AnimationNodeTimeScale, "BlendTree contains TimeScale")
	if idle_machine != null:
		_test_direction_state_machine(idle_machine, "idle")
	if walk_machine != null:
		_test_direction_state_machine(walk_machine, "walk")
	_test_contact_foot_drift(rig, animation_player, animation_tree)
	_test_idle_foot_stability(rig, animation_player, animation_tree)


func _test_walk_animation(animation_name: StringName, animation: Animation) -> void:
	for track_path in REQUIRED_GAIT_TRACKS:
		var track_index := animation.find_track(track_path, Animation.TYPE_VALUE)
		_expect(track_index >= 0, "%s authors %s" % [animation_name, track_path])
		if track_index < 0:
			continue
		_expect(_track_contains_phases(animation, track_index, WALK_PHASES), "%s %s contains all nine gait keys" % [animation_name, track_path])
		if animation.track_get_key_count(track_index) > 1:
			var first_value: Variant = animation.track_get_key_value(track_index, 0)
			var final_value: Variant = animation.track_get_key_value(track_index, animation.track_get_key_count(track_index) - 1)
			_expect(_variants_equal_approx(first_value, final_value), "%s %s repeats its left-contact pose" % [animation_name, track_path])

	var root_track := animation.find_track(^"FacingRoot/Skeleton2D/Root:position", Animation.TYPE_VALUE)
	if root_track >= 0:
		var expected_bob: Array[float] = [0.0, 2.0, 0.0, -2.0, 0.0, 2.0, 0.0, -2.0, 0.0]
		for index in WALK_PHASES.size():
			var root_position := animation.track_get_key_value(root_track, index) as Vector2
			_expect(is_equal_approx(root_position.y, expected_bob[index]), "%s uses grounded bob at %.2f s" % [animation_name, WALK_PHASES[index]])

	var left_thigh_track := animation.find_track(^"FacingRoot/Skeleton2D/Root/Thigh_L:rotation", Animation.TYPE_VALUE)
	var right_thigh_track := animation.find_track(^"FacingRoot/Skeleton2D/Root/Thigh_R:rotation", Animation.TYPE_VALUE)
	if left_thigh_track >= 0 and right_thigh_track >= 0:
		var left_contact := float(animation.track_get_key_value(left_thigh_track, 0))
		var right_contact := float(animation.track_get_key_value(right_thigh_track, 0))
		var left_opposite := float(animation.track_get_key_value(left_thigh_track, 4))
		var right_opposite := float(animation.track_get_key_value(right_thigh_track, 4))
		_expect(signf(left_contact) == -signf(right_contact), "%s starts with opposing legs" % animation_name)
		_expect(signf(left_contact) == -signf(left_opposite), "%s alternates the left leg by right contact" % animation_name)
		_expect(signf(right_contact) == -signf(right_opposite), "%s alternates the right leg by right contact" % animation_name)
		var side_clip := animation_name.begins_with("walk_side_")
		var expected_amplitude := 20.0 if side_clip else 12.0
		_expect(absf(rad_to_deg(left_contact)) >= expected_amplitude - 2.0, "%s uses the intended thigh swing" % animation_name)


func _test_idle_animation(animation_name: StringName, animation: Animation) -> void:
	var root_track := animation.find_track(^"FacingRoot/Skeleton2D/Root:position", Animation.TYPE_VALUE)
	_expect(root_track >= 0, "%s authors subtle body rise" % animation_name)
	if root_track >= 0:
		_expect(_track_contains_phases(animation, root_track, IDLE_PHASES), "%s uses all five idle keys" % animation_name)
		var highest_rise := 0.0
		for key_index in animation.track_get_key_count(root_track):
			var value := animation.track_get_key_value(root_track, key_index) as Vector2
			highest_rise = maxf(highest_rise, absf(value.y))
		_expect(highest_rise <= 1.5 + 0.01, "%s body rise stays within 1.5 px" % animation_name)
	for foot_path in [
		^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/Foot_L:position",
		^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/Foot_R:position",
	]:
		var foot_track := animation.find_track(foot_path, Animation.TYPE_VALUE)
		if foot_track < 0:
			continue
		var first_value: Variant = animation.track_get_key_value(foot_track, 0)
		for key_index in animation.track_get_key_count(foot_track):
			_expect(_variants_equal_approx(first_value, animation.track_get_key_value(foot_track, key_index)), "%s keeps %s fixed" % [animation_name, foot_path])


func _test_idle_foot_stability(
	rig: Node,
	animation_player: AnimationPlayer,
	animation_tree: AnimationTree
) -> void:
	var was_active := animation_tree.active
	animation_tree.active = false
	for facing in FACINGS:
		var animation_name := StringName("idle_%s" % facing)
		animation_player.play(animation_name)
		animation_player.seek(0.0, true)
		var left_foot := rig.get_node(^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/Foot_L") as Bone2D
		var right_foot := rig.get_node(^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/Foot_R") as Bone2D
		var left_origin := left_foot.global_position
		var right_origin := right_foot.global_position
		var left_drift := 0.0
		var right_drift := 0.0
		for phase in IDLE_PHASES:
			animation_player.seek(phase, true)
			left_drift = maxf(left_drift, left_foot.global_position.distance_to(left_origin))
			right_drift = maxf(right_drift, right_foot.global_position.distance_to(right_origin))
		_expect(left_drift <= 0.05, "%s keeps the left idle foot fixed" % animation_name)
		_expect(right_drift <= 0.05, "%s keeps the right idle foot fixed" % animation_name)
	animation_player.stop()
	animation_tree.active = was_active
	rig.call(&"reset_to_idle")


func _test_contact_foot_drift(
	rig: Node,
	animation_player: AnimationPlayer,
	animation_tree: AnimationTree
) -> void:
	var was_active := animation_tree.active
	animation_tree.active = false
	for facing in FACINGS:
		var animation_name := StringName("walk_%s" % facing)
		animation_player.play(animation_name)
		animation_player.seek(0.0, true)
		var left_foot := rig.get_node(^"FacingRoot/Skeleton2D/Root/Thigh_L/Shin_L/Foot_L") as Bone2D
		var right_foot := rig.get_node(^"FacingRoot/Skeleton2D/Root/Thigh_R/Shin_R/Foot_R") as Bone2D
		var left_contact_height := left_foot.global_position.y
		animation_player.seek(0.09, true)
		var left_down_height := left_foot.global_position.y
		animation_player.seek(0.36, true)
		var right_contact_height := right_foot.global_position.y
		animation_player.seek(0.45, true)
		var right_down_height := right_foot.global_position.y
		_expect(
			absf(left_down_height - left_contact_height) <= 1.5,
			"%s keeps the left contact foot planted through down" % animation_name
		)
		_expect(
			absf(right_down_height - right_contact_height) <= 1.5,
			"%s keeps the right contact foot planted through down" % animation_name
		)
	animation_player.stop()
	animation_tree.active = was_active
	rig.call(&"reset_to_idle")


func _test_direction_state_machine(machine: AnimationNodeStateMachine, prefix: String) -> void:
	for facing in FACINGS:
		var state_node := machine.get_node(facing) as AnimationNodeAnimation
		_expect(state_node != null, "%s state machine contains %s" % [prefix, facing])
		if state_node != null:
			_expect(state_node.animation == StringName("%s_%s" % [prefix, facing]), "%s/%s uses its authored clip" % [prefix, facing])

	_expect(machine.get_transition_count() == 12, "%s state machine has all directed facing transitions" % prefix)
	for transition_index in machine.get_transition_count():
		var transition := machine.get_transition(transition_index)
		_expect(transition.switch_mode == AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC, "%s transition %d synchronizes gait phase" % [prefix, transition_index])
		_expect(not transition.reset, "%s transition %d does not reset playback" % [prefix, transition_index])
		_expect(is_equal_approx(transition.xfade_time, 0.10), "%s transition %d crossfades over 0.10 seconds" % [prefix, transition_index])


func _test_public_behavior(rig: Node) -> void:
	for method_name in REQUIRED_METHODS:
		_expect(rig.has_method(method_name), "%s is exposed" % method_name)
	_expect(rig.has_signal(&"facing_changed"), "facing_changed signal exists")
	_expect(rig.has_signal(&"locomotion_changed"), "locomotion_changed signal exists")
	_expect(rig.call(&"get_facing") as StringName == &"front", "compact rig starts facing front")
	_expect(rig.call(&"get_locomotion_state") as StringName == &"idle", "compact rig starts idle")

	var facing_root := rig.get_node(^"FacingRoot") as Node2D
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		rig.call(&"set_motion", direction * 220.0)
		_expect(facing_root.scale.x > 0.0, "FacingRoot remains positive while facing %s" % direction)
	_expect(rig.call(&"get_facing") as StringName == &"side_right", "right movement selects side_right")
	_expect(rig.call(&"get_locomotion_state") as StringName == &"walk", "nonzero movement selects walk")
	rig.call(&"set_motion", Vector2.LEFT * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"side_left", "left movement selects authored side_left")
	_expect(facing_root.scale.x > 0.0, "left facing never mirrors FacingRoot")
	rig.call(&"set_motion", Vector2.UP * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"back", "up movement selects back")
	rig.call(&"set_motion", Vector2.DOWN * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"front", "down movement selects front")

	rig.call(&"set_motion", Vector2.RIGHT * 220.0)
	rig.call(&"set_motion", Vector2(1.0, 0.95).normalized() * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"side_right", "near-equal diagonal retains side family")
	rig.call(&"set_motion", Vector2.UP * 220.0)
	rig.call(&"set_motion", Vector2(0.95, -1.0).normalized() * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"back", "near-equal diagonal retains vertical family")
	rig.call(&"reset_to_idle")
	rig.call(&"set_motion", Vector2(-1.0, -1.0).normalized() * 220.0)
	_expect(rig.call(&"get_facing") as StringName == &"back", "initial upward tie selects back")
	rig.call(&"set_motion", Vector2.ZERO)
	_expect(rig.call(&"get_locomotion_state") as StringName == &"idle", "zero motion returns to idle")
	_expect(rig.call(&"get_facing") as StringName == &"back", "zero motion retains facing")

	var facing_before := rig.call(&"get_facing") as StringName
	_expect(not (rig.call(&"set_facing_direction", Vector2.ZERO) as bool), "near-zero explicit facing is rejected")
	_expect(rig.call(&"get_facing") as StringName == facing_before, "rejected facing does not change state")

	var animation_tree := rig.get_node(^"AnimationTree") as AnimationTree
	rig.call(&"set_playback_speed", 0.01)
	_expect(is_equal_approx(animation_tree.get(&"parameters/TimeScale/scale") as float, 0.25), "playback speed clamps to 0.25")
	rig.call(&"set_playback_speed", 9.0)
	_expect(is_equal_approx(animation_tree.get(&"parameters/TimeScale/scale") as float, 2.0), "playback speed clamps to 2.0")
	rig.call(&"set_playback_speed", 1.0)

	rig.call(&"set_debug_bones_visible", true)
	for indicator in rig.find_children("*", "Line2D", true, false):
		_expect((indicator as Line2D).visible, "%s can be shown" % rig.get_path_to(indicator))
	rig.call(&"set_debug_bones_visible", false)
	for indicator in rig.find_children("*", "Line2D", true, false):
		_expect(not (indicator as Line2D).visible, "%s can be hidden" % rig.get_path_to(indicator))

	var idle_playback := animation_tree.get(&"parameters/IdleDirection/playback") as AnimationNodeStateMachinePlayback
	var walk_playback := animation_tree.get(&"parameters/WalkDirection/playback") as AnimationNodeStateMachinePlayback
	rig.call(&"set_motion", Vector2.RIGHT * 220.0)
	await get_tree().create_timer(0.12).timeout
	_expect(idle_playback.get_current_node() == &"side_right", "idle machine tracks the authored right-facing state")
	_expect(walk_playback.get_current_node() == &"side_right", "walk machine tracks the authored right-facing state")
	rig.call(&"set_motion", Vector2.LEFT * 220.0)
	await get_tree().create_timer(0.12).timeout
	_expect(idle_playback.get_current_node() == &"side_left", "idle machine transitions to authored left-facing state")
	_expect(walk_playback.get_current_node() == &"side_left", "walk machine transitions to authored left-facing state")
	_expect(facing_root.scale.x > 0.0, "side reversal preserves authored anatomy without root mirroring")
	walk_playback.start(&"side_right")
	animation_tree.advance(0.0)
	animation_tree.advance(0.23)
	var phase_before_reversal := walk_playback.get_current_play_position()
	walk_playback.travel(&"side_left")
	animation_tree.advance(0.11)
	var phase_after_reversal := walk_playback.get_current_play_position()
	_expect(phase_before_reversal >= 0.20, "side reversal starts from an established gait phase")
	_expect(walk_playback.get_current_node() == &"side_left", "side reversal reaches the authored opposite state")
	_expect(phase_after_reversal >= 0.30, "side reversal preserves and advances the synchronized gait phase")


func _test_missing_dependency_handling() -> void:
	var rig_script := load(RIG_SCRIPT_PATH) as Script
	_expect(rig_script != null, "compact rig controller parses")
	if rig_script == null:
		return
	var incomplete_rig := Node2D.new()
	incomplete_rig.set_script(rig_script)
	_expect(not (incomplete_rig.call(&"_validate_dependencies", false) as bool), "incomplete rigs are detected")
	incomplete_rig.call(&"set_motion", Vector2.RIGHT * 220.0)
	_expect(incomplete_rig.call(&"get_locomotion_state") as StringName == &"idle", "incomplete rigs keep playback disabled")
	incomplete_rig.free()


func _test_comparison_lab() -> void:
	var lab_scene := load(COMPARISON_LAB_PATH) as PackedScene
	_expect(lab_scene != null, "comparison lab exists and parses")
	if lab_scene == null:
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var lab := lab_scene.instantiate()
	viewport.add_child(lab)
	await get_tree().process_frame

	var movers := lab.find_children("*", "CharacterBody2D", true, false)
	_expect(movers.size() == 1, "comparison lab contains one shared mover")
	var mover := lab.get_node_or_null(^"ComparisonMover") as CharacterBody2D
	_expect(mover != null, "shared mover uses the stable ComparisonMover path")
	if mover != null:
		var original_mount := mover.get_node_or_null(^"OriginalRigMount") as Node2D
		var compact_mount := mover.get_node_or_null(^"CompactRigMount") as Node2D
		_expect(original_mount != null and is_equal_approx(original_mount.position.x, -140.0), "original rig mount uses -140 px offset")
		_expect(compact_mount != null and is_equal_approx(compact_mount.position.x, 140.0), "compact rig mount uses +140 px offset")
		if original_mount != null:
			_expect(original_mount.scale.is_equal_approx(Vector2.ONE), "original rig remains at native scale")
		if compact_mount != null:
			_expect(compact_mount.scale.is_equal_approx(Vector2.ONE), "compact rig remains at native scale")
		_expect(mover.find_children("*", "CollisionShape2D", false, false).size() == 2, "shared mover has two direct collision shapes")

	var camera := lab.get_node_or_null(^"ComparisonMover/Camera2D") as Camera2D
	_expect(camera != null and camera.enabled, "comparison camera follows the shared mover")
	if camera != null:
		_expect(not camera.position_smoothing_enabled, "comparison camera has no smoothing")
		_expect(camera.limit_left == 0 and camera.limit_top == 0, "comparison camera uses top-left room limits")
		_expect(camera.limit_right == 3200 and camera.limit_bottom == 1800, "comparison camera uses bottom-right room limits")
	_expect(lab.get_node_or_null(^"ComparisonMover/OriginalRigMount/OriginalLabel") is Label, "original rig has a world label")
	_expect(lab.get_node_or_null(^"ComparisonMover/CompactRigMount/CompactLabel") is Label, "compact rig has a world label")
	_expect(lab.get_node_or_null(^"HUD/StatusPanel/StatusRow/LocomotionValue") is Label, "comparison HUD shows shared locomotion")
	_expect(lab.get_node_or_null(^"HUD/StatusPanel/StatusRow/FacingValue") is Label, "comparison HUD shows shared facing")
	_expect(lab.find_children("*", "Button", true, false).is_empty(), "comparison lab has no toolbar buttons")
	_expect(lab.find_children("*", "Range", true, false).is_empty(), "comparison lab has no sliders")

	lab.queue_free()
	viewport.queue_free()
	await get_tree().process_frame


func _calculate_visual_bounds(facing_root: Node2D, visuals: Array[Polygon2D]) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for visual in visuals:
		for point in visual.polygon:
			var local_point := facing_root.to_local(visual.to_global(point))
			minimum.x = minf(minimum.x, local_point.x)
			minimum.y = minf(minimum.y, local_point.y)
			maximum.x = maxf(maximum.x, local_point.x)
			maximum.y = maxf(maximum.y, local_point.y)
	return Rect2(minimum, maximum - minimum)


func _track_contains_phases(animation: Animation, track_index: int, phases: Array[float]) -> bool:
	var key_times: Array[float] = []
	for key_index in animation.track_get_key_count(track_index):
		key_times.append(animation.track_get_key_time(track_index, key_index))
	for phase in phases:
		if not _contains_approx(key_times, phase):
			return false
	return true


func _contains_approx(values: Array[float], expected: float) -> bool:
	for value in values:
		if is_equal_approx(value, expected):
			return true
	return false


func _variants_equal_approx(first: Variant, second: Variant) -> bool:
	if typeof(first) != typeof(second):
		return false
	match typeof(first):
		TYPE_FLOAT:
			return is_equal_approx(float(first), float(second))
		TYPE_VECTOR2:
			return (first as Vector2).is_equal_approx(second as Vector2)
		_:
			return first == second


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
