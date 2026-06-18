# RuneCircle.gd
# Purpose:
#   Draw and animate a lightweight magical rune circle for the main menu.
#
# Node assumptions:
#   - Attach this script to a Control node.
#   - The Control's rectangle is the area where the circle should appear.
#   - The script creates Label children automatically from rune_words.
#   - The node should sit above the menu background and below buttons/title art.
#
# Inspector tuning notes:
#   - radius controls how far rune labels sit from the center of this Control.
#   - rotation_speed_degrees controls the slow menu animation.
#   - rune_opacity and pulse settings keep the seal subtle instead of noisy.
extends Control


# Rune text shown around the circle. These are the existing chant/rune words.
@export var rune_words: Array[String] = [
	"ASHA",
	"VORO",
	"KETH",
	"MIRA",
	"NOX",
	"IRI",
	"ELUM",
	"ZUN",
	"BAVO"
]

# Distance from the center of this Control to each rune label.
@export var radius: float = 260.0

# Slow clockwise rotation speed. Small values keep the menu calm.
@export var rotation_speed_degrees: float = 3.0

# Base opacity for labels and ink guide lines.
@export_range(0.0, 1.0, 0.01) var rune_opacity: float = 0.55

# Enables a very subtle breathing opacity effect.
@export var pulse_enabled: bool = true

# How quickly the opacity pulse moves.
@export var pulse_speed: float = 0.8

# How far opacity can move above and below rune_opacity.
@export_range(0.0, 0.5, 0.01) var pulse_strength: float = 0.12

# Optional visual tuning for the generated rune labels and guide rings.
@export var rune_font_size: int = 28
@export var rune_label_size: Vector2 = Vector2(112.0, 42.0)
@export var ink_color: Color = Color(0.09, 0.065, 0.04, 1.0)
@export var ring_width: float = 2.0


# Runtime-created labels. They are rebuilt from rune_words in _ready().
var _rune_labels: Array[Label] = []

# Internal animation state measured in degrees for readability.
var _current_rotation_degrees: float = 0.0
var _pulse_time: float = 0.0
var _current_alpha: float = 1.0


# Godot calls this when the node enters the scene.
func _ready() -> void:
	# This decoration should never block menu button clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild_rune_labels()
	_update_alpha()
	_update_label_layout()
	queue_redraw()


# Godot calls this every frame because the circle is animated.
func _process(delta: float) -> void:
	_current_rotation_degrees = fmod(
		_current_rotation_degrees + rotation_speed_degrees * delta,
		360.0
	)
	_pulse_time += delta
	_update_alpha()
	_update_label_layout()
	queue_redraw()


# Redraw the ink rings and small tick marks whenever Godot asks this Control to draw.
func _draw() -> void:
	var center := size * 0.5
	var outer_radius := maxf(1.0, radius)
	var inner_radius := maxf(1.0, radius * 0.72)

	var line_color := ink_color
	line_color.a = _current_alpha * 0.42

	# Two imperfect-feeling guide rings give the labels an ancient seal frame.
	draw_arc(center, outer_radius, 0.0, TAU, 128, line_color, ring_width, true)
	draw_arc(center, inner_radius, 0.0, TAU, 128, line_color, ring_width * 0.7, true)

	if rune_words.is_empty():
		return

	# Small radial tick marks make the circle read as a ritual diagram.
	for index: int in range(rune_words.size()):
		var angle := (
			TAU * float(index) / float(rune_words.size())
			+ deg_to_rad(_current_rotation_degrees)
		)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			center + direction * (inner_radius + 8.0),
			center + direction * (outer_radius - 8.0),
			line_color,
			maxf(1.0, ring_width * 0.55),
			true
		)


# Rebuild labels from the exported rune_words array.
func _rebuild_rune_labels() -> void:
	for child: Node in get_children():
		child.queue_free()
	_rune_labels.clear()

	for rune_word: String in rune_words:
		var label := Label.new()
		label.name = "Rune_%s" % rune_word
		label.text = rune_word
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = rune_label_size
		label.size = rune_label_size
		label.add_theme_font_size_override("font_size", rune_font_size)
		add_child(label)
		_rune_labels.append(label)


# Place each generated label around the circle.
func _update_label_layout() -> void:
	if _rune_labels.is_empty():
		return

	var center := size * 0.5
	for index: int in range(_rune_labels.size()):
		var label := _rune_labels[index]
		var angle := (
			TAU * float(index) / float(_rune_labels.size())
			+ deg_to_rad(_current_rotation_degrees)
		)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		label.size = rune_label_size
		label.position = center + offset - rune_label_size * 0.5

		var label_color := ink_color
		label_color.a = _current_alpha
		label.add_theme_color_override("font_color", label_color)


# Calculate the current opacity, including optional pulsing.
func _update_alpha() -> void:
	_current_alpha = clampf(rune_opacity, 0.0, 1.0)
	if pulse_enabled:
		_current_alpha += sin(_pulse_time * TAU * pulse_speed) * pulse_strength
	_current_alpha = clampf(_current_alpha, 0.0, 1.0)


# Godot sends this when the Control is resized in the editor or at runtime.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_label_layout()
		queue_redraw()
