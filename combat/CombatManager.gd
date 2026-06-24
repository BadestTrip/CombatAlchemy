# CombatManager.gd
# Attach this script to the root Control of CombatScene.tscn.
# It discovers the active 1v1 combat actors, wires managers together, and owns
# Victory/Defeat checks. Spell effects still live in ChantResolver.
extends Control
class_name CombatManager


# Emitted once after actors, round manager, resolver, UI, and log are ready.
signal combat_started

# Emitted once when the enemy or player dies.
signal combat_ended(victory: bool)

# Emitted when either combat unit loses HP.
signal unit_damaged(unit: Node, amount: int)

# Emitted when shield changes on either side.
signal unit_shield_changed(unit: Node, shield: int)

# Emitted when either combat unit dies.
signal unit_died(unit: Node)


# Assign CombatBalance_Default.tres here. CombatManager passes it to every
# active combat system and applies its defaults to units during scene setup.
@export_group("Balance")
@export var balance: CombatBalanceData


# These unique-name paths assume the named nodes exist in CombatScene.tscn.
# The containers keep the old scene structure, but the active prototype uses
# only the first MageUnit as the player and the first EnemyUnit as the enemy.
@onready var mages_root: Node = %Mages
@onready var enemies_root: Node = %Enemies
@onready var round_manager: RoundManager = %RoundManager
@onready var chant_resolver: ChantResolver = %ChantResolver
@onready var discovery_manager: SpellDiscoveryManager = %SpellDiscoveryManager
@onready var ui_controller: CombatUIController = %CombatUI
@onready var combat_log: CombatLog = %CombatLog


# These arrays are kept for ChantResolver compatibility. In this prototype they
# should contain exactly one living player and exactly one living enemy.
var mages: Array[MageUnit] = []
var enemies: Array[EnemyUnit] = []

# Convenience references for the new 1v1 combat flow.
var player: MageUnit
var enemy: EnemyUnit

# This guard prevents multiple result panels or duplicate end signals.
var has_combat_ended: bool = false

# RoundManager still reports these values, but the active scene presents flow
# through the central objective label instead of old header labels.
var current_round_number: int = 0
var current_phase_text: String = ""


# Godot calls this after child nodes have entered the tree.
func _ready() -> void:
	if balance == null:
		balance = CombatBalanceData.new()
		push_warning(
			"CombatManager has no CombatBalanceData assigned; using script defaults."
		)

	_collect_units()
	_connect_unit_signals()
	_pass_balance_to_combat_nodes()
	discovery_manager.configure(chant_resolver.spell_recipes, balance)

	round_manager.configure(
		self,
		chant_resolver,
		discovery_manager,
		ui_controller,
		combat_log
	)
	ui_controller.configure(
		self,
		round_manager,
		discovery_manager,
		combat_log
	)

	combat_log.append_line(
		"%s faces %s." % [
			player.mage_name if player != null else "The player",
			enemy.enemy_name if enemy != null else "the enemy"
		]
	)
	combat_started.emit()
	if balance.auto_start_combat:
		round_manager.start_combat()
	else:
		set_phase_text("Ready")
		ui_controller.refresh_all()


# ChantResolver still expects arrays so existing effects such as "damage all
# mages" and "damage all enemies" continue to work without rewriting spell data.
func get_combat_context() -> Dictionary:
	return {
		"mages": mages,
		"enemies": enemies,
		"round_manager": round_manager
	}


# Enemy intent generation and spell helpers use this filtered list.
func get_living_mages() -> Array[MageUnit]:
	var living: Array[MageUnit] = []
	for mage: MageUnit in mages:
		if mage.is_alive:
			living.append(mage)
	return living


# Target selection and spell helpers use this filtered list.
func get_living_enemies() -> Array[EnemyUnit]:
	var living: Array[EnemyUnit] = []
	for current_enemy: EnemyUnit in enemies:
		if current_enemy.is_alive:
			living.append(current_enemy)
	return living


# RoundManager uses this as the single spell target at planning start.
func get_first_living_enemy() -> EnemyUnit:
	var living := get_living_enemies()
	if living.is_empty():
		return null
	return living[0]


