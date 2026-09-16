class_name EnemyProfileData
extends Resource

# Responsibility: Store immutable, Inspector-editable tuning for one enemy archetype.

@export_group("Actor")
@export_range(1, 9999, 1) var max_health: int = 90
@export_range(1.0, 1000.0, 1.0) var movement_speed: float = 180.0
@export_group("Awareness")
@export_range(1.0, 3000.0, 1.0) var notice_distance: float = 900.0
@export_range(1.0, 4000.0, 1.0) var disengage_distance: float = 1200.0
@export_group("Attack")
@export_range(1, 999, 1) var damage: int = 10
@export_range(0.01, 10.0, 0.01) var windup_time: float = 0.5
@export_range(0.01, 10.0, 0.01) var recovery_time: float = 0.85
@export_range(1.0, 2000.0, 1.0) var attack_start_distance: float = 96.0
@export_group("Melee")
@export_range(1.0, 1000.0, 1.0) var melee_reach: float = 110.0
@export_range(1.0, 360.0, 1.0) var melee_arc_degrees: float = 120.0
@export_group("Ranged Positioning")
@export_range(1.0, 2000.0, 1.0) var retreat_start: float = 280.0
@export_range(1.0, 2000.0, 1.0) var retreat_stop: float = 340.0
@export_range(1.0, 2000.0, 1.0) var approach_stop: float = 420.0
@export_range(1.0, 2000.0, 1.0) var approach_start: float = 480.0
@export_group("Projectile")
@export_range(1.0, 3000.0, 1.0) var projectile_speed: float = 360.0
@export_range(0.01, 30.0, 0.01) var projectile_lifetime: float = 3.5


## Rejects tuning that would prevent movement, damage, or stable range decisions.
func is_valid() -> bool:
	return (
		max_health > 0 and movement_speed > 0.0 and damage > 0
		and notice_distance > 0.0 and disengage_distance >= notice_distance
		and windup_time > 0.0 and recovery_time > 0.0
		and attack_start_distance > 0.0 and melee_reach > 0.0
		and melee_arc_degrees > 0.0 and melee_arc_degrees <= 360.0
		and retreat_start > 0.0 and retreat_stop > retreat_start
		and approach_stop > retreat_stop and approach_start > approach_stop
		and projectile_speed > 0.0 and projectile_lifetime > 0.0
	)
