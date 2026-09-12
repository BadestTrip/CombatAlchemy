extends Node

# Responsibility: Verify deterministic small-flask reaction behavior independently of combat.

const BREWING_REACTION_SCRIPT := preload("res://combat/potions/brewing/BrewingReaction.gd")
const BREWING_PROFILE_SCRIPT := preload("res://combat/potions/brewing/BrewingProfileData.gd")
const DEFAULT_PROFILE := preload("res://combat/potions/brewing/SmallFlaskBrewingProfile.tres")

var _failures: Array[String] = []
var _check_count := 0
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	_test_early_release_can_resume_into_success()
	_test_clean_default_brew_completes_after_settling()
	_test_success_range_is_inclusive()
	_test_overreaction_recovers_with_partial_progress()
	_test_repeated_start_and_release_are_idempotent()
	_test_step_size_does_not_change_result()
	_test_overreaction_timing_is_step_size_independent()
	_free_owned_nodes()
	if _failures.is_empty():
		print("BrewingReactionTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("BrewingReactionTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _test_early_release_can_resume_into_success() -> void:
	var reaction = _new_reaction(DEFAULT_PROFILE)
	_expect(reaction.start_agitation(), "an idle reaction accepts agitation")
	reaction.advance(0.5)
	reaction.release_agitation()
	reaction.advance(0.45)
	_expect(reaction.get_state() == reaction.State.IDLE, "early settling returns to idle")
	_expect(is_equal_approx(reaction.get_progress(), 0.33), "early settling preserves predicted progress")
	_expect(reaction.start_agitation(), "an early settled reaction can resume")
	reaction.advance(0.8)
	reaction.release_agitation()
	reaction.advance(0.45)
	_expect(reaction.get_state() == reaction.State.COMPLETED, "resumed brewing can complete")


func _test_clean_default_brew_completes_after_settling() -> void:
	var reaction = _new_reaction(DEFAULT_PROFILE)
	var completion_count := [0]
	reaction.completed.connect(func() -> void: completion_count[0] += 1)
	reaction.start_agitation()
	reaction.advance(1.35)
	_expect(reaction.get_state() == reaction.State.AGITATING, "holding through the success range does not complete")
	_expect(is_equal_approx(reaction.get_predicted_settled_progress(), 0.7975), "prediction uses the settled result")
	reaction.release_agitation()
	reaction.advance(0.45)
	_expect(reaction.get_state() == reaction.State.COMPLETED, "settling in range completes the reaction")
	_expect(completion_count[0] == 1, "successful settling emits completion once")
	reaction.advance(2.0)
	_expect(completion_count[0] == 1, "completed reaction cannot emit twice")


func _test_success_range_is_inclusive() -> void:
	var profile = BREWING_PROFILE_SCRIPT.new()
	profile.energy_ramp_time = 1.0
	profile.progress_rate = 1.0
	profile.energy_dissipation_time = 1.0
	profile.success_min_progress = 0.49
	profile.success_max_progress = 0.64
	profile.overreaction_cooldown = 0.2
	profile.recovery_progress = 0.25
	for hold_time in [0.7, 0.8]:
		var reaction = _new_reaction(profile)
		reaction.start_agitation()
		reaction.advance(hold_time)
		reaction.release_agitation()
		reaction.advance(hold_time)
		_expect(reaction.get_state() == reaction.State.COMPLETED, "success includes the %.2f boundary" % (hold_time * hold_time))


func _test_overreaction_recovers_with_partial_progress() -> void:
	var reaction = _new_reaction(DEFAULT_PROFILE)
	var overreaction_count := [0]
	var recovery_count := [0]
	reaction.overreacted.connect(func() -> void: overreaction_count[0] += 1)
	reaction.recovered.connect(func() -> void: recovery_count[0] += 1)
	reaction.start_agitation()
	reaction.advance(1.7)
	reaction.release_agitation()
	reaction.advance(0.45)
	_expect(reaction.get_state() == reaction.State.COOLDOWN, "progress above the window enters cooldown")
	_expect(overreaction_count[0] == 1, "overreaction emits once")
	_expect(not reaction.start_agitation(), "cooldown rejects agitation")
	reaction.advance(0.6)
	_expect(reaction.get_state() == reaction.State.IDLE, "cooldown returns to idle")
	_expect(is_equal_approx(reaction.get_progress(), 0.4), "recovery preserves configured partial progress")
	_expect(is_zero_approx(reaction.get_energy()), "recovery clears reaction energy")
	_expect(recovery_count[0] == 1, "recovery emits once")


func _test_repeated_start_and_release_are_idempotent() -> void:
	var reaction = _new_reaction(DEFAULT_PROFILE)
	_expect(reaction.start_agitation(), "first start succeeds")
	_expect(not reaction.start_agitation(), "repeated start is rejected")
	reaction.advance(0.5)
	reaction.release_agitation()
	var state_after_release = reaction.get_state()
	reaction.release_agitation()
	_expect(reaction.get_state() == state_after_release, "repeated release does not change state")
	reaction.cancel()
	_expect(reaction.get_state() == reaction.State.IDLE, "cancel returns to idle")
	_expect(is_zero_approx(reaction.get_progress()), "cancel clears progress")


func _test_step_size_does_not_change_result() -> void:
	var coarse = _run_timed_brew(1.35, 0.45, 1.0 / 30.0)
	var fine = _run_timed_brew(1.35, 0.45, 1.0 / 120.0)
	_expect(coarse.get_state() == coarse.State.COMPLETED, "coarse simulation completes")
	_expect(fine.get_state() == fine.State.COMPLETED, "fine simulation completes")
	_expect(is_equal_approx(coarse.get_progress(), fine.get_progress()), "simulation result is stable across frame steps")


func _test_overreaction_timing_is_step_size_independent() -> void:
	var coarse = _run_overreaction_timeline(2.4, 2.0)
	var fine = _run_overreaction_timeline(2.4, 1.0 / 120.0)
	_expect(coarse.get_state() == coarse.State.IDLE, "coarse overreaction timeline finishes recovery")
	_expect(fine.get_state() == fine.State.IDLE, "fine overreaction timeline finishes recovery")
	_expect(is_equal_approx(coarse.get_progress(), fine.get_progress()), "overreaction recovery is stable across frame steps")


func _run_timed_brew(hold_time: float, settle_time: float, step: float):
	var reaction = _new_reaction(DEFAULT_PROFILE)
	reaction.start_agitation()
	_advance_in_steps(reaction, hold_time, step)
	reaction.release_agitation()
	_advance_in_steps(reaction, settle_time, step)
	return reaction


func _run_overreaction_timeline(duration: float, step: float):
	var reaction = _new_reaction(DEFAULT_PROFILE)
	reaction.start_agitation()
	_advance_in_steps(reaction, duration, step)
	return reaction


func _advance_in_steps(reaction, duration: float, step: float) -> void:
	var remaining := duration
	while remaining > 0.000001:
		var delta := minf(step, remaining)
		reaction.advance(delta)
		remaining -= delta


func _new_reaction(profile):
	var reaction = BREWING_REACTION_SCRIPT.new()
	reaction.profile = profile
	_owned_nodes.append(reaction)
	return reaction


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.free()


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
