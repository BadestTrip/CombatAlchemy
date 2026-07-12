extends Node2D
class_name SimpleChantEffect

@export_group("Scene Visual Nodes")
@export var projectile_visual_path: NodePath = NodePath("ProjectileVisual")
@export var projectile_trail_path: NodePath = NodePath("ProjectileVisual/Trail")
@export var projectile_core_path: NodePath = NodePath("ProjectileVisual/Core")
@export var projectile_glow_path: NodePath = NodePath("ProjectileVisual/Glow")
@export var projectile_sparks_path: NodePath = NodePath("ProjectileVisual/Sparks")
@export var shield_visual_path: NodePath = NodePath("ShieldVisual")
@export var shield_ring_path: NodePath = NodePath("ShieldVisual/Ring")
@export var shield_aura_path: NodePath = NodePath("ShieldVisual/Aura")
@export var shield_sparks_path: NodePath = NodePath("ShieldVisual/Sparks")
@export var fizzle_visual_path: NodePath = NodePath("FizzleVisual")
@export var fizzle_core_path: NodePath = NodePath("FizzleVisual/Core")
@export var fizzle_horizontal_burst_path: NodePath = NodePath("FizzleVisual/BurstHorizontal")
@export var fizzle_vertical_burst_path: NodePath = NodePath("FizzleVisual/BurstVertical")
@export var fizzle_sparks_path: NodePath = NodePath("FizzleVisual/Sparks")

var effect_type: String = "projectile"
var color: Color = Color.WHITE
var direction: Vector2 = Vector2.RIGHT
var speed: float = 650.0
var lifetime: float = 0.9
var age: float = 0.0
var radius: float = 8.0
var effect_template: ChantEffectTemplateData
var caster_node: Node2D
var target_node: Node2D
var target_unit: CombatUnit
var hit_radius: float = 26.0
var damage: int = 0
var shield: int = 0
var hit_done: bool = false
var on_hit: Callable = Callable()

var _log_callback: Callable = Callable()
var _miss_logged: bool = false
var _visuals_cached: bool = false
var _projectile_visual: Node2D
var _projectile_trail: Line2D
var _projectile_core: Polygon2D
var _projectile_glow: Polygon2D
var _projectile_sparks: Node2D
var _shield_visual: Node2D
var _shield_ring: Line2D
var _shield_aura: Polygon2D
var _shield_sparks: Node2D
var _fizzle_visual: Node2D
var _fizzle_core: Polygon2D
var _fizzle_horizontal_burst: Line2D
var _fizzle_vertical_burst: Line2D
var _fizzle_sparks: Node2D


func _ready() -> void:
	_cache_visual_nodes()
	_update_visuals()


func setup(result: SpellResultData, context: Dictionary, override_effect_type: String = "") -> void:
	effect_type = override_effect_type if not override_effect_type.is_empty() else result.effect_type
	effect_template = result.effect_template
	if effect_template == null:
		effect_template = ChantEffectTemplateData.new()

	color = _get_base_color(result.effect_color)
	direction = context.get("aim_direction", Vector2.RIGHT)
	if direction.length() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	speed = result.effect_speed * maxf(effect_template.speed_multiplier, 0.0)
	lifetime = maxf(result.effect_lifetime * maxf(effect_template.lifetime_multiplier, 0.01), 0.01)
	radius = maxf(result.effect_radius * maxf(effect_template.core_radius_multiplier, 0.01), 0.1)
	hit_radius = maxf(effect_template.hit_radius, 0.1)
	damage = result.damage if effect_type.begins_with("projectile") else 0
	shield = result.shield if effect_type == "shield" or effect_type == "projectile_plus_shield" else 0
	caster_node = context.get("player_node") as Node2D
	target_node = context.get("enemy_node") as Node2D
	target_unit = context.get("enemy_unit") as CombatUnit

	if context.has("log_callback"):
		_log_callback = context["log_callback"]

	var cast_origin: Vector2 = context.get("cast_origin", Vector2.ZERO)
	global_position = cast_origin + direction * effect_template.start_offset
	if effect_type == "shield" and caster_node != null:
		global_position = caster_node.global_position

	_cache_visual_nodes()
	_update_visuals()


