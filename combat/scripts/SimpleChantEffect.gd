extends Node2D
class_name SimpleChantEffect

var effect_type: String = "projectile"
var color: Color = Color.WHITE
var direction: Vector2 = Vector2.RIGHT
var speed: float = 650.0
var lifetime: float = 0.9
var age: float = 0.0
var radius: float = 8.0
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


func setup(result: SpellResultData, context: Dictionary, override_effect_type: String = "") -> void:
	effect_type = override_effect_type if not override_effect_type.is_empty() else result.effect_type
	color = result.effect_color
	direction = context.get("aim_direction", Vector2.RIGHT)
	if direction.length() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	speed = result.effect_speed
	lifetime = result.effect_lifetime
	radius = result.effect_radius
	damage = result.damage if effect_type.begins_with("projectile") else 0
	shield = result.shield if effect_type == "shield" or effect_type == "projectile_plus_shield" else 0
	caster_node = context.get("player_node") as Node2D
	target_node = context.get("enemy_node") as Node2D
	target_unit = context.get("enemy_unit") as CombatUnit

	if context.has("log_callback"):
		_log_callback = context["log_callback"]

	var cast_origin: Vector2 = context.get("cast_origin", Vector2.ZERO)
	global_position = cast_origin
	if effect_type == "shield" and caster_node != null:
		global_position = caster_node.global_position


func _process(delta: float) -> void:
	age += delta

	if effect_type == "shield":
		if caster_node != null:
			global_position = caster_node.global_position
	elif effect_type.begins_with("projectile"):
		if not hit_done:
			global_position += direction * speed * delta
			_check_projectile_hit()
	elif effect_type == "fizzle":
		global_position += direction * speed * 0.18 * delta

	queue_redraw()

	if age >= lifetime:
		_log_miss_if_needed()
		queue_free()


func _draw() -> void:
	var fade := clampf(1.0 - age / maxf(lifetime, 0.001), 0.0, 1.0)
	var draw_color := Color(color.r, color.g, color.b, color.a * fade)

	match effect_type:
		"shield":
			_draw_shield(draw_color, fade)
		"projectile_plus_shield":
			_draw_projectile(draw_color)
			_draw_shield(Color(color.r, color.g, color.b, color.a * fade * 0.45), fade)
		"fizzle":
			_draw_fizzle(draw_color, fade)
		_:
			_draw_projectile(draw_color)


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


func _draw_projectile(draw_color: Color) -> void:
	var tail := -direction * radius * 3.4
	draw_line(tail, Vector2.ZERO, Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.45), radius * 0.75)
	draw_circle(Vector2.ZERO, radius, draw_color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 1.0, 1.0, draw_color.a))


func _draw_shield(draw_color: Color, fade: float) -> void:
	var pulse := 1.0 + sin(age * 18.0) * 0.08
	var ring_radius := lerpf(radius * 2.2, radius * 5.2, 1.0 - fade) * pulse
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, draw_color, 3.0)
	draw_circle(Vector2.ZERO, ring_radius * 0.32, Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.18))


func _draw_fizzle(draw_color: Color, fade: float) -> void:
	var spark_radius := radius * (1.0 + (1.0 - fade) * 1.8)
	draw_circle(Vector2.ZERO, spark_radius, Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.45))
	draw_line(Vector2(-spark_radius, 0.0), Vector2(spark_radius, 0.0), draw_color, 2.0)
	draw_line(Vector2(0.0, -spark_radius), Vector2(0.0, spark_radius), draw_color, 2.0)


func _log_miss_if_needed() -> void:
	if _miss_logged or hit_done or damage <= 0 or not effect_type.begins_with("projectile"):
		return
	_miss_logged = true
	_emit_log("The aimed chant misses.")


func _emit_log(line: String) -> void:
	if _log_callback.is_valid():
		_log_callback.call(line)
