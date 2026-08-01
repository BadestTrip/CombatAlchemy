extends Node

# Responsibility: Verify researcher facing changes do not reverse authored hand anatomy.

const RESEARCHER_RIG_SCENE := preload(
	"res://characters/animation/ResearcherCutoutRig.tscn"
)
const LEFT_HAND_ART_PATH := (
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_L/Forearm_L/Hand_L/HandArt"
)
const RIGHT_HAND_ART_PATH := (
	^"FacingRoot/Skeleton2D/Root/Spine/UpperArm_R/Forearm_R/Hand_R/HandArt"
)

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_test()
	if _failures.is_empty():
		print("ResearcherMirroringTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("ResearcherMirroringTests: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _run_test() -> void:
	var rig := RESEARCHER_RIG_SCENE.instantiate()
	add_child(rig)
	await get_tree().process_frame

	var facing_root := rig.get_node_or_null(^"FacingRoot") as Node2D
	var left_hand_art := rig.get_node_or_null(LEFT_HAND_ART_PATH) as Sprite2D
	var right_hand_art := rig.get_node_or_null(RIGHT_HAND_ART_PATH) as Sprite2D
	var left_socket_before := rig.call(&"get_socket", &"hand_left") as Marker2D
	var right_socket_before := rig.call(&"get_socket", &"hand_right") as Marker2D
	_expect(facing_root != null, "researcher rig exposes FacingRoot")
	_expect(left_hand_art != null, "researcher rig exposes authored left-hand art")
	_expect(right_hand_art != null, "researcher rig exposes authored right-hand art")
	if facing_root == null or left_hand_art == null or right_hand_art == null:
		rig.queue_free()
		return

	var left_orientation_before := signf(left_hand_art.global_transform.determinant())
	var right_orientation_before := signf(right_hand_art.global_transform.determinant())
	rig.call(&"set_mirrored", true)

	_expect(facing_root.scale.x < 0.0, "left-facing pose still mirrors FacingRoot")
	_expect(
		signf(left_hand_art.global_transform.determinant()) == left_orientation_before,
		"left-hand atlas keeps its authored chirality while facing left"
	)
	_expect(
		signf(right_hand_art.global_transform.determinant()) == right_orientation_before,
		"right-hand atlas keeps its authored chirality while facing left"
	)
	_expect(
		rig.call(&"get_socket", &"hand_left") == left_socket_before,
		"left-hand socket identity remains stable"
	)
	_expect(
		rig.call(&"get_socket", &"hand_right") == right_socket_before,
		"right-hand socket identity remains stable"
	)

	rig.call(&"set_mirrored", false)
	_expect(facing_root.scale.x > 0.0, "right-facing pose restores FacingRoot")
	_expect(
		signf(left_hand_art.global_transform.determinant()) == left_orientation_before,
		"left-hand atlas restores its original orientation"
	)
	_expect(
		signf(right_hand_art.global_transform.determinant()) == right_orientation_before,
		"right-hand atlas restores its original orientation"
	)
	rig.queue_free()


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