func _process(delta: float) -> void:
	age += delta

	if effect_type == "shield":
		if caster_node != null:
			global_position = caster_node.global_position
	elif effect_type.begins_with("projectile"):
		if not hit_done:
			speed = maxf(speed + effect_template.acceleration * delta, 0.0)
			global_position += direction * speed * delta
			_check_projectile_hit()
	elif effect_type == "fizzle":
		speed = maxf(speed + effect_template.acceleration * delta, 0.0)
		global_position += direction * speed * effect_template.fizzle_speed_multiplier * delta

	_update_visuals()

	if age >= lifetime:
		_log_miss_if_needed()
		queue_free()


func _check_projectile_hit() -> void:
	if hit_done or target_node == null or target_unit == null or damage <= 0:
		return
	if global_position.distance_to(target_node.global_position) > hit_radius:
		return

	hit_done = true
	speed = 0.0
	age = maxf(age, lifetime * 0.72)
	var hp_damage := target_unit.take_damage(damage)
	if on_hit.is_valid():
		on_hit.call(hp_damage)
	_emit_log("%s takes %d damage from the aimed chant." % [target_unit.display_name, hp_damage])


func _cache_visual_nodes() -> void:
	if _visuals_cached:
		return

	_projectile_visual = get_node_or_null(projectile_visual_path) as Node2D
	_projectile_trail = get_node_or_null(projectile_trail_path) as Line2D
	_projectile_core = get_node_or_null(projectile_core_path) as Polygon2D
	_projectile_glow = get_node_or_null(projectile_glow_path) as Polygon2D
	_projectile_sparks = get_node_or_null(projectile_sparks_path) as Node2D
	_shield_visual = get_node_or_null(shield_visual_path) as Node2D
	_shield_ring = get_node_or_null(shield_ring_path) as Line2D
	_shield_aura = get_node_or_null(shield_aura_path) as Polygon2D
	_shield_sparks = get_node_or_null(shield_sparks_path) as Node2D
	_fizzle_visual = get_node_or_null(fizzle_visual_path) as Node2D
	_fizzle_core = get_node_or_null(fizzle_core_path) as Polygon2D
	_fizzle_horizontal_burst = get_node_or_null(fizzle_horizontal_burst_path) as Line2D
	_fizzle_vertical_burst = get_node_or_null(fizzle_vertical_burst_path) as Line2D
	_fizzle_sparks = get_node_or_null(fizzle_sparks_path) as Node2D
	_visuals_cached = true


func _update_visuals() -> void:
	if effect_template == null:
		effect_template = ChantEffectTemplateData.new()

	_cache_visual_nodes()
	var linear_fade := clampf(1.0 - age / maxf(lifetime, 0.001), 0.0, 1.0)
	var fade := pow(linear_fade, maxf(effect_template.fade_power, 0.01))
	var draw_alpha := clampf(color.a * fade * effect_template.alpha_multiplier, 0.0, 1.0)
	var draw_color := Color(color.r, color.g, color.b, draw_alpha)

	_set_visual_visible(_projectile_visual, false)
	_set_visual_visible(_shield_visual, false)
	_set_visual_visible(_fizzle_visual, false)

	match _get_visual_mode():
		"shield":
			_update_shield_visual(draw_color, fade)
		"projectile_plus_shield":
			_update_projectile_visual(draw_color)
			_update_shield_visual(_with_alpha(draw_color, draw_alpha * effect_template.shield_alpha_multiplier), fade)
		"fizzle":
			_update_fizzle_visual(draw_color, fade)
		_:
			_update_projectile_visual(draw_color)


