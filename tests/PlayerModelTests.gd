extends Node

const MODEL_SCENE := preload("res://characters/player/PlayerModel.tscn")
const ENTITY_SCENE := preload("res://combat/potions/PotionEntity.tscn")
const FACINGS: Array[StringName] = [&"front", &"back", &"side_left", &"side_right"]
const DIRECTIONS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
var _failures: Array[String] = []
var _check_count := 0

func _ready() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("PlayerModelTests: PASS (%d checks)" % _check_count)
	else:
		for failure in _failures: push_error(failure)
		print("PlayerModelTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _run_tests() -> void:
	var model := MODEL_SCENE.instantiate() as Node2D
	add_child(model)
	await get_tree().process_frame
	var sprite := model.get_node_or_null("FacingRoot/Sprite") as AnimatedSprite2D
	_expect(sprite != null, "canonical model uses the new animated sprite sheet")
	if sprite == null:
		model.queue_free()
		return
	_expect(model.find_children("*", "Skeleton2D", true, false).is_empty(), "active model has no retired skeleton")
	_expect(sprite.scale == Vector2(2, 2), "source pixels display at integer 2x scale")
	_expect(not sprite.centered and sprite.offset == Vector2(-32,-74), "sprite uses metadata ground pivot")
	var facing_root := model.get_node("FacingRoot") as Node2D
	_expect(facing_root.position == Vector2(0,38), "sprite feet retain old model ground level")
	var left := model.call("get_socket", &"hand_left") as Marker2D
	var right := model.call("get_socket", &"hand_right") as Marker2D
	_expect(left != null and right != null and left != right, "stable anatomical hand markers exist")
	_expect(model.call("get_socket", &"unknown") == null, "unknown socket returns null")
	var entity := ENTITY_SCENE.instantiate() as PotionEntity
	add_child(entity)
	entity.initialize(PotionInstance.create(load("res://combat/potions/resources/DamagePotion.tres"), [PotionReagent.GREEN,PotionReagent.GREEN,PotionReagent.BLUE]), self)
	_expect(entity.attach_to(right), "physical bottle attaches to stable right hand")
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sprites/characters/researcher_01/researcher_01_v001.json"))
	var records: Array = metadata["frames"]
	for facing_index in FACINGS.size():
		var facing := FACINGS[facing_index]
		for state in [&"idle", &"walk"]:
			model.call("set_motion", DIRECTIONS[facing_index] if state == &"walk" else Vector2.ZERO)
			model.call("set_facing_direction", DIRECTIONS[facing_index])
			sprite.pause()
			var animation := StringName("%s_%s" % [state,facing])
			_expect(sprite.animation == animation, "public API selects %s" % animation)
			var count := 2 if state == &"idle" else 4
			_expect(sprite.sprite_frames.get_frame_count(animation) == count, "frame count matches %s" % animation)
			_expect(is_equal_approx(count / sprite.sprite_frames.get_animation_speed(animation), 1.6 if state == &"idle" else 0.72), "duration matches %s" % animation)
			for frame in count:
				sprite.set_frame_and_progress(frame, 0.0)
				var record: Dictionary = records[facing_index*6 + frame + (0 if state == &"idle" else 2)]
				for hand in ["hand_left","hand_right"]:
					var marker := model.call("get_socket", StringName(hand)) as Marker2D
					var xy: Array = record[hand]
					var expected := (Vector2(xy[0],xy[1])-Vector2(32,74))*2.0
					_expect(marker.position == expected, "%s %d %s follows native-frame metadata" % [animation,frame,hand])
					_expect(marker.z_index == int(record["hand_draw_order"][hand]), "held item depth matches anatomical facing")
				_expect(entity.global_position.is_equal_approx(right.global_position), "same held bottle follows every frame")
				_expect((entity.get_node("Outline") as Sprite2D).global_scale == Vector2(2,2), "bottle does not inherit character's visual scale")
				_expect(sprite.scale.x > 0 and not sprite.flip_h and facing_root.scale.x > 0, "facings never mirror")
	_expect(model.call("get_socket", &"hand_right") == right, "turns do not replace hand sockets")
	model.call("reset_to_idle")
	_expect(model.call("get_facing") == &"front" and model.call("get_locomotion_state") == &"idle", "reset selects front idle")
	_expect(not model.call("set_facing_direction", Vector2.ZERO), "zero facing is rejected")
	model.call("set_motion", Vector2.RIGHT)
	model.call("set_facing_direction", Vector2(1,1))
	_expect(model.call("get_facing") == &"side_right", "diagonal retains current family")
	model.call("set_facing_direction", Vector2(0.5,1))
	_expect(model.call("get_facing") == &"front", "dominant vertical direction crosses hysteresis")
	sprite.set_frame_and_progress(2,0.375)
	model.call("set_facing_direction", Vector2.LEFT)
	_expect(sprite.frame == 2 and is_equal_approx(sprite.frame_progress,0.375), "direction changes preserve gait phase")
	model.call("set_motion", Vector2.ZERO)
	_expect(model.call("get_facing") == &"side_left" and sprite.animation == &"idle_side_left", "stopping retains facing")
	model.call("set_playback_speed",0.01)
	_expect(is_equal_approx(sprite.speed_scale,0.25), "playback clamps at minimum")
	model.call("set_playback_speed",9.0)
	_expect(is_equal_approx(sprite.speed_scale,2.0), "playback clamps at maximum")
	var events: Array[StringName] = []
	model.connect("facing_changed", func(f: StringName) -> void: events.append(f))
	model.call("set_facing_direction",Vector2.UP)
	model.call("set_facing_direction",Vector2.UP)
	_expect(events == [&"back"], "facing signal emits only on actual changes")
	model.call("set_debug_guides_visible",true)
	_expect(model.get_node("FacingRoot/DebugGuides").visible, "new guide API shows frame and socket guides")
	model.call("set_debug_bones_visible",false)
	_expect(not model.get_node("FacingRoot/DebugGuides").visible, "old debug API remains a working alias")
	entity.queue_free()
	model.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition: _failures.append(message)
