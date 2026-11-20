extends Node2D

## Sprite locomotion facade shared by combat and the model workshop.
## Gameplay resolves stable hand markers without depending on presentation internals.
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
const REQUIRED_FACINGS: Array[StringName] = [FACING_FRONT,FACING_BACK,FACING_SIDE_LEFT,FACING_SIDE_RIGHT]
const MOTION_EPSILON_SQUARED := 0.0001
const DIRECTION_HYSTERESIS := 0.10
const MIN_PLAYBACK_SPEED := 0.25
const MAX_PLAYBACK_SPEED := 2.0

@export var sprite_data: PlayerSpriteData
@onready var _facing_root := get_node_or_null("FacingRoot") as Node2D
@onready var _sprite := get_node_or_null("FacingRoot/Sprite") as AnimatedSprite2D
@onready var _left := get_node_or_null("FacingRoot/HandSocket_L") as Marker2D
@onready var _right := get_node_or_null("FacingRoot/HandSocket_R") as Marker2D
@onready var _guides := get_node_or_null("FacingRoot/DebugGuides") as Node2D
var _facing := FACING_FRONT
var _facing_family := FAMILY_VERTICAL
var _locomotion_state := LOCOMOTION_IDLE
var _is_operational := false

func _ready() -> void:
	set_debug_guides_visible(false)
	if not _validate_dependencies(true):
		if _sprite != null: _sprite.stop()
		return
	_sprite.sprite_frames = sprite_data.sprite_frames
	_sprite.centered = false
	_sprite.offset = -sprite_data.pivot
	_sprite.frame_changed.connect(_sync_frame)
	_sprite.animation_changed.connect(_sync_frame)
	_is_operational = true
	_play_current(false)

func set_motion(velocity: Vector2) -> void:
	if not _is_operational: return
	if velocity.length_squared() <= MOTION_EPSILON_SQUARED:
		_set_locomotion_state(LOCOMOTION_IDLE)
		return
	_set_locomotion_state(LOCOMOTION_WALK)
	_set_facing_from_direction(velocity.normalized())

func set_facing_direction(direction: Vector2) -> bool:
	if not _is_operational or direction.length_squared() <= MOTION_EPSILON_SQUARED: return false
	_set_facing_from_direction(direction.normalized())
	return true

func reset_to_idle() -> void:
	if not _is_operational: return
	var old_facing := _facing
	var old_state := _locomotion_state
	_facing = FACING_FRONT
	_facing_family = FAMILY_VERTICAL
	_locomotion_state = LOCOMOTION_IDLE
	_play_current(false)
	if old_facing != _facing: facing_changed.emit(_facing)
	if old_state != _locomotion_state: locomotion_changed.emit(_locomotion_state)

func set_playback_speed(multiplier: float) -> void:
	if _sprite != null:
		_sprite.speed_scale = clampf(multiplier, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)

func set_debug_guides_visible(show_guides: bool) -> void:
	if _guides != null: _guides.visible = show_guides

## Compatibility alias for existing callers.
func set_debug_bones_visible(show_bones: bool) -> void:
	set_debug_guides_visible(show_bones)

func get_facing() -> StringName:
	return _facing

func get_locomotion_state() -> StringName:
	return _locomotion_state

func get_socket(socket_id: StringName) -> Marker2D:
	match socket_id:
		&"hand_left": return _left
		&"hand_right": return _right
		_: return null

func _set_facing_from_direction(direction: Vector2) -> void:
	var family := _facing_family
	if absf(direction.x) > absf(direction.y) + DIRECTION_HYSTERESIS: family = FAMILY_SIDE
	elif absf(direction.y) > absf(direction.x) + DIRECTION_HYSTERESIS: family = FAMILY_VERTICAL
	var facing: StringName
	if family == FAMILY_SIDE: facing = FACING_SIDE_LEFT if direction.x < 0 else FACING_SIDE_RIGHT
	else: facing = FACING_FRONT if direction.y > 0 else FACING_BACK
	_facing_family = family
	if facing == _facing: return
	_facing = facing
	_play_current(true)
	facing_changed.emit(_facing)

func _set_locomotion_state(state: StringName) -> void:
	if state == _locomotion_state: return
	_locomotion_state = state
	_play_current(false)
	locomotion_changed.emit(state)

func _play_current(preserve_phase: bool) -> void:
	var frame := _sprite.frame if preserve_phase else 0
	var progress := _sprite.frame_progress if preserve_phase else 0.0
	_facing_root.scale = _facing_root.scale.abs()
	_sprite.flip_h = false
	_sprite.flip_v = false
	_sprite.play(StringName("%s_%s" % [_locomotion_state, _facing]))
	_sprite.set_frame_and_progress(frame,progress)
	_sync_frame()

func _sync_frame() -> void:
	if not _is_operational: return
	var frames: Array = sprite_data.frame_sockets.get(_sprite.animation, [])
	if _sprite.frame >= frames.size(): return
	var data: Dictionary = frames[_sprite.frame]
	_left.position = ((data["hand_left"] as Vector2) - sprite_data.pivot) * _sprite.scale
	_right.position = ((data["hand_right"] as Vector2) - sprite_data.pivot) * _sprite.scale
	_left.z_index = int(data["left_z"])
	_right.z_index = int(data["right_z"])
	if _guides != null:
		(_guides.get_node("LeftHand") as Node2D).position = _left.position
		(_guides.get_node("RightHand") as Node2D).position = _right.position

func _validate_dependencies(report_errors: bool) -> bool:
	var problems: Array[String] = []
	if _facing_root == null or _sprite == null: problems.append("FacingRoot/Sprite")
	if _left == null or _right == null: problems.append("hand markers")
	if sprite_data == null or sprite_data.sprite_frames == null:
		problems.append("sprite data")
	else:
		for facing in REQUIRED_FACINGS:
			for state in [LOCOMOTION_IDLE,LOCOMOTION_WALK]:
				var animation := StringName("%s_%s" % [state,facing])
				var count := 2 if state == LOCOMOTION_IDLE else 4
				if not sprite_data.sprite_frames.has_animation(animation) or sprite_data.sprite_frames.get_frame_count(animation) != count:
					problems.append(String(animation))
				var sockets: Array = sprite_data.frame_sockets.get(animation, [])
				if sockets.size() != count:
					problems.append("sockets/%s" % animation)
					continue
				for entry: Dictionary in sockets:
					if not (entry.get("hand_left") is Vector2 and entry.get("hand_right") is Vector2 and entry.has("left_z") and entry.has("right_z")):
						problems.append("socket fields/%s" % animation)
	if not problems.is_empty() and report_errors:
		push_error("PlayerModel requires: %s" % ", ".join(problems))
	return problems.is_empty()