func _update_projectile_visual(draw_color: Color) -> void:
	_set_visual_visible(_projectile_visual, true)
	if _projectile_visual == null:
		return

	_projectile_visual.position = _get_wobble_offset()
	_projectile_visual.rotation = direction.angle()

	var trail_length := radius * effect_template.tail_length_multiplier
	var line_width := maxf(radius * effect_template.line_width_multiplier, 1.0)
	if _projectile_trail != null:
		_projectile_trail.visible = effect_template.show_trail
		_projectile_trail.width = line_width
		_projectile_trail.default_color = _with_alpha(draw_color, draw_color.a * effect_template.trail_alpha_multiplier)
		_projectile_trail.points = PackedVector2Array([Vector2(-trail_length, 0.0), Vector2.ZERO])

	_set_polygon_visible(_projectile_core, effect_template.show_core)
	if _projectile_core != null:
		_projectile_core.color = draw_color
		_projectile_core.scale = Vector2.ONE * radius

	var glow_radius := radius * maxf(effect_template.glow_radius_multiplier, 0.0)
	_set_polygon_visible(_projectile_glow, effect_template.show_core and glow_radius > 0.0)
	if _projectile_glow != null:
		_projectile_glow.color = _get_glow_color(draw_color.a)
		_projectile_glow.scale = Vector2.ONE * glow_radius

	_update_directional_sparks(_projectile_sparks, effect_template.show_burst, radius, draw_color)


func _update_shield_visual(draw_color: Color, fade: float) -> void:
	_set_visual_visible(_shield_visual, true)
	if _shield_visual == null:
		return

	var pulse := 1.0 + sin(age * effect_template.pulse_speed) * effect_template.pulse_amount
	var ring_start := radius * effect_template.ring_start_multiplier
	var ring_end := radius * effect_template.ring_end_multiplier
	var ring_radius := lerpf(ring_start, ring_end, 1.0 - fade) * pulse
	var spin := age * effect_template.spin_speed
	var line_width := maxf(radius * effect_template.line_width_multiplier, 1.0)
	_shield_visual.rotation = spin

	if _shield_ring != null:
		_shield_ring.visible = effect_template.show_ring
		_shield_ring.width = line_width
		_shield_ring.default_color = draw_color
		_shield_ring.points = _make_circle_points(ring_radius, 48)

	_set_polygon_visible(_shield_aura, effect_template.show_shield_aura)
	if _shield_aura != null:
		_shield_aura.color = Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.18)
		_shield_aura.scale = Vector2.ONE * ring_radius * 0.32

	_update_ring_sparks(_shield_sparks, effect_template.show_burst, ring_radius, draw_color)


func _update_fizzle_visual(draw_color: Color, fade: float) -> void:
	_set_visual_visible(_fizzle_visual, true)
	if _fizzle_visual == null:
		return

	_fizzle_visual.rotation = direction.angle()
	var spark_radius := radius * (1.0 + (1.0 - fade) * 1.8)
	var line_width := maxf(radius * effect_template.line_width_multiplier, 1.0)

	_set_polygon_visible(_fizzle_core, effect_template.show_core)
	if _fizzle_core != null:
		_fizzle_core.color = Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.45)
		_fizzle_core.scale = Vector2.ONE * spark_radius

	if _fizzle_horizontal_burst != null:
		_fizzle_horizontal_burst.visible = effect_template.show_burst
		_fizzle_horizontal_burst.width = line_width
		_fizzle_horizontal_burst.default_color = draw_color
		_fizzle_horizontal_burst.points = PackedVector2Array([Vector2(-spark_radius, 0.0), Vector2(spark_radius, 0.0)])

	if _fizzle_vertical_burst != null:
		_fizzle_vertical_burst.visible = effect_template.show_burst
		_fizzle_vertical_burst.width = line_width
		_fizzle_vertical_burst.default_color = draw_color
		_fizzle_vertical_burst.points = PackedVector2Array([Vector2(0.0, -spark_radius), Vector2(0.0, spark_radius)])

	_update_directional_sparks(_fizzle_sparks, effect_template.show_burst, spark_radius, draw_color)


