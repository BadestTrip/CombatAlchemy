# MageUnit.gd
# Attach this script to each Mage node under CombatScene/Mages.
# It stores health, shield, life state, and the mage's current three-card hand.
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

# Emitted after this mage draws or discards.
signal hand_updated(mage: MageUnit)


# Set this in the Inspector to the player-facing mage name.
@export var mage_name: String = "Mage"

# Set this in the Inspector to the mage's starting and maximum HP.
@export var max_hp: int = 20


# Current HP is initialized from max_hp when the node enters the scene.
var current_hp: int = 0

# Shield absorbs incoming damage before HP.
var shield: int = 0

# The hand contains SymbolCardData Resources drawn from DeckManager.
var hand: Array[SymbolCardData] = []

# Dead mages cannot select cards and are not valid enemy targets.
var is_alive: bool = true

# CombatManager provides this reference during scene setup.
var deck_manager: DeckManager


# Godot calls _ready when the scene is loaded.
# The group names let other systems discover mages without old zone groups.
func _ready() -> void:
	current_hp = max_hp
	is_alive = current_hp > 0
	add_to_group("mages")
	add_to_group("combat_units")


# CombatManager calls this once so draw/discard methods can reach the shared deck.
func configure(new_deck_manager: DeckManager) -> void:
	deck_manager = new_deck_manager


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

	if remaining_damage <= 0:
		return

	var applied_damage := mini(current_hp, remaining_damage)
	current_hp -= applied_damage
	unit_damaged.emit(self, applied_damage)

	if current_hp <= 0:
		die()


# ChantResolver calls this for protective chants.
func gain_shield(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	shield += amount
	unit_shield_changed.emit(self, shield)


# ChantResolver calls this for healing effects such as Holy Pigeon.
func heal(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	var previous_hp := current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var applied_healing := current_hp - previous_hp
	if applied_healing > 0:
		unit_healed.emit(self, applied_healing)


# RoundManager calls this between rounds.
# It asks the shared DeckManager for cards until the hand reaches hand_size.
func draw_to_hand_size(hand_size: int) -> void:
	if deck_manager == null or not is_alive:
		return

	while hand.size() < hand_size:
		var card := deck_manager.draw_card()
		if card == null:
			break
		hand.append(card)

	hand_updated.emit(self)
	deck_manager.hand_updated.emit(self)


# RoundManager calls this after the selected card has contributed to a chant.
func discard_card(card: SymbolCardData) -> void:
	if card == null or deck_manager == null:
		return
	if not hand.has(card):
		return

	hand.erase(card)
	deck_manager.discard_card(card)
	hand_updated.emit(self)
	deck_manager.hand_updated.emit(self)


# CombatManager may call this for a disaster that discards a random hand card.
func discard_random_card() -> SymbolCardData:
	if hand.is_empty():
		return null
	var card: SymbolCardData = hand.pick_random()
	discard_card(card)
	return card


# take_damage calls this once HP reaches zero.
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	current_hp = 0
	unit_died.emit(self)
