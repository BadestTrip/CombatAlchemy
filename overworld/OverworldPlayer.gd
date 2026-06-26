extends CharacterBody2D
class_name OverworldPlayer


# This tiny prototype player only moves on a flat 2D training-ground screen.
# Future overworld work can replace this with animation, collision maps, or a
# camera without changing the duel-start flow.
@export var move_speed: float = 260.0
@export var walk_bounds_min: Vector2 = Vector2(120.0, 150.0)
@export var walk_bounds_max: Vector2 = Vector2(1800.0, 900.0)
@export var dust_trail_offset_distance: float = 50.0
@export var walk_tilt_degrees: float = 5.0
@export var walk_tilt_speed: float = 11.0
@export var walk_tilt_return_speed: float = 12.0

@onready var character_sprite: Control = get_node_or_null("CharacterOverworldSprite") as Control
@onready var dust_trail: CPUParticles2D = get_node_or_null("DustTrail") as CPUParticles2D

var _base_sprite_scale: Vector2 = Vector2.ONE
var _last_horizontal_facing: float = -1.0


func _ready() -> void:
	add_to_group("overworld_player")
	_prepare_character_sprite()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var previous_position := position

	velocity = direction * move_speed
	move_and_slide()

	# Keep the prototype player inside the visible walkable area.
	position.x = clampf(position.x, walk_bounds_min.x, walk_bounds_max.x)
	position.y = clampf(position.y, walk_bounds_min.y, walk_bounds_max.y)

	var moved_this_frame := position.distance_squared_to(previous_position) > 0.01
	_update_character_sprite(direction, moved_this_frame, delta)
	_update_dust_trail(direction, moved_this_frame)


func _prepare_character_sprite() -> void:
	if character_sprite == null:
		return
	_base_sprite_scale = character_sprite.scale
	# TextureRect does not support flip_h, so scale flips should happen around
	# the visual center to avoid a small sideways jump.
	character_sprite.pivot_offset = character_sprite.size * 0.5


func _update_dust_trail(direction: Vector2, is_moving: bool) -> void:
	if dust_trail == null:
		return

	# Tune DustTrail's amount, lifetime, color, and scale in the scene to adjust
	# the pixie-dust feel without changing movement code.
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
	# The source art faces left. Negative scale mirrors it to face right.
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
