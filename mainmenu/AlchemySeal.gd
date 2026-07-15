## Draws a self-contained, animated alchemy seal for the main menu.
extends Control
class_name AlchemySeal


@export_group("Geometry")

## Maximum radius of the outer ring in pixels.
@export_range(32.0, 600.0, 1.0) var seal_radius: float = 260.0

## Width of the seal's ring and geometry strokes.
@export_range(0.5, 8.0, 0.1) var ring_width: float = 2.0

## Number of evenly spaced ticks around the outer ring.
@export_range(3, 24, 1) var radial_mark_count: int = 12

## Size of the three colored geometric marks.
@export_range(2.0, 40.0, 0.5) var colored_mark_size: float = 13.0


@export_group("Animation")

## Clockwise rotation speed of the outer geometry in degrees per second.
@export_range(-30.0, 30.0, 0.1) var rotation_speed_degrees: float = 3.0

## Rotation multiplier for the inner geometry; negative values counter-rotate it.
@export_range(-2.0, 2.0, 0.05) var inner_rotation_ratio: float = -0.6

## Enables a restrained opacity pulse.
@export var pulse_enabled: bool = true

## Number of opacity pulse cycles per second.
@export_range(0.0, 3.0, 0.05) var pulse_speed: float = 0.35

## Maximum opacity change produced by the pulse.
@export_range(0.0, 0.3, 0.01) var pulse_strength: float = 0.07


@export_group("Appearance")

## Base opacity shared by the seal geometry.
@export_range(0.0, 1.0, 0.01) var seal_opacity: float = 0.52

## Neutral ink color used for rings, spokes, and ticks.
@export var ring_color: Color = Color(0.09, 0.065, 0.04, 1.0)

## Opacity multiplier for the colored geometric marks.
@export_range(0.0, 1.0, 0.01) var colored_mark_opacity: float = 0.5

## Red accent used by the triangular mark.
@export var red_mark_color: Color = Color(0.62, 0.12, 0.1, 1.0)

## Green accent used by the diamond mark.
@export var green_mark_color: Color = Color(0.18, 0.48, 0.2, 1.0)

## Blue accent used by the circular mark.
@export var blue_mark_color: Color = Color(0.14, 0.32, 0.62, 1.0)


