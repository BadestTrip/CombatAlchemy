class_name ImpactHitbox
extends Area2D

# Responsibility: Map a collision area to the entity whose components effects may query.

## Entity exposed as the effect subject when this hitbox is struck.
@export var effect_subject_path: NodePath = ^".."


## Returns the configured entity, falling back to this area when detached or misconfigured.
func get_effect_subject() -> Node:
	var configured_subject := get_node_or_null(effect_subject_path)
	return configured_subject if configured_subject != null else self
