extends CharacterBody2D
class_name TestPlayer


# Standalone movement controller for the mechanics playground. It intentionally
# does not read or write campaign state, so experiments can freely diverge from
# the overworld player.
@export var move_speed: float = 260.0
@export var walk_bounds_min: Vector2 = Vector2(124.0, 120.0)
@export var walk_bounds_max: Vector2 = Vector2(1796.0, 960.0)
@export var dust_trail_offset_distance: float = 50.0
@export var walk_tilt_degrees: float = 5.0
@export var walk_tilt_speed: float = 11.0
@export var walk_tilt_return_speed: float = 12.0

@onready var character_sprite: Control = get_node_or_null("CharacterSprite") as Control
@onready var dust_trail: CPUParticles2D = get_node_or_null("DustTrail") as CPUParticles2D

var _base_sprite_scale: Vector2 = Vector2.ONE
var _last_horizontal_facing: float = -1.0


func _ready() -> void:
	_prepare_character_sprite()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var previous_position := position

	# Input.get_vector limits the vector length to one, keeping diagonal and
	# cardinal movement at the same speed.
	velocity = direction * move_speed
	move_and_slide()

	position.x = clampf(position.x, walk_bounds_min.x, walk_bounds_max.x)
	position.y = clampf(position.y, walk_bounds_min.y, walk_bounds_max.y)

	var moved_this_frame := position.distance_squared_to(previous_position) > 0.01
	_update_character_sprite(direction, moved_this_frame, delta)
	_update_dust_trail(direction, moved_this_frame)


func _prepare_character_sprite() -> void:
	if character_sprite == null:
		return
	_base_sprite_scale = character_sprite.scale
	character_sprite.pivot_offset = character_sprite.size * 0.5


func _update_dust_trail(direction: Vector2, is_moving: bool) -> void:
	if dust_trail == null:
		return

	dust_trail.emitting = is_moving
	if is_moving and direction.length_squared() > 0.0:
		dust_trail.position = -direction.normalized() * dust_trail_offset_distance


func _update_character_sprite(
	direction: Vector2,
	is_moving: bool,
	delta: float
) -> void:
	if character_sprite == null:
		return

	character_sprite.pivot_offset = character_sprite.size * 0.5
	if absf(direction.x) > 0.01:
		_last_horizontal_facing = 1.0 if direction.x > 0.0 else -1.0

	var facing_scale_x := absf(_base_sprite_scale.x)
	# The source art faces left, so a negative X scale faces it right.
	character_sprite.scale.x = -facing_scale_x if _last_horizontal_facing > 0.0 else facing_scale_x
	character_sprite.scale.y = _base_sprite_scale.y

	var target_rotation := 0.0
	if is_moving:
		var walk_time := Time.get_ticks_msec() * 0.001 * walk_tilt_speed
		target_rotation = sin(walk_time) * walk_tilt_degrees

	var blend := clampf(delta * walk_tilt_return_speed, 0.0, 1.0)
	character_sprite.rotation_degrees = lerpf(
		character_sprite.rotation_degrees,
		target_rotation,
		blend
	)