var _outer_rotation: float = 0.0
var _elapsed_seconds: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	_outer_rotation = fmod(
		_outer_rotation + deg_to_rad(rotation_speed_degrees) * delta,
		TAU
	)
	_elapsed_seconds = fmod(_elapsed_seconds + delta, 3600.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var center: Vector2 = size * 0.5
	var available_radius: float = minf(size.x, size.y) * 0.5 - ring_width
	var radius: float = minf(seal_radius, maxf(1.0, available_radius))
	var opacity: float = _calculate_opacity()

	_draw_rings(center, radius, opacity)
	_draw_inner_geometry(center, radius, opacity)
	_draw_colored_marks(center, radius, opacity)


func _draw_rings(center: Vector2, radius: float, opacity: float) -> void:
	var ink: Color = ring_color
	ink.a *= opacity * 0.48

	draw_arc(center, radius, 0.0, TAU, 160, ink, ring_width, true)
	draw_arc(center, radius * 0.76, 0.0, TAU, 128, ink, ring_width * 0.8, true)
	draw_arc(center, radius * 0.44, 0.0, TAU, 96, ink, ring_width * 0.65, true)

	var tick_count: int = maxi(3, radial_mark_count)
	for index: int in range(tick_count):
		var angle: float = _outer_rotation + TAU * float(index) / float(tick_count)
		var direction: Vector2 = Vector2.from_angle(angle)
		var tick_start: float = radius * (0.84 if index % 3 == 0 else 0.9)
		draw_line(
			center + direction * tick_start,
			center + direction * radius,
			ink,
			maxf(0.5, ring_width * 0.7),
			true
		)

	var inner_rotation: float = _outer_rotation * inner_rotation_ratio
	for segment: int in range(6):
		var segment_start: float = inner_rotation + TAU * float(segment) / 6.0
		draw_arc(
			center,
			radius * 0.61,
			segment_start + 0.08,
			segment_start + TAU / 12.0 - 0.08,
			16,
			ink,
			maxf(0.5, ring_width * 0.75),
			true
		)


func _draw_inner_geometry(center: Vector2, radius: float, opacity: float) -> void:
	var ink: Color = ring_color
	ink.a *= opacity * 0.36
	var inner_rotation: float = _outer_rotation * inner_rotation_ratio
	var triangle: PackedVector2Array = _regular_polygon_points(
		center,
		radius * 0.39,
		3,
		inner_rotation - PI * 0.5,
		true
	)
	var hexagon: PackedVector2Array = _regular_polygon_points(
		center,
		radius * 0.25,
		6,
		_outer_rotation,
		true
	)

	draw_polyline(triangle, ink, maxf(0.5, ring_width * 0.7), true)
	draw_polyline(hexagon, ink, maxf(0.5, ring_width * 0.6), true)

	for index: int in range(3):
		var angle: float = inner_rotation - PI * 0.5 + TAU * float(index) / 3.0
		draw_line(
			center,
			center + Vector2.from_angle(angle) * radius * 0.39,
			ink,
			maxf(0.5, ring_width * 0.55),
			true
		)


func _draw_colored_marks(center: Vector2, radius: float, opacity: float) -> void:
	var mark_radius: float = radius * 0.69
	var red_angle: float = _outer_rotation - PI * 0.5
	var green_angle: float = _outer_rotation + TAU / 3.0 - PI * 0.5
	var blue_angle: float = _outer_rotation + TAU * 2.0 / 3.0 - PI * 0.5

	var red: Color = red_mark_color
	red.a *= opacity * colored_mark_opacity
	var green: Color = green_mark_color
	green.a *= opacity * colored_mark_opacity
	var blue: Color = blue_mark_color
	blue.a *= opacity * colored_mark_opacity

	var red_center: Vector2 = center + Vector2.from_angle(red_angle) * mark_radius
	var green_center: Vector2 = center + Vector2.from_angle(green_angle) * mark_radius
	var blue_center: Vector2 = center + Vector2.from_angle(blue_angle) * mark_radius

	var triangle: PackedVector2Array = _regular_polygon_points(
		red_center,
		colored_mark_size,
		3,
		red_angle,
		true
	)
	var diamond: PackedVector2Array = _regular_polygon_points(
		green_center,
		colored_mark_size,
		4,
		green_angle,
		true
	)

	draw_polyline(triangle, red, maxf(0.75, ring_width), true)
	draw_polyline(diamond, green, maxf(0.75, ring_width), true)
	draw_arc(
		blue_center,
		colored_mark_size * 0.78,
		0.0,
		TAU,
		24,
		blue,
		maxf(0.75, ring_width),
		true
	)
	var blue_axis: Vector2 = Vector2.from_angle(blue_angle) * colored_mark_size
	draw_line(
		blue_center - blue_axis,
		blue_center + blue_axis,
		blue,
		maxf(0.75, ring_width * 0.8),
		true
	)


func _regular_polygon_points(
	center: Vector2,
	radius: float,
	side_count: int,
	rotation: float,
	close_shape: bool
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_side_count: int = maxi(3, side_count)
	for index: int in range(safe_side_count):
		var angle: float = rotation + TAU * float(index) / float(safe_side_count)
		points.append(center + Vector2.from_angle(angle) * radius)
	if close_shape and not points.is_empty():
		points.append(points[0])
	return points


func _calculate_opacity() -> float:
	var opacity: float = seal_opacity
	if pulse_enabled:
		opacity += sin(_elapsed_seconds * TAU * pulse_speed) * pulse_strength
	return clampf(opacity, 0.0, 1.0)
