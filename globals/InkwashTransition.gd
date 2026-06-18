extends CanvasLayer

signal transition_finished

@export var ink_reveal_time: float = 2.2
@export var transition_snapshot_path: NodePath = ^"TransitionSnapshot"

@onready var transition_snapshot: TextureRect = get_node(transition_snapshot_path) as TextureRect

var shader_material: ShaderMaterial
var is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false

	if transition_snapshot == null:
		push_error("TransitionSnapshot node not found.")
		return

	transition_snapshot.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_snapshot.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_snapshot.visible = false
	transition_snapshot.stretch_mode = TextureRect.STRETCH_SCALE

	shader_material = transition_snapshot.material as ShaderMaterial
	if shader_material == null:
		push_error("TransitionSnapshot needs a ShaderMaterial.")
		return

	_reset_transition()


func is_busy() -> bool:
	return is_transitioning


# MainMenu calls this before scene-changing buttons invoke GameManager.
# Keeping the setter here lets other menus reuse the same transition autoload.
func set_transition_duration(duration: float) -> void:
	ink_reveal_time = maxf(0.01, duration)
	_set_shader_parameter("transition_duration_seconds", ink_reveal_time)


func transition_to_scene(scene_path: String) -> void:
	if is_transitioning:
		return

	if shader_material == null:
		push_error("Transition shader material is missing.")
		return

	is_transitioning = true

	# 1. Capture current screen.
	await _capture_current_screen_to_snapshot()

	# 2. Show screenshot as frozen cover.
	visible = true
	transition_snapshot.visible = true
	_set_shader_parameter("transition_duration_seconds", ink_reveal_time)
	_set_shader_parameter("reveal_progress", 0.0)

	# 3. Change scene behind the screenshot.
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not change scene to: " + scene_path)
		_reset_transition()
		is_transitioning = false
		return

	# Let the new scene appear behind the screenshot.
	await get_tree().process_frame
	await get_tree().process_frame

	# 4 + 5. Screenshot stays on top and becomes the transition layer.
	# Ink puddles cut transparent holes into this screenshot.
	await _animate_shader_parameter(
		"reveal_progress",
		1.0,
		ink_reveal_time,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)

	_reset_transition()

	is_transitioning = false
	transition_finished.emit()


func _capture_current_screen_to_snapshot() -> void:
	# Hide this layer before capture so we do not capture the transition itself.
	visible = false
	transition_snapshot.visible = false

	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()

	# Uncomment only if your screenshot appears upside down.
	# image.flip_y()

	var texture := ImageTexture.create_from_image(image)
	transition_snapshot.texture = texture


func _animate_shader_parameter(
	parameter_name: String,
	target_value: float,
	duration: float,
	transition_type: Tween.TransitionType,
	ease_type: Tween.EaseType
) -> void:
	var start_value := float(shader_material.get_shader_parameter(parameter_name))

	var tween := create_tween()
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)

	tween.tween_method(
		func(value: float) -> void:
			_set_shader_parameter(parameter_name, value),
		start_value,
		target_value,
		max(duration, 0.01)
	)

	await tween.finished


func _set_shader_parameter(parameter_name: String, value: float) -> void:
	if shader_material == null:
		return

	shader_material.set_shader_parameter(parameter_name, value)


func _reset_transition() -> void:
	if shader_material != null:
		_set_shader_parameter("reveal_progress", 0.0)

	if transition_snapshot != null:
		transition_snapshot.visible = false
		transition_snapshot.texture = null

	visible = false
