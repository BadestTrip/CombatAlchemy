# CombatManager.gd
# Attach this script to the root Control of CombatScene.tscn.
# It discovers scene actors, connects the managers, starts combat, and owns
# Victory/Defeat checks. It deliberately contains no chant effect logic.
extends Control
class_name CombatManager


# Emitted once after actors, deck, round manager, resolver, UI, and log are ready.
signal combat_started

# Emitted once when all enemies or all mages are dead.
signal combat_ended(victory: bool)

# Emitted when either a mage or enemy loses HP.
signal unit_damaged(unit: Node, amount: int)

# Emitted when shield changes on either team.
signal unit_shield_changed(unit: Node, shield: int)

# Emitted when either a mage or enemy dies.
signal unit_died(unit: Node)


# Assign CombatBalance_Default.tres here. CombatManager passes it to every
# manager and applies its defaults to units during scene setup.
@export_group("Balance")
@export var balance: CombatBalanceData


# These unique-name paths assume the named nodes exist in CombatScene.tscn.
@onready var mages_root: Node = %Mages
@onready var enemies_root: Node = %Enemies
@onready var deck_manager: DeckManager = %DeckManager
@onready var round_manager: RoundManager = %RoundManager
@onready var chant_resolver: ChantResolver = %ChantResolver
@onready var discovery_manager: SpellDiscoveryManager = %SpellDiscoveryManager
@onready var ui_controller: CombatUIController = %CombatUI
@onready var combat_log: CombatLog = %CombatLog
@onready var round_label: Label = %RoundLabel
@onready var phase_label: Label = %PhaseLabel


# These arrays preserve scene order: Mage 1-3 and Enemy 1-3.
var mages: Array[MageUnit] = []
var enemies: Array[EnemyUnit] = []

# This guard prevents multiple result panels or duplicate end signals.
var has_combat_ended: bool = false


# Godot calls this after child nodes have entered the tree.
# Setup order matters because opening hands need configured MageUnit references.
func _ready() -> void:
	if balance == null:
		balance = CombatBalanceData.new()
		push_warning(
			"CombatManager has no CombatBalanceData assigned; using script defaults."
		)

	_collect_units()
	_connect_unit_signals()
	_pass_balance_to_combat_nodes()

	for mage: MageUnit in mages:
		mage.configure(deck_manager)

	deck_manager.create_starter_deck()
	deck_manager.deal_opening_hands(mages)
	discovery_manager.configure(chant_resolver.spell_recipes)

	round_manager.configure(
		self,
		deck_manager,
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

	combat_log.append_line("Three mages face three hostile adepts.")
	combat_started.emit()
	if balance.auto_start_combat:
		round_manager.start_combat()
	else:
		set_phase_text("Ready")
		ui_controller.refresh_all()


# RoundManager and ChantResolver use this instead of owning duplicate unit arrays.
func get_combat_context() -> Dictionary:
	return {
		"mages": mages,
		"enemies": enemies,
		"deck_manager": deck_manager,
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
	for enemy: EnemyUnit in enemies:
		if enemy.is_alive:
			living.append(enemy)
	return living


# RoundManager uses this as the default target at planning start.
func get_first_living_enemy() -> EnemyUnit:
	var living := get_living_enemies()
	if living.is_empty():
		return null
	return living[0]


# RoundManager calls this after chant resolution and after enemy actions.
# Victory and Defeat are both explicit, independently reachable branches.
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


# RoundManager updates these labels as phases change.
func set_round_number(number: int) -> void:
	round_label.text = "Round %d" % number


func set_phase_text(phase_name: String) -> void:
	phase_label.text = phase_name


# This terminal path disables round input and opens the result controls.
func _end_combat(victory: bool) -> void:
	if has_combat_ended:
		return

	has_combat_ended = true
	round_manager.end_combat()
	set_phase_text("Combat ended")
	combat_log.append_separator()
	combat_log.append_line(
		"Victory! All enemies are defeated."
		if victory
		else "Defeat! All mages have fallen.",
		Color(0.52, 0.9, 0.48) if victory else Color(1.0, 0.42, 0.36)
	)
	ui_controller.show_result(victory)
	combat_ended.emit(victory)


# Unit nodes live under stable Mages and Enemies containers in the scene.
func _collect_units() -> void:
	for child: Node in mages_root.get_children():
		var mage := child as MageUnit
		if mage != null:
			mages.append(mage)

	for child: Node in enemies_root.get_children():
		var enemy := child as EnemyUnit
		if enemy != null:
			enemies.append(enemy)


# Signals keep UI-facing coordination out of MageUnit and EnemyUnit.
func _connect_unit_signals() -> void:
	for mage: MageUnit in mages:
		mage.unit_damaged.connect(_on_mage_damaged)
		mage.unit_shield_changed.connect(_on_mage_shield_changed)
		mage.unit_died.connect(_on_mage_died)

	for enemy: EnemyUnit in enemies:
		enemy.unit_damaged.connect(_on_enemy_damaged)
		enemy.unit_shield_changed.connect(_on_enemy_shield_changed)
		enemy.unit_died.connect(_on_enemy_died)


# One shared Resource keeps Inspector tuning consistent across combat systems.
func _pass_balance_to_combat_nodes() -> void:
	deck_manager.balance = balance
	round_manager.balance = balance
	chant_resolver.balance = balance
	ui_controller.balance = balance

	for mage: MageUnit in mages:
		mage.apply_balance_defaults(balance)
	for enemy: EnemyUnit in enemies:
		enemy.apply_balance_defaults(balance)


func _on_mage_damaged(mage: MageUnit, amount: int) -> void:
	unit_damaged.emit(mage, amount)
	ui_controller.refresh_all()


func _on_enemy_damaged(enemy: EnemyUnit, amount: int) -> void:
	unit_damaged.emit(enemy, amount)
	ui_controller.refresh_all()


func _on_mage_shield_changed(mage: MageUnit, new_shield: int) -> void:
	unit_shield_changed.emit(mage, new_shield)
	ui_controller.refresh_all()


func _on_enemy_shield_changed(enemy: EnemyUnit, new_shield: int) -> void:
	unit_shield_changed.emit(enemy, new_shield)
	ui_controller.refresh_all()


func _on_mage_died(mage: MageUnit) -> void:
	combat_log.append_line("%s falls." % mage.mage_name, Color(1.0, 0.45, 0.4))
	unit_died.emit(mage)
	ui_controller.refresh_all()


func _on_enemy_died(enemy: EnemyUnit) -> void:
	combat_log.append_line(
		"%s is defeated." % enemy.enemy_name,
		Color(1.0, 0.55, 0.38)
	)
	unit_died.emit(enemy)
	ui_controller.refresh_all()
