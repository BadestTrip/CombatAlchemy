extends Node

# Responsibility: Verify the two-check boiling simulation without combat or UI.

const REACTION := preload("res://combat/potions/brewing/BrewingReaction.gd")
const PROFILE := preload("res://combat/potions/brewing/BrewingProfileData.gd")
const DEFAULT_PROFILE := preload("res://combat/potions/brewing/SmallFlaskBrewingProfile.tres")
const EPSILON := 0.00000001

var _failures: Array[String] = []
var _check_count := 0
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	var probe = _new_reaction()
	_expect(probe.has_method("start"), "the boiling simulation exposes start()")
	if probe.has_method("start"):
		_test_profile_scoring_contract()
		_test_all_nine_score_combinations()
		_test_inclusive_boundaries()
		_test_reset_and_blend()
		_test_step_equivalence()
		_test_power_and_suspension()
		_test_cancel_and_duplicate_events()
		_test_profiles_and_invalid_input()
	for node in _owned_nodes:
		node.free()
	if _failures.is_empty():
		print("BrewingReactionTests: PASS (%d checks)" % _check_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("BrewingReactionTests: FAIL (%d failures, %d checks)" % [_failures.size(), _check_count])
	get_tree().quit(1)


func _test_profile_scoring_contract() -> void:
	var profile := DEFAULT_PROFILE as BrewingProfileData
	_expect(profile.has_method(&"score_height"), "brewing profile exposes the shared height-scoring rule")
	_expect(profile.has_method(&"is_perfect_height"), "brewing profile exposes the exact ideal-window cue rule")
	if not profile.has_method(&"score_height") or not profile.has_method(&"is_perfect_height"):
		return
	for entry in [
		[0.64998, 0, false],
		[0.65, 1, true],
		[0.75, 1, true],
		[0.75002, 0, false],
		[1.0, -1, false],
	]:
		_expect(profile.call(&"score_height", entry[0]) == entry[1], "profile scores height %.5f consistently" % entry[0])
		_expect(profile.call(&"is_perfect_height", entry[0]) == entry[2], "ideal cue matches score at height %.5f" % entry[0])


func _test_all_nine_score_combinations() -> void:
	# Literal totals catch swapped, overwritten, or clamped check scores.
	var cases := [
		[0.2, 0.2, -1, -1, -2], [0.2, 0.55, -1, 0, -1], [0.2, 0.7, -1, 1, 0],
		[0.55, 0.2, 0, -1, -1], [0.55, 0.55, 0, 0, 0], [0.55, 0.7, 0, 1, 1],
		[0.7, 0.2, 1, -1, 0], [0.7, 0.55, 1, 0, 1], [0.7, 0.7, 1, 1, 2],
	]
	for entry in cases:
		var reaction = _new_reaction()
		var checks: Array = []
		var completions: Array = []
		reaction.check_completed.connect(func(index: int, score: int): checks.append([index, score]))
		reaction.completed.connect(func(score: int): completions.append(score))
		_expect(reaction.start(), "idle start succeeds for %s" % [entry])
		for index in range(2):
			_expect(reaction.get_cycle_index() == index, "heating reports current check index")
			_heat_to(reaction, entry[index])
			_expect(reaction.release_pressure(), "heating accepts pressure release")
			_expect(reaction.get_state() == reaction.State.RESETTING, "release begins reset")
			_expect(reaction.get_cycle_index() == index, "index remains current during reset")
			_expect(completions.is_empty(), "completion waits for second reset")
			reaction.advance(0.22)
		_expect(reaction.get_results() == [entry[2], entry[3]], "ordered results for %s" % [entry])
		_expect(checks == [[0, entry[2]], [1, entry[3]]], "each check emits index and score once")
		_expect(reaction.get_quality_score() == entry[4], "quality total for %s" % [entry])
		_expect(completions == [entry[4]], "completion carries final quality")
		_expect(reaction.get_state() == reaction.State.COMPLETED, "two resets complete brewing")
		_expect(reaction.get_cycle_index() == 2, "completed index is two")
		_expect(_near(reaction.get_blend_progress(), 1.0), "completed blend is one")
		_expect(not reaction.is_editable(), "completed mixture is not editable")
		var copy: Array[int] = reaction.get_results()
		copy.clear()
		_expect(reaction.get_results().size() == 2, "callers cannot mutate results")


func _test_inclusive_boundaries() -> void:
	for entry in [
		[0.0, -1], [0.4999, -1], [0.5, 0], [0.5001, 0],
		[0.6499, 0], [0.65, 1], [0.6501, 1], [0.7499, 1],
		[0.75, 1], [0.7501, 0], [0.8999, 0], [0.9, 0], [0.9001, -1],
		[0.499999, 0], [0.649999, 1], [0.750001, 1], [0.900001, 0],
	]:
		var reaction = _new_reaction()
		reaction.start()
		_heat_to(reaction, entry[0])
		reaction.release_pressure()
		_expect(reaction.get_results() == [entry[1]], "inclusive epsilon scoring at %.6f" % entry[0])
	var overflow = _new_reaction()
	overflow.start()
	_heat_to(overflow, 0.9999)
	_expect(overflow.get_results().is_empty(), "height below one does not overflow early")
	_heat_to(overflow, 1.0)
	_expect(overflow.get_results() == [-1], "exact height one automatically fails")
	_expect(not overflow.release_pressure(), "overflow already consumed check")


func _test_reset_and_blend() -> void:
	var reaction = _new_reaction()
	reaction.start()
	_heat_to(reaction, 0.35)
	_expect(_near(reaction.get_blend_progress(), 0.25), "first heating drives half the blend")
	reaction.release_pressure()
	reaction.advance(0.11)
	_expect(_near(reaction.get_progress(), 0.175), "reset lowers height continuously")
	_expect(reaction.get_blend_progress() > 0.25, "early release advances blend during reset")
	reaction.advance(0.11)
	_expect(reaction.get_state() == reaction.State.HEATING, "first reset automatically starts second heating")
	_expect(_near(reaction.get_progress(), 0.0), "reset clears height")
	_expect(_near(reaction.get_blend_progress(), 0.5), "first reset establishes halfway baseline")
	_heat_to(reaction, 0.7)
	_expect(reaction.get_blend_progress() < 1.0, "second heating cannot finish blend")
	var blend: float = reaction.get_blend_progress()
	reaction.release_pressure()
	reaction.advance(0.11)
	_expect(reaction.get_blend_progress() >= blend, "second reset never reduces blend")
	_expect(reaction.get_blend_progress() < 1.0, "unfinished reset stays below one")
	reaction.advance(0.11)
	_expect(_near(reaction.get_blend_progress(), 1.0), "only completion finishes blend")
	var early = _new_reaction()
	early.start()
	early.release_pressure()
	early.advance(0.22)
	_expect(_near(early.get_blend_progress(), 0.5), "zero-height release advances baseline")
	early.release_pressure()
	early.advance(0.22)
	_expect(early.get_state() == early.State.COMPLETED, "two zero-height releases still finish")


func _test_step_equivalence() -> void:
	for duration in [1.0, 2.7, 3.0, 5.6, 6.0, 100.0]:
		var coarse = _new_reaction()
		var fine = _new_reaction()
		coarse.start()
		fine.start()
		coarse.advance(duration)
		_advance_in_steps(fine, duration, 1.0 / 120.0)
		_expect_same(coarse, fine, "overflow timeline %.2f" % duration)
	var reaction = _new_reaction()
	var events: Array = []
	reaction.completed.connect(func(score: int): events.append(score))
	reaction.start()
	reaction.advance(100.0)
	_expect(reaction.get_results() == [-1, -1], "large delta includes both overflows")
	_expect(events == [-2], "large delta completes exactly once")
	for step in [1.0 / 30.0, 1.0 / 120.0, 0.000001]:
		var coarse = _new_reaction()
		var fine = _new_reaction()
		coarse.start()
		fine.start()
		coarse.advance(0.001)
		_advance_in_steps(fine, 0.001, step)
		_expect_same(coarse, fine, "small positive deltas are not discarded")
	var coarse = _new_reaction()
	var fine = _new_reaction()
	coarse.start()
	fine.start()
	_heat_to(coarse, 0.7)
	_heat_to(fine, 0.7)
	coarse.release_pressure()
	fine.release_pressure()
	coarse.advance(0.62)
	_advance_in_steps(fine, 0.62, 1.0 / 120.0)
	_expect_same(coarse, fine, "manual reset carries unused delta into heating")
	_expect(_near(coarse.get_progress(), 0.15), "remaining 0.4 seconds heats next cycle")


func _test_power_and_suspension() -> void:
	var reaction = _new_reaction()
	_expect(_near(reaction.get_heat_power(), 0.5), "default heat power is half")
	reaction.start()
	reaction.advance(1.0)
	_expect(_near(reaction.get_progress(), 0.375), "default profile heats at half rise rate")
	reaction.set_heat_power(0.0)
	reaction.advance(100.0)
	_expect(_near(reaction.get_progress(), 0.375), "zero heat freezes height")
	reaction.set_heat_power(2.0)
	_expect(_near(reaction.get_heat_power(), 1.0), "heat clamps high values")
	reaction.advance(0.2)
	_expect(_near(reaction.get_progress(), 0.525), "power changes apply immediately")
	reaction.set_heat_power(-1.0)
	_expect(_near(reaction.get_heat_power(), 0.0), "heat clamps low values")
	reaction.set_suspended(true)
	var before := _snapshot(reaction)
	reaction.advance(100.0)
	_expect(not reaction.release_pressure(), "suspension rejects pressure release")
	_expect(_snapshot(reaction) == before, "suspension freezes all heating state")
	reaction.set_suspended(false)
	_expect(reaction.release_pressure(), "zero heat still permits release")
	reaction.advance(0.055)
	reaction.set_suspended(true)
	before = _snapshot(reaction)
	reaction.advance(100.0)
	_expect(_snapshot(reaction) == before, "suspension freezes reset and blend")
	reaction.set_suspended(false)
	reaction.advance(0.165)
	_expect(reaction.get_state() == reaction.State.HEATING, "reset resumes at same elapsed time")
	_expect(_near(reaction.get_progress(), 0.0), "zero heat does not freeze reset")
	reaction.cancel()
	reaction.set_suspended(true)
	_expect(not reaction.start(), "suspended idle cannot start")


func _test_cancel_and_duplicate_events() -> void:
	var reaction = _new_reaction()
	var states: Array = []
	var checks: Array = []
	var completions: Array = []
	var updates: Array = []
	reaction.state_changed.connect(func(state): states.append(state))
	reaction.check_completed.connect(func(index: int, score: int): checks.append([index, score]))
	reaction.completed.connect(func(score: int): completions.append(score))
	reaction.reaction_changed.connect(func(height: float, power: float, blend: float): updates.append([height, power, blend]))
	_expect(reaction.is_editable(), "idle is editable")
	_expect(not reaction.release_pressure(), "idle release cannot start")
	reaction.start()
	_expect(not reaction.start(), "duplicate start rejected")
	_expect(not reaction.is_editable(), "heating is not editable")
	_heat_to(reaction, 0.7)
	reaction.release_pressure()
	_expect(not reaction.is_editable(), "resetting is not editable")
	_expect(not reaction.start() and not reaction.release_pressure(), "reset rejects both actions")
	reaction.advance(0.22)
	_heat_to(reaction, 0.7)
	reaction.release_pressure()
	reaction.advance(0.22)
	_expect(not reaction.start() and not reaction.release_pressure(), "completed rejects actions")
	reaction.advance(100.0)
	_expect(states == [reaction.State.HEATING, reaction.State.RESETTING, reaction.State.HEATING, reaction.State.RESETTING, reaction.State.COMPLETED], "state transitions emit exactly once")
	_expect(checks == [[0, 1], [1, 1]] and completions == [2], "duplicate actions cannot duplicate events")
	var previous_blend := 0.0
	for update in updates:
		_expect(update[2] >= previous_blend and update[2] <= 1.0, "emitted blend is monotonic and bounded")
		previous_blend = update[2]
	_expect(updates.back() == [0.0, 0.5, 1.0], "signal exposes height, power and blend")
	for cancel_phase in range(3):
		reaction.cancel()
		reaction.set_heat_power(0.8)
		reaction.start()
		reaction.advance(0.2)
		if cancel_phase > 0:
			reaction.release_pressure()
		if cancel_phase > 1:
			reaction.advance(0.22)
		reaction.cancel()
		_expect(reaction.is_editable() and reaction.get_state() == reaction.State.IDLE, "cancel restores editable idle")
		_expect(reaction.get_results().is_empty() and reaction.get_quality_score() == 0, "cancel clears scores")
		_expect(reaction.get_cycle_index() == 0 and _near(reaction.get_progress(), 0.0) and _near(reaction.get_blend_progress(), 0.0), "cancel clears cycle, height and blend")
		_expect(_near(reaction.get_heat_power(), 0.8), "cancel preserves power")
		reaction.advance(100.0)
		_expect(reaction.get_state() == reaction.State.IDLE, "cancel leaves no pending transitions")
	_expect(completions == [2], "cancelled brews never complete")


func _test_profiles_and_invalid_input() -> void:
	_expect(DEFAULT_PROFILE.is_valid(), "default vessel profile is valid")
	var reaction = _new_reaction()
	reaction.profile = null
	_expect(not reaction.start(), "missing profile rejects start")
	for entry in [["rise_rate", 0.0], ["rise_rate", INF], ["reset_duration", -1.0], ["reset_duration", INF], ["perfect_min", 0.8], ["normal_min", 0.7], ["normal_max", 1.1]]:
		var profile = PROFILE.new()
		profile.set(entry[0], entry[1])
		_expect(not profile.is_valid(), "invalid profile rejects %s" % [entry])
	var instant = _new_reaction()
	instant.profile = PROFILE.new()
	instant.profile.reset_duration = 0.0
	instant.start()
	instant.advance(100.0)
	_expect(instant.get_state() == instant.State.COMPLETED, "zero-duration resets terminate")
	var stable = _new_reaction()
	stable.start()
	stable.advance(0.1)
	var before := _snapshot(stable)
	for delta in [0.0, -1.0, NAN, INF]:
		stable.advance(delta)
	_expect(_snapshot(stable) == before, "invalid delta cannot corrupt simulation")
	stable.set_heat_power(NAN)
	_expect(_near(stable.get_heat_power(), 0.5), "NaN heat cannot corrupt simulation")


func _heat_to(reaction, height: float) -> void:
	reaction.advance(maxf(0.0, height - reaction.get_progress()) / (reaction.profile.rise_rate * reaction.get_heat_power()))


func _snapshot(reaction) -> Array:
	return [reaction.get_state(), reaction.get_progress(), reaction.get_cycle_index(), reaction.get_quality_score(), reaction.get_blend_progress(), reaction.get_results()]


func _expect_same(left, right, context: String) -> void:
	_expect(left.get_state() == right.get_state(), context + ": state")
	_expect(left.get_cycle_index() == right.get_cycle_index(), context + ": cycle")
	_expect(left.get_results() == right.get_results(), context + ": results")
	_expect(left.get_quality_score() == right.get_quality_score(), context + ": quality")
	_expect(_near(left.get_progress(), right.get_progress()), context + ": height")
	_expect(_near(left.get_blend_progress(), right.get_blend_progress()), context + ": blend")


func _advance_in_steps(reaction, duration: float, step: float) -> void:
	var remaining := duration
	while remaining > 0.0:
		var delta := minf(step, remaining)
		reaction.advance(delta)
		remaining -= delta


func _new_reaction():
	var reaction = REACTION.new()
	reaction.profile = DEFAULT_PROFILE
	_owned_nodes.append(reaction)
	return reaction


func _near(left: float, right: float) -> bool:
	return absf(left - right) <= EPSILON


func _expect(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
