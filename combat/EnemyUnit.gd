# EnemyUnit.gd
# Attach this script to each Enemy node under CombatScene/Enemies.
# It owns enemy HP, shield, simple intent generation, and lightweight statuses.
extends Node
class_name EnemyUnit


# Emitted after HP is lost. CombatManager forwards it to the UI.
signal unit_damaged(unit: EnemyUnit, amount: int)

# Emitted after healing changes HP.
signal unit_healed(unit: EnemyUnit, amount: int)

# Emitted whenever shield is gained or consumed.
signal unit_shield_changed(unit: EnemyUnit, shield: int)

# Emitted once when this enemy reaches zero HP.
signal unit_died(unit: EnemyUnit)

# Emitted after generate_intent creates the visible enemy plan.
signal intent_generated(unit: EnemyUnit, intent: Dictionary)

# Lightweight UI signal for floating HUDs.
signal stats_changed

# Generic death signal for UI components that should not depend on old names.
signal died

# Emitted when the visible intent changes after generation.
signal intent_changed


# Set this in the Inspector to the player-facing enemy name.
@export var enemy_name: String = "Enemy"

# Current HP is initialized from max_hp when the scene loads.
# This is runtime state and should not be exposed in Inspector.
var current_hp: int = 0

# Shield absorbs incoming damage before HP unless a spell ignores shield.
# This is runtime state and should not be exposed in Inspector.
var shield: int = 0

# RoundManager asks the enemy to create this before the planning phase.
# This is runtime state and should not be exposed in Inspector.
var current_intent: Dictionary = {}

# Dead enemies do not generate or execute intents.
var is_alive: bool = true

# Reversed Blade reads this value before applying its bonus damage.
var was_attacked_last_round: bool = false

# Status ids map to remaining round counts.
var status_effects: Dictionary = {}

# Funny and defensive spells can modify only the next attack.
var next_attack_damage_modifier: int = 0

# RoundManager reads this after execute_intent and appends it to CombatLog.
var last_action_log: String = ""

# Damage this round becomes was_attacked_last_round at round end.
var _was_attacked_this_round: bool = false

# Combat stats are loaded from CombatBalanceData during scene setup.
var max_hp: int = 15
var base_attack: int = 3
var starting_shield: int = 0
var guard_chance: float = 0.25
var guard_shield: int = 3


# Godot calls _ready when the scene is loaded.
func _ready() -> void:
	current_hp = max_hp
	shield = starting_shield
	is_alive = current_hp > 0
	add_to_group("enemies")
	add_to_group("combat_units")


# CombatManager passes global defaults after child _ready methods have run.
func apply_balance_defaults(balance: CombatBalanceData) -> void:
	if balance == null:
		return
	max_hp = balance.default_enemy_max_hp
	starting_shield = balance.default_enemy_starting_shield
	base_attack = balance.default_enemy_base_attack
	guard_chance = balance.enemy_guard_chance
	guard_shield = balance.enemy_guard_shield
	current_hp = max_hp
	shield = starting_shield
	is_alive = current_hp > 0


# RoundManager calls this at round start before the player chooses cards.
# Most intents attack a random living mage; some enemies choose to guard.
func generate_intent(living_mages: Array[MageUnit]) -> void:
	current_intent.clear()
	if not is_alive:
		return

	if has_status("stunned"):
		current_intent = {
			"type": "skip",
			"description": "%s is stunned and will lose its action." % enemy_name
		}
	elif has_status("confused"):
		current_intent = {
			"type": "skip",
			"description": "%s is confused and will lose its action." % enemy_name
		}
	elif has_status("silenced"):
		current_intent = {
			"type": "skip",
			"description": "%s is silenced and cannot form an intent." % enemy_name
		}
	# Guard probability and shield are balance-driven design values.
	elif randf() < clampf(guard_chance, 0.0, 1.0):
		current_intent = {
			"type": "guard",
			"shield": guard_shield,
			"description": "%s intends to Guard for %d shield." % [
				enemy_name,
				guard_shield
			]
		}
	elif not living_mages.is_empty():
		var target: MageUnit = living_mages.pick_random()
		var damage := maxi(0, base_attack + next_attack_damage_modifier)
		current_intent = {
			"type": "attack",
			"target": target,
			"damage": damage,
			"description": "%s intends to attack %s for %d." % [
				enemy_name,
				target.mage_name,
				damage
			]
		}

	intent_generated.emit(self, current_intent)
	intent_changed.emit()


