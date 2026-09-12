class_name BrewingProfileData
extends Resource

# Responsibility: Store editable timing and threshold values for one brewing vessel.

## Seconds required to raise reaction energy from zero to one.
@export_range(0.01, 5.0, 0.01) var energy_ramp_time := 0.25
## Progress gained per second at maximum energy.
@export_range(0.01, 5.0, 0.01) var progress_rate := 0.55
## Seconds required for maximum energy to dissipate after release.
@export_range(0.01, 5.0, 0.01) var energy_dissipation_time := 0.45
## Inclusive lower bound for a successful settled reaction.
@export_range(0.0, 1.0, 0.01) var success_min_progress := 0.70
## Inclusive upper bound; exceeding it causes overreaction.
@export_range(0.0, 1.0, 0.01) var success_max_progress := 0.90
## Seconds before an overreacted mixture can be agitated again.
@export_range(0.0, 5.0, 0.01) var overreaction_cooldown := 0.60
## Progress retained after overreaction recovery.
@export_range(0.0, 1.0, 0.01) var recovery_progress := 0.40


## Returns whether the profile can drive a stable reaction simulation.
func is_valid() -> bool:
	return (
		energy_ramp_time > 0.0
		and progress_rate > 0.0
		and energy_dissipation_time > 0.0
		and success_min_progress >= 0.0
		and success_min_progress <= success_max_progress
		and success_max_progress <= 1.0
		and overreaction_cooldown >= 0.0
		and recovery_progress >= 0.0
		and recovery_progress < success_min_progress
	)