func _update_directional_sparks(sparks_parent: Node2D, should_show: bool, spark_origin_radius: float, draw_color: Color) -> void:
	var spark_lines := _get_spark_lines(sparks_parent)
	var active_count := mini(maxi(effect_template.spark_count, 0), spark_lines.size()) if should_show else 0
	var spread := deg_to_rad(effect_template.spark_spread_degrees)
	var base_angle := -spread * 0.5
	var spark_color := Color(
		effect_template.secondary_color.r,
		effect_template.secondary_color.g,
		effect_template.secondary_color.b,
		clampf(draw_color.a * effect_template.spark_fade_multiplier, 0.0, 1.0)
	)

	for index in range(spark_lines.size()):
		var spark := spark_lines[index]
		spark.visible = index < active_count
		if index >= active_count:
			continue

		var ratio := 0.5 if active_count == 1 else float(index) / float(active_count - 1)
		var spark_direction := Vector2.RIGHT.rotated(base_angle + spread * ratio)
		spark.default_color = spark_color
		spark.width = maxf(radius * 0.18, 1.0)
		spark.points = PackedVector2Array([
			-spark_direction * spark_origin_radius * 0.35,
			spark_direction * spark_origin_radius * effect_template.spark_length_multiplier
		])


func _update_ring_sparks(sparks_parent: Node2D, should_show: bool, ring_radius: float, draw_color: Color) -> void:
	var spark_lines := _get_spark_lines(sparks_parent)
	var active_count := mini(maxi(effect_template.spark_count, 0), spark_lines.size()) if should_show else 0
	var spark_color := Color(
		effect_template.secondary_color.r,
		effect_template.secondary_color.g,
		effect_template.secondary_color.b,
		clampf(draw_color.a * effect_template.spark_fade_multiplier, 0.0, 1.0)
	)

	for index in range(spark_lines.size()):
		var spark := spark_lines[index]
		spark.visible = index < active_count
		if index >= active_count:
			continue

		var ratio := float(index) / float(active_count)
		var spark_direction := Vector2.RIGHT.rotated(TAU * ratio)
		spark.default_color = spark_color
		spark.width = maxf(radius * 0.16, 1.0)
		spark.points = PackedVector2Array([
			spark_direction * (ring_radius - radius * 0.5),
			spark_direction * (ring_radius + radius * effect_template.spark_length_multiplier)
		])


func _get_spark_lines(sparks_parent: Node2D) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	if sparks_parent == null:
		return lines

	for child in sparks_parent.get_children():
		if child is Line2D:
			lines.append(child as Line2D)
	return lines


func _make_circle_points(circle_radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * circle_radius)
	return points


func _set_visual_visible(node: Node2D, should_show: bool) -> void:
	if node != null:
		node.visible = should_show


func _set_polygon_visible(node: Polygon2D, should_show: bool) -> void:
	if node != null:
		node.visible = should_show


func _log_miss_if_needed() -> void:
	if _miss_logged or hit_done or damage <= 0 or not effect_type.begins_with("projectile"):
		return
	_miss_logged = true
	_emit_log("The aimed chant misses.")


func _emit_log(line: String) -> void:
	if _log_callback.is_valid():
		_log_callback.call(line)


func _get_visual_mode() -> String:
	if effect_template != null and effect_template.effect_mode != "auto":
		return effect_template.effect_mode
	return effect_type


func _get_base_color(result_color: Color) -> Color:
	if effect_template == null or effect_template.use_result_color:
		return result_color
	return effect_template.primary_color


func _get_glow_color(alpha: float) -> Color:
	var glow := effect_template.glow_color
	return Color(glow.r, glow.g, glow.b, alpha)


func _get_wobble_offset() -> Vector2:
	if effect_template.wobble_amount <= 0.0:
		return Vector2.ZERO
	return Vector2(-direction.y, direction.x) * sin(age * effect_template.wobble_speed) * effect_template.wobble_amount


func _with_alpha(input_color: Color, alpha: float) -> Color:
	return Color(
		input_color.r,
		input_color.g,
		input_color.b,
		clampf(alpha, 0.0, 1.0)
	)
