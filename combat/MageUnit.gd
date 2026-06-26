# MageUnit.gd
# Attach this script to the player Mage node under CombatScene/Mages.
# It stores health, shield, and life state. The class name stays MageUnit for
# compatibility, but the active prototype treats this as the one player unit.
# TODO: Rename to PlayerUnit in a dedicated migration when all references can
# be updated together.
extends Node
class_name MageUnit


# Emitted after HP is lost. CombatManager forwards this for UI updates.
signal unit_damaged(unit: MageUnit, amount: int)

# Emitted after healing changes HP.
signal unit_healed(unit: MageUnit, amount: int)

# Emitted whenever shield is gained or consumed.
signal unit_shield_changed(unit: MageUnit, shield: int)

# Emitted once when this mage reaches zero HP.
signal unit_died(unit: MageUnit)

# Lightweight UI signal for floating HUDs.
signal stats_changed

# Generic death signal for UI components that should not depend on old names.
signal died

# Set this in the Inspector to the player-facing mage name.
@export var mage_name: String = "Mage"

# Current HP is initialized from max_hp when the node enters the scene.
# This is runtime state and should not be exposed in Inspector.
var current_hp: int = 0

# Shield absorbs incoming damage before HP.
# This is runtime state and should not be exposed in Inspector.
var shield: int = 0

# Dead MageUnit instances are no longer valid player units.
# This is runtime state and should not be exposed in Inspector.
var is_alive: bool = true

# Combat stats are loaded from CombatBalanceData during scene setup.
var max_hp: int = 20
var starting_shield: int = 0


# Godot calls _ready when the scene is loaded.
# The group names let other systems discover mages without old zone groups.
func _ready() -> void:
	current_hp = max_hp
	shield = starting_shield
	is_alive = current_hp > 0
	add_to_group("mages")
	add_to_group("combat_units")


# CombatManager passes global defaults after child _ready methods have run.
func apply_balance_defaults(balance: CombatBalanceData) -> void:
	if balance == null:
		return
	max_hp = balance.default_mage_max_hp
	starting_shield = balance.default_mage_starting_shield
	current_hp = max_hp
	shield = starting_shield
	is_alive = current_hp > 0


# EnemyUnit and ChantResolver call this when a mage is hurt.
# Shield is consumed first; only remaining damage reaches HP.
func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return

	var remaining_damage := amount
	if shield > 0:
		var absorbed := mini(shield, remaining_damage)
		shield -= absorbed
		remaining_damage -= absorbed
		unit_shield_changed.emit(self, shield)
		stats_changed.emit()

	if remaining_damage <= 0:
		return

	var applied_damage := mini(current_hp, remaining_damage)
	current_hp -= applied_damage
	unit_damaged.emit(self, applied_damage)
	stats_changed.emit()

	if current_hp <= 0:
		die()


# ChantResolver calls this for protective chants.
func gain_shield(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	shield += amount
	unit_shield_changed.emit(self, shield)
	stats_changed.emit()


# ChantResolver calls this for healing effects such as Holy Pigeon.
func heal(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	var previous_hp := current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var applied_healing := current_hp - previous_hp
	if applied_healing > 0:
		unit_healed.emit(self, applied_healing)
		stats_changed.emit()


# take_damage calls this once HP reaches zero.
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	current_hp = 0
	unit_died.emit(self)
	died.emit()
	stats_changed.emit()