# RoundManager calls this after the chant resolves.
# It applies the previously displayed intent and records a readable log line.
func execute_intent(living_mages: Array[MageUnit]) -> void:
	last_action_log = ""
	if not is_alive or current_intent.is_empty():
		return

	# Chants apply these statuses after intents are generated, so execution must
	# check them again before using the intent that was visible during planning.
	if has_status("stunned") or has_status("confused") or has_status("silenced"):
		last_action_log = "%s loses its action because of a chant status." % enemy_name
		_remove_skip_statuses()
		return

	if has_status("delayed"):
		remove_status("delayed")
		last_action_log = "%s's intent is delayed and does not happen." % enemy_name
		return

	var intent_type := String(current_intent.get("type", ""))
	match intent_type:
		"skip":
			last_action_log = String(current_intent.get(
				"description",
				"%s loses its action." % enemy_name
			))
			_remove_skip_statuses()
		"guard":
			var guard_amount := int(current_intent.get("shield", guard_shield))
			gain_shield(guard_amount)
			last_action_log = "%s guards and gains %d shield." % [
				enemy_name,
				guard_amount
			]
		"attack":
			var target := current_intent.get("target") as MageUnit
			if target == null or not target.is_alive:
				target = _pick_living_mage(living_mages)
			if target == null:
				return
			var damage := maxi(0, int(current_intent.get("damage", base_attack)))
			target.take_damage(damage)
			last_action_log = "%s attacks %s for %d damage." % [
				enemy_name,
				target.mage_name,
				damage
			]
			next_attack_damage_modifier = 0


# ChantResolver calls this for direct and area damage.
# When ignore_shield is true, Bright Cut bypasses the shield value.
func take_damage(amount: int, ignore_shield: bool = false) -> void:
	if amount <= 0 or not is_alive:
		return

	var remaining_damage := amount
	if not ignore_shield and shield > 0:
		var absorbed := mini(shield, remaining_damage)
		shield -= absorbed
		remaining_damage -= absorbed
		unit_shield_changed.emit(self, shield)
		stats_changed.emit()

	if remaining_damage <= 0:
		return

	var applied_damage := mini(current_hp, remaining_damage)
	current_hp -= applied_damage
	_was_attacked_this_round = true

	# Silent Frog ends early if the target takes real HP damage.
	if has_status("silenced"):
		remove_status("silenced")

	unit_damaged.emit(self, applied_damage)
	stats_changed.emit()
	if current_hp <= 0:
		die()


# Choked Flame calls this to heal its enemy target.
func heal(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	var previous_hp := current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var applied_healing := current_hp - previous_hp
	if applied_healing > 0:
		unit_healed.emit(self, applied_healing)
		stats_changed.emit()


# Several chant results protect an enemy instead of damaging it.
func gain_shield(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	shield += amount
	unit_shield_changed.emit(self, shield)
	stats_changed.emit()


# ChantResolver calls this for stun, confusion, silence, and intent delay.
func apply_status(status_id: String, duration: int = 1) -> void:
	if status_id.is_empty() or not is_alive:
		return
	status_effects[status_id] = maxi(duration, int(status_effects.get(status_id, 0)))


# Other systems use this helper instead of reading the dictionary directly.
func has_status(status_id: String) -> bool:
	return int(status_effects.get(status_id, 0)) > 0


# execute_intent uses this when a one-use status has already done its job.
func remove_status(status_id: String) -> void:
	status_effects.erase(status_id)


# Funny chants use negative values to weaken the next generated attack.
func modify_next_attack_damage(amount: int) -> void:
	# Intents are generated before the chant. If an attack is already visible,
	# it is the "next attack" and should be modified immediately.
	if String(current_intent.get("type", "")) == "attack":
		var current_damage := int(current_intent.get("damage", base_attack))
		current_intent["damage"] = maxi(0, current_damage + amount)
		var target := current_intent.get("target") as MageUnit
		var target_name := target.mage_name if target != null else "the mage"
		current_intent["description"] = "%s intends to attack %s for %d." % [
			enemy_name,
			target_name,
			int(current_intent["damage"])
		]
		intent_changed.emit()
		return

	# Guard/skip intents do not attack, so preserve the modifier for a later round.
	next_attack_damage_modifier += amount


# RoundManager calls this after all enemy intents have resolved.
# It updates Reversed Blade history and reduces remaining status durations.
func end_round() -> void:
	was_attacked_last_round = _was_attacked_this_round
	_was_attacked_this_round = false

	for status_id: String in status_effects.keys():
		var remaining := int(status_effects[status_id]) - 1
		if remaining <= 0:
			status_effects.erase(status_id)
		else:
			status_effects[status_id] = remaining


# take_damage calls this once HP reaches zero.
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	current_hp = 0
	current_intent.clear()
	unit_died.emit(self)
	died.emit()
	stats_changed.emit()
	intent_changed.emit()


# Skip statuses are consumed when the skipped action is processed.
func _remove_skip_statuses() -> void:
	remove_status("stunned")
	remove_status("confused")
	remove_status("silenced")


# If an intended target died during the chant, this selects a replacement.
func _pick_living_mage(living_mages: Array[MageUnit]) -> MageUnit:
	var available: Array[MageUnit] = []
	for mage: MageUnit in living_mages:
		if mage.is_alive:
			available.append(mage)
	if available.is_empty():
		return null
	return available.pick_random()
