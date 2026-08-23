extends Node

# Responsibility: Verify the isolated PlayerModel workshop composition and controls.

const WORKSHOP_PATH := "res://characters/player/PlayerModelWorkshop.tscn"
const PROJECT_PATH := "res://project.godot"

var _failures: Array[String] = []
var _check_count := 0


func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("PlayerModelWorkshopTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("PlayerModelWorkshopTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _run_tests() -> void:
	_expect(FileAccess.file_exists(WORKSHOP_PATH), "workshop scene exists")
	if not FileAccess.file_exists(WORKSHOP_PATH):
		return

	var workshop_scene := load(WORKSHOP_PATH) as PackedScene
	_expect(workshop_scene != null, "workshop scene parses")
	if workshop_scene == null:
		return

	var workshop := workshop_scene.instantiate()
	_expect(workshop != null, "workshop instantiates")
	if workshop == null:
		return

	var actor := workshop.get_node_or_null(^"WorkshopActor") as CharacterBody2D
	var model := workshop.get_node_or_null(^"WorkshopActor/PlayerModel")
	var camera := workshop.get_node_or_null(^"WorkshopActor/Camera2D") as Camera2D
	var collision := workshop.get_node_or_null(^"WorkshopActor/CollisionShape2D") as CollisionShape2D
	var facing_label := workshop.get_node_or_null(^"HUD/StatusPanel/StatusRow/FacingValue") as Label
	var locomotion_label := workshop.get_node_or_null(^"HUD/StatusPanel/StatusRow/LocomotionValue") as Label
	var bones_toggle := workshop.get_node_or_null(^"HUD/StatusPanel/StatusRow/BonesToggle") as CheckButton

	_expect(actor != null, "workshop has one movement owner")
	_expect(
		model != null and model.scene_file_path == "res://characters/player/PlayerModel.tscn",
		"workshop instances the canonical model"
	)
	_expect(camera != null and not camera.position_smoothing_enabled, "workshop camera follows without smoothing")
	_expect(collision != null, "workshop actor has one gameplay-sized collision")
	_expect(
		facing_label != null and locomotion_label != null and bones_toggle != null,
		"workshop exposes only compact state controls"
	)

	var movement_owners := workshop.find_children("*", "CharacterBody2D", true, false)
	_expect(movement_owners.size() == 1, "workshop contains exactly one CharacterBody2D")
	_test_room(workshop, camera)
	_test_actor_collision(collision)
	_expect(workshop.find_child("PlayerActor", true, false) == null, "workshop does not contain PlayerActor")
	_expect(not _contains_potion_node(workshop), "workshop contains no potion nodes")
	var project_text := FileAccess.get_file_as_string(PROJECT_PATH)
	_expect(project_text.find(WORKSHOP_PATH) == -1, "project.godot does not register the workshop")

	add_child(workshop)
	await get_tree().process_frame
	_test_state_controls(model, facing_label, locomotion_label, bones_toggle)
	workshop.queue_free()
	await get_tree().process_frame


func _test_room(workshop: Node, camera: Camera2D) -> void:
	var floor := workshop.get_node_or_null(^"RoomFloor") as Polygon2D
	var border := workshop.get_node_or_null(^"RoomBorder") as Line2D
	var walls := workshop.get_node_or_null(^"Walls")
	_expect(floor != null and border != null and walls != null, "workshop authors one bounded room")
	if walls != null:
		var wall_bodies := walls.find_children("*", "StaticBody2D", true, false)
		_expect(wall_bodies.size() == 4, "workshop has four wall bodies")
	for wall_name in [&"NorthWall", &"SouthWall", &"WestWall", &"EastWall"]:
		_expect(
			walls != null and walls.get_node_or_null(NodePath(String(wall_name))) is StaticBody2D,
			"workshop has %s" % wall_name
		)
	if camera != null:
		_expect(
			camera.limit_left == 0
			and camera.limit_top == 0
			and camera.limit_right == 3200
			and camera.limit_bottom == 1800,
			"workshop camera limits match the 3200x1800 room"
		)


func _test_actor_collision(collision: CollisionShape2D) -> void:
	if collision == null:
		return
	var capsule := collision.shape as CapsuleShape2D
	_expect(capsule != null, "workshop actor collision uses a capsule")
	if capsule == null:
		return
	_expect(is_equal_approx(capsule.radius, 31.0), "workshop capsule radius is 31")
	_expect(is_equal_approx(capsule.height, 120.0), "workshop capsule height is 120")
	_expect(collision.position.is_equal_approx(Vector2(0.0, -22.0)), "workshop collision is aligned to the model")


func _test_state_controls(
	model: Node,
	facing_label: Label,
	locomotion_label: Label,
	bones_toggle: CheckButton
) -> void:
	if model == null or facing_label == null or locomotion_label == null or bones_toggle == null:
		return
	_expect(not bones_toggle.button_pressed, "bone indicators start disabled")
	_expect(_bone_lines_have_visibility(model, false), "bone indicators start hidden")
	_expect(facing_label.text == "FRONT", "facing label initializes from the model")
	_expect(locomotion_label.text == "IDLE", "locomotion label initializes from the model")

	model.call(&"set_motion", Vector2.RIGHT * 220.0)
	_expect(facing_label.text == "SIDE_RIGHT", "facing signal updates the workshop label")
	_expect(locomotion_label.text == "WALK", "locomotion signal updates the workshop label")

	bones_toggle.set_pressed_no_signal(true)
	bones_toggle.toggled.emit(true)
	_expect(_bone_lines_have_visibility(model, true), "the CheckButton shows bone indicators")
	bones_toggle.set_pressed_no_signal(false)
	bones_toggle.toggled.emit(false)
	_expect(_bone_lines_have_visibility(model, false), "the CheckButton hides bone indicators")


func _bone_lines_have_visibility(model: Node, expected: bool) -> bool:
	var indicators := model.find_children("*", "Line2D", true, false)
	if indicators.is_empty():
		return false
	for indicator in indicators:
		if (indicator as Line2D).visible != expected:
			return false
	return true


func _contains_potion_node(root: Node) -> bool:
	for candidate in root.find_children("*", "", true, false):
		if String(candidate.name).to_lower().contains("potion"):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