# RoundManager calls this after chant resolution and after enemy actions.
func check_combat_end() -> bool:
	if has_combat_ended:
		return true

	if get_living_enemies().is_empty():
		_end_combat(true)
		return true

	if get_living_mages().is_empty():
		_end_combat(false)
		return true

	return false


func set_round_number(number: int) -> void:
	current_round_number = number


func set_phase_text(phase_name: String) -> void:
	current_phase_text = phase_name


# This terminal path disables round input and opens the result controls.
func _end_combat(victory: bool) -> void:
	if has_combat_ended:
		return

	has_combat_ended = true
	round_manager.end_combat()
	set_phase_text("Combat ended")
	combat_log.append_separator()
	combat_log.append_line(
		"Victory! The enemy is defeated."
		if victory
		else "Defeat! The Rune Mage has fallen.",
		Color(0.52, 0.9, 0.48) if victory else Color(1.0, 0.42, 0.36)
	)
	ui_controller.show_result(victory)
	combat_ended.emit(victory)


# Unit nodes live under stable Mages and Enemies containers in the scene.
func _collect_units() -> void:
	mages.clear()
	enemies.clear()

	for child: Node in mages_root.get_children():
		var mage := child as MageUnit
		if mage != null:
			mages.append(mage)

	for child: Node in enemies_root.get_children():
		var current_enemy := child as EnemyUnit
		if current_enemy != null:
			enemies.append(current_enemy)

	if mages.size() > 1:
		push_warning("Full-rune combat uses only the first player unit.")
	if enemies.size() > 1:
		push_warning("Full-rune combat uses only the first enemy unit.")

	if not mages.is_empty():
		player = mages[0]
		var active_mages: Array[MageUnit] = []
		active_mages.append(player)
		mages = active_mages
	if not enemies.is_empty():
		enemy = enemies[0]
		var active_enemies: Array[EnemyUnit] = []
		active_enemies.append(enemy)
		enemies = active_enemies


# Signals keep UI-facing coordination out of MageUnit and EnemyUnit.
func _connect_unit_signals() -> void:
	for mage: MageUnit in mages:
		mage.unit_damaged.connect(_on_mage_damaged)
		mage.unit_shield_changed.connect(_on_mage_shield_changed)
		mage.unit_died.connect(_on_mage_died)

	for current_enemy: EnemyUnit in enemies:
		current_enemy.unit_damaged.connect(_on_enemy_damaged)
		current_enemy.unit_shield_changed.connect(_on_enemy_shield_changed)
		current_enemy.unit_died.connect(_on_enemy_died)


# One shared Resource keeps Inspector tuning consistent across combat systems.
func _pass_balance_to_combat_nodes() -> void:
	round_manager.balance = balance
	chant_resolver.balance = balance
	discovery_manager.balance = balance
	ui_controller.balance = balance

	for mage: MageUnit in mages:
		mage.apply_balance_defaults(balance)
	for current_enemy: EnemyUnit in enemies:
		current_enemy.apply_balance_defaults(balance)


func _on_mage_damaged(mage: MageUnit, amount: int) -> void:
	unit_damaged.emit(mage, amount)
	ui_controller.refresh_all()


func _on_enemy_damaged(current_enemy: EnemyUnit, amount: int) -> void:
	unit_damaged.emit(current_enemy, amount)
	ui_controller.refresh_all()


func _on_mage_shield_changed(mage: MageUnit, new_shield: int) -> void:
	unit_shield_changed.emit(mage, new_shield)
	ui_controller.refresh_all()


func _on_enemy_shield_changed(current_enemy: EnemyUnit, new_shield: int) -> void:
	unit_shield_changed.emit(current_enemy, new_shield)
	ui_controller.refresh_all()


func _on_mage_died(mage: MageUnit) -> void:
	combat_log.append_line("%s falls." % mage.mage_name, Color(1.0, 0.45, 0.4))
	unit_died.emit(mage)
	ui_controller.refresh_all()


func _on_enemy_died(current_enemy: EnemyUnit) -> void:
	combat_log.append_line(
		"%s is defeated." % current_enemy.enemy_name,
		Color(1.0, 0.55, 0.38)
	)
	unit_died.emit(current_enemy)
	ui_controller.refresh_all()
