extends Area2D
class_name TestDummy


signal dummy_hit(damage: int, current_health: int)
signal dummy_depleted
signal health_changed(current_health: int, max_health: int)

@export var max_health: int = 100
@export var click_damage: int = 10
@export var click_knockback_pixels: float = 18.0
@export var depleted_reset_delay: float = 0.75

@onready var visual_root: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var health_label: Label = get_node_or_null("HealthLabel") as Label

var current_health: int = 100
var _home_position: Vector2
var _feedback_tween: Tween
var _reset_pending: bool = false


func _ready() -> void:
	add_to_group("test_dummy")
	input_pickable = true
	_home_position = position
	current_health = max_health
	_refresh_health_ui()


# Public hook for future prototype attacks.
func apply_hit(damage: int = 10, knockback: Vector2 = Vector2.ZERO) -> void:
	if damage <= 0 or _reset_pending:
		return

	current_health = maxi(0, current_health - damage)
	dummy_hit.emit(damage, current_health)
	health_changed.emit(current_health, max_health)
	_refresh_health_ui()
	_play_hit_feedback(knockback)

	if current_health == 0:
		_reset_pending = true
		dummy_depleted.emit()
		_reset_after_delay()


func reset_dummy() -> void:
	_reset_pending = false
	current_health = max_health
	position = _home_position
	modulate = Color.WHITE
	if visual_root != null:
		visual_root.modulate = Color.WHITE
	_refresh_health_ui()


func _input_event(
	_viewport: Viewport,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var knockback_direction := (global_position - get_global_mouse_position()).normalized()
			if knockback_direction == Vector2.ZERO:
				knockback_direction = Vector2.RIGHT
			apply_hit(click_damage, knockback_direction * click_knockback_pixels)


func _refresh_health_ui() -> void:
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if health_label != null:
		health_label.text = "%d/%d" % [current_health, max_health]


func _play_hit_feedback(knockback: Vector2) -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()

	if visual_root != null:
		visual_root.modulate = Color(1.0, 0.72, 0.58, 1.0)

	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "position", _home_position + knockback, 0.06)
	if visual_root != null:
		_feedback_tween.tween_property(visual_root, "modulate", Color.WHITE, 0.16)
	_feedback_tween.set_parallel(false)
	_feedback_tween.tween_property(self, "position", _home_position, 0.14)


func _reset_after_delay() -> void:
	await get_tree().create_timer(depleted_reset_delay).timeout
	reset_dummy()
