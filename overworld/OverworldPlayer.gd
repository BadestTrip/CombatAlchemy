extends CharacterBody2D
class_name OverworldPlayer


# This tiny prototype player only moves on a flat 2D training-ground screen.
# Future overworld work can replace this with animation, collision maps, or a
# camera without changing the duel-start flow.
const MOVE_SPEED: float = 260.0
const WALK_BOUNDS_MIN: Vector2 = Vector2(120.0, 150.0)
const WALK_BOUNDS_MAX: Vector2 = Vector2(1800.0, 900.0)
const DUST_TRAIL_OFFSET_DISTANCE: float = 50.0

@onready var dust_trail: CPUParticles2D = get_node_or_null("DustTrail") as CPUParticles2D


func _ready() -> void:
	add_to_group("overworld_player")


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var previous_position := position

	velocity = direction * MOVE_SPEED
	move_and_slide()

	# Keep the prototype player inside the visible walkable area.
	position.x = clampf(position.x, WALK_BOUNDS_MIN.x, WALK_BOUNDS_MAX.x)
	position.y = clampf(position.y, WALK_BOUNDS_MIN.y, WALK_BOUNDS_MAX.y)

	var moved_this_frame := position.distance_squared_to(previous_position) > 0.01
	_update_dust_trail(direction, moved_this_frame)


func _update_dust_trail(direction: Vector2, is_moving: bool) -> void:
	if dust_trail == null:
		return

	# Tune DustTrail's amount, lifetime, color, and scale in the scene to adjust
	# the pixie-dust feel without changing movement code.
	dust_trail.emitting = is_moving
	if is_moving and direction.length_squared() > 0.0:
		dust_trail.position = -direction.normalized() * DUST_TRAIL_OFFSET_DISTANCE
