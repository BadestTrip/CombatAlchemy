extends Area2D
class_name TestFireProjectile


@export var speed: float = 620.0
@export var damage: int = 25
@export var knockback_pixels: float = 42.0
@export var lifetime_seconds: float = 1.8

var _direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _has_hit: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func initialize(direction: Vector2) -> void:
	_direction = direction.normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime_seconds:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return
	if not area.is_in_group("test_dummy"):
		return

	_has_hit = true
	if area.has_method("apply_hit"):
		area.call("apply_hit", damage, _direction * knockback_pixels)
	queue_free()
