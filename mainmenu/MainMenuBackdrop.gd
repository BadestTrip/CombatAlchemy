class_name MainMenuBackdrop
extends Control

# Responsibility: Apply editor-facing speed and glow tuning to the authored
# ambient layers of the main-menu laboratory.

## Far cloud movement in native pixels per second.
@export_range(0.0, 32.0, 0.25) var far_cloud_speed: float = 4.0
## Near cloud movement in native pixels per second.
@export_range(0.0, 32.0, 0.25) var near_cloud_speed: float = 8.0
## Playback multiplier shared by foliage and pinned-note motion.
@export_range(0.25, 2.0, 0.05) var wind_speed_multiplier: float = 1.0
## Intensity multiplier for the six reactive crystal deposits.
@export_range(0.0, 1.5, 0.05) var reagent_glow_strength: float = 1.0

@onready var _far_clouds: LoopingPixelLayer = get_node_or_null("CloudWindow/FarClouds") as LoopingPixelLayer
@onready var _near_clouds: LoopingPixelLayer = get_node_or_null("CloudWindow/NearClouds") as LoopingPixelLayer
@onready var _foliage: Node2D = get_node_or_null("Foliage") as Node2D
@onready var _notes: Node2D = get_node_or_null("Notes") as Node2D
@onready var _reagent_lights: Node2D = get_node_or_null("ReagentLights") as Node2D
@onready var _ambient_animation: AnimationPlayer = get_node_or_null("AmbientAnimation") as AnimationPlayer


func _ready() -> void:
	if not _validate_dependencies():
		return
	_apply_editor_tuning()


## Reapplies exported values after editor or runtime tuning.
func apply_tuning() -> void:
	_apply_editor_tuning()


func _apply_editor_tuning() -> void:
	if _far_clouds != null:
		_far_clouds.speed_pixels_per_second = far_cloud_speed
	if _near_clouds != null:
		_near_clouds.speed_pixels_per_second = near_cloud_speed
	_set_container_speed(_foliage, wind_speed_multiplier)
	_set_container_speed(_notes, wind_speed_multiplier)
	if _ambient_animation != null:
		_ambient_animation.speed_scale = wind_speed_multiplier
	if _reagent_lights != null:
		for child in _reagent_lights.get_children():
			if child.has_method(&"set_glow_strength"):
				child.call(&"set_glow_strength", reagent_glow_strength)


func _set_container_speed(container: Node, multiplier: float) -> void:
	if container == null:
		return
	for child in container.get_children():
		var animated := child as AnimatedSprite2D
		if animated != null:
			animated.speed_scale = multiplier


func _validate_dependencies() -> bool:
	if (
		_far_clouds == null
		or _near_clouds == null
		or _foliage == null
		or _notes == null
		or _reagent_lights == null
		or _ambient_animation == null
	):
		push_error("MainMenuBackdrop is missing an authored ambient layer.")
		return false
	return true
