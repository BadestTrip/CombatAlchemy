extends CanvasLayer

# Responsibility: Cover scene changes with the reusable ink-wash snapshot effect.

const MIN_DURATION_SECONDS: float = 0.01
const TRANSITION_LAYER: int = 100
const REVEAL_PROGRESS_PARAMETER: StringName = &"reveal_progress"
const DURATION_PARAMETER: StringName = &"transition_duration_seconds"

## Emitted after a scene change and its ink-wash reveal both finish.
signal transition_finished

## Duration of the ink-wash reveal in seconds.
@export var ink_reveal_time: float = 2.2
## Path to the TextureRect used to hold the outgoing scene snapshot.
@export var transition_snapshot_path: NodePath = ^"TransitionSnapshot"

@onready var transition_snapshot: TextureRect = (
	get_node_or_null(transition_snapshot_path) as TextureRect
)

var shader_material: ShaderMaterial
var is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = TRANSITION_LAYER
	visible = false

	if transition_snapshot == null:
		push_error(
			"InkwashTransition could not find a TextureRect at %s."
			% transition_snapshot_path
		)
		return

	transition_snapshot.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_snapshot.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_snapshot.visible = false
	transition_snapshot.stretch_mode = TextureRect.STRETCH_SCALE

	shader_material = transition_snapshot.material as ShaderMaterial
	if shader_material == null:
		push_error("InkwashTransition requires a ShaderMaterial on TransitionSnapshot.")
		return

	_reset_transition()


## Returns whether an ink-wash scene transition is currently running.
func is_busy() -> bool:
	return is_transitioning


## Sets the editable reveal duration, clamped to a positive value.
func set_transition_duration(duration: float) -> void:
	ink_reveal_time = maxf(MIN_DURATION_SECONDS, duration)
	_set_shader_parameter(DURATION_PARAMETER, ink_reveal_time)


## Changes to a valid scene path behind the ink-wash snapshot and emits transition_finished.
func transition_to_scene(scene_path: String) -> void:
	if is_transitioning:
		return
	if scene_path.is_empty():
		push_error("InkwashTransition requires a non-empty scene path.")
		return
	if shader_material == null or transition_snapshot == null:
		push_error("InkwashTransition is not ready because its snapshot material is missing.")
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		push_error("InkwashTransition cannot run without an active SceneTree.")
		return

	is_transitioning = true
	await _capture_current_screen_to_snapshot()

	visible = true
	transition_snapshot.visible = true
	_set_shader_parameter(DURATION_PARAMETER, ink_reveal_time)
	_set_shader_parameter(REVEAL_PROGRESS_PARAMETER, 0.0)

	var error: Error = tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("InkwashTransition could not load %s (error %d)." % [scene_path, error])
		_cancel_transition()
		return

	await tree.process_frame
	await tree.process_frame
	await _animate_shader_parameter(
		REVEAL_PROGRESS_PARAMETER,
		1.0,
		ink_reveal_time,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)

	_reset_transition()
	is_transitioning = false
	transition_finished.emit()


func _capture_current_screen_to_snapshot() -> void:
	visible = false
	transition_snapshot.visible = false

	await RenderingServer.frame_post_draw

	var viewport_texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = viewport_texture.get_image()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	transition_snapshot.texture = texture


func _animate_shader_parameter(
	parameter_name: StringName,
	target_value: float,
	duration: float,
	transition_type: Tween.TransitionType,
	ease_type: Tween.EaseType
) -> void:
	var start_value: float = float(shader_material.get_shader_parameter(parameter_name))
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)
	tween.tween_method(
		func(value: float) -> void:
			_set_shader_parameter(parameter_name, value),
		start_value,
		target_value,
		maxf(duration, MIN_DURATION_SECONDS)
	)

	await tween.finished


func _set_shader_parameter(parameter_name: StringName, value: float) -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter(parameter_name, value)


func _cancel_transition() -> void:
	_reset_transition()
	is_transitioning = false


func _reset_transition() -> void:
	if shader_material != null:
		_set_shader_parameter(REVEAL_PROGRESS_PARAMETER, 0.0)

	if transition_snapshot != null:
		transition_snapshot.visible = false
		transition_snapshot.texture = null

	visible = false
