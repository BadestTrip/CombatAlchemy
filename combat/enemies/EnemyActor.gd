class_name EnemyActor
extends CharacterBody2D

# Responsibility: Wire an enemy's local capabilities, order physics work, and remove it at zero HP.

## Single source of tuning for this actor. Runtime health/timers never mutate this resource.
@export var profile: EnemyProfileData
## Optional world container injected by the spawner; projectiles must outlive their caster.
var projectiles_parent: Node

@onready var _health := get_node_or_null(^"HealthComponent") as HealthComponent
@onready var _hitbox := get_node_or_null(^"ImpactHitbox") as ImpactHitbox
@onready var _movement := get_node_or_null(^"Movement") as EnemyMovement
@onready var _senses := get_node_or_null(^"Senses") as EnemySenses
@onready var _brain := get_node_or_null(^"Brain") as EnemyBrain
@onready var _attack := get_node_or_null(^"Attack") as EnemyAttack

var _target: Node2D
var _configured := false
var _dying := false


func _ready() -> void:
	if (
		profile == null or not profile.is_valid() or _health == null
		or _hitbox == null or _movement == null or _senses == null
		or _brain == null or _attack == null
		or get_node_or_null(^"CollisionShape2D") == null
	):
		push_error("EnemyActor requires a valid profile, body shape, HealthComponent, ImpactHitbox, Movement, Senses, Brain, and Attack.")
		set_physics_process(false)
		return
	if not _attack.configure(self, profile):
		set_physics_process(false)
		return
	if _attack is RangedEnemyAttack:
		(_attack as RangedEnemyAttack).projectiles_parent = projectiles_parent
	_movement.configure(self, profile.movement_speed)
	_brain.configure(_senses, _movement, _attack, profile)
	_health.reset_health(profile.max_health)
	_health.depleted.connect(_on_depleted)
	_senses.set_target(_target)
	_configured = true


## Assigns an explicit Player target; usable before or after entering the scene tree.
func set_target(target: Node2D) -> void:
	_target = target
	if _configured:
		_senses.set_target(target)
		_attack.cancel()
		_brain.reset()


func _physics_process(delta: float) -> void:
	if not _configured or _dying:
		return
	_senses.refresh(global_position, profile)
	if _senses.get_target() == null:
		_attack.cancel()
		_brain.reset()
	else:
		_attack.advance(delta)
		_brain.tick()
	_movement.advance()


func _on_depleted() -> void:
	if _dying:
		return
	_dying = true
	set_physics_process(false)
	_attack.cancel()
	_movement.stop()
	# Health may deplete during an Area2D callback. Physics changes must be deferred.
	set_deferred(&"collision_layer", 0)
	_hitbox.set_deferred(&"collision_layer", 0)
	queue_free()
