class_name EnemyProjectile
extends Node2D

# Responsibility: Fly one fixed-direction enemy dart until its first impact or expiry.

@onready var _sweep_cast: ShapeCast2D = $SweepCast

var _target: Node2D
var _source: Node
var _direction := Vector2.RIGHT
var _damage := 0
var _speed := 360.0
var _lifetime_left := 3.5
var _active := false


func _ready() -> void:
	add_to_group(&"enemy_projectile")
	set_physics_process(false)


## Launch once, after this scene has been added to its world parent.
func launch(
	origin: Vector2,
	direction: Vector2,
	target: Node2D,
	source: Node,
	damage: int,
	speed: float = 360.0,
	lifetime: float = 3.5
) -> void:
	if _active or is_queued_for_deletion():
		return
	global_position = origin
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	global_rotation = _direction.angle()
	_target = target
	_source = source
	_damage = maxi(damage, 0)
	_speed = maxf(speed, 0.0)
	_lifetime_left = maxf(lifetime, 0.0)
	_sweep_cast.clear_exceptions()
	if is_instance_valid(_source):
		_add_collision_exception_tree(_source)
	_active = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _lifetime_left <= 0.0:
		_consume()
		return
	var travel := _direction * _speed * minf(delta, _lifetime_left)
	if _sweep_for_impact(travel):
		return
	global_position += travel
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_consume()


func _sweep_for_impact(travel: Vector2) -> bool:
	_sweep_cast.target_position = _sweep_cast.to_local(_sweep_cast.global_position + travel)
	while true:
		_sweep_cast.force_shapecast_update()
		var filtered := false
		var closest: CollisionObject2D
		var closest_point := global_position + travel
		var closest_distance := INF
		for index in range(_sweep_cast.get_collision_count()):
			var collider := _sweep_cast.get_collider(index) as CollisionObject2D
			if not is_instance_valid(collider):
				continue
			if _should_ignore(collider):
				_sweep_cast.add_exception(collider)
				var actor := _character_ancestor(collider)
				if actor != null and actor != _target:
					_add_collision_exception_tree(actor)
				filtered = true
				continue
			var point := _sweep_cast.get_collision_point(index)
			var distance := global_position.distance_squared_to(point)
			if distance < closest_distance:
				closest = collider
				closest_point = point
				closest_distance = distance
		# Ignored contacts can fill max_results or stop the cast at an earlier fraction.
		# Exclude them and repeat the entire travel before accepting an impact or moving.
		if filtered:
			continue
		if closest == null:
			return false
		global_position = closest_point
		_consume()
		if not closest is StaticBody2D:
			_damage_target()
		return true
	return false


func _should_ignore(collider: Node) -> bool:
	var subject := collider
	if collider is ImpactHitbox:
		subject = (collider as ImpactHitbox).get_effect_subject()
	if _belongs_to_source(collider) or _belongs_to_source(subject):
		return true
	for node in [collider, subject]:
		var actor := _character_ancestor(node)
		if actor != null and actor != _target:
			return true
	return (
		not collider is StaticBody2D
		and not _belongs_to_target(collider)
		and not _belongs_to_target(subject)
	)


func _character_ancestor(node: Node) -> CharacterBody2D:
	while is_instance_valid(node):
		if node is CharacterBody2D:
			return node as CharacterBody2D
		node = node.get_parent()
	return null


func _belongs_to_source(node: Node) -> bool:
	return (
		is_instance_valid(_source)
		and is_instance_valid(node)
		and (node == _source or _source.is_ancestor_of(node))
	)


func _belongs_to_target(node: Node) -> bool:
	return (
		is_instance_valid(_target)
		and not _target.is_queued_for_deletion()
		and is_instance_valid(node)
		and (node == _target or _target.is_ancestor_of(node))
	)


func _add_collision_exception_tree(node: Node) -> void:
	if node is CollisionObject2D:
		_sweep_cast.add_exception(node as CollisionObject2D)
	for child in node.get_children():
		_add_collision_exception_tree(child)


func _damage_target() -> void:
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		return
	for child in _target.get_children():
		if child is HealthComponent:
			var health := child as HealthComponent
			if not health.is_queued_for_deletion() and health.current_health > 0:
				health.take_damage(_damage)
			return


func _consume() -> void:
	_active = false
	set_physics_process(false)
	queue_free()
