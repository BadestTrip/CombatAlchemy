class_name PotionImpactContext
extends RefCounted

# Responsibility: Carry one potion delivery's source, subject, collision, and geometry.

var subject: Node
var collider: Node
var source: Node
var world_position := Vector2.ZERO
var direction := Vector2.RIGHT
var delivery_method: StringName = PotionDelivery.THROW


## Configures and returns this context for direct or projectile-driven delivery.
func configure(
	configured_subject: Node,
	configured_collider: Node,
	configured_source: Node,
	configured_world_position: Vector2,
	configured_direction: Vector2,
	configured_delivery_method: StringName
) -> PotionImpactContext:
	subject = configured_subject
	collider = configured_collider
	source = configured_source
	world_position = configured_world_position
	direction = (
		configured_direction.normalized()
		if configured_direction.length_squared() > 0.000001
		else Vector2.RIGHT
	)
	delivery_method = (
		configured_delivery_method
		if configured_delivery_method != &""
		else PotionDelivery.THROW
	)
	return self


## Returns whether the impacted subject still exists.
func is_valid() -> bool:
	return subject != null and is_instance_valid(subject)


## Finds a capability script on the subject or one of its direct component children.
func find_component(component_script: Script) -> Node:
	if not is_valid() or component_script == null:
		return null
	if is_instance_of(subject, component_script):
		return subject
	for child in subject.get_children():
		if is_instance_of(child, component_script):
			return child
	return null
