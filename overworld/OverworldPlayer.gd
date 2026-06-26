extends CharacterBody2D
class_name OverworldPlayer


# This tiny prototype player only moves on a flat 2D training-ground screen.
# Future overworld work can replace this with animation, collision maps, or a
# camera without changing the duel-start flow.
@export var move_speed: float = 260.0
@export var walk_bounds_min: Vector2 = Vector2(120.0, 150.0)
@export var walk_bounds_max: Vector2 = Vector2(1800.0, 900.0)
@export var dust_trail_offset_distance: float = 50.0

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

	velocity = direction * move_speed
	move_and_slide()

	# Keep the prototype player inside the visible walkable area.
	position.x = clampf(position.x, walk_bounds_min.x, walk_bounds_max.x)
	position.y = clampf(position.y, walk_bounds_min.y, walk_bounds_max.y)

	var moved_this_frame := position.distance_squared_to(previous_position) > 0.01
	_update_dust_trail(direction, moved_this_frame)


func _update_dust_trail(direction: Vector2, is_moving: bool) -> void:
	if dust_trail == null:
		return

	# Tune DustTrail's amount, lifetime, color, and scale in the scene to adjust
	# the pixie-dust feel without changing movement code.
	dust_trail.emitting = is_moving
	if is_moving and direction.length_squared() > 0.0:
		dust_trail.position = -direction.normalized() * dust_trail_offset_distance
