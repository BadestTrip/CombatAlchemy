# DeckManager.gd
# Attach this script to the DeckManager node in CombatScene.tscn.
# It owns the shared draw pile and discard pile used by all three mages.
# Mages ask this manager for cards instead of managing separate decks.
extends Node
class_name DeckManager


# Emitted whenever a mage draws or discards a card.
# CombatUIController listens indirectly through RoundManager and refreshes hands.
signal hand_updated(mage: MageUnit)


# The current shared draw pile. The last array item is drawn first.
var draw_pile: Array[SymbolCardData] = []

# Used cards wait here until the draw pile is empty.
var discard_pile: Array[SymbolCardData] = []


# CombatManager calls this once when a new combat scene starts.
# Three copies of each of the nine symbols provide a simple 27-card MVP deck.
func create_starter_deck() -> void:
	draw_pile.clear()
	discard_pile.clear()

	for copy_index: int in range(3):
		# Hidden/dev feel: ignition, beginning, activation.
		draw_pile.append(_make_card("asha", "ASHA", "First Flame", "^^"))
		# Hidden/dev feel: force, motion, push.
		draw_pile.append(_make_card("voro", "VORO", "Turning Force", ">>"))
		# Hidden/dev feel: cut, sever, damage.
		draw_pile.append(_make_card("keth", "KETH", "Sever Mark", "//"))
		# Hidden/dev feel: mirror, reflection, copy.
		draw_pile.append(_make_card("mira", "MIRA", "Mirror Eye", "<>"))
		# Hidden/dev feel: void, silence, negation.
		draw_pile.append(_make_card("nox", "NOX", "Null Ring", "OO"))
		# Hidden/dev feel: scatter, random, many.
		draw_pile.append(_make_card("iri", "IRI", "Many Star", "***"))
		# Hidden/dev feel: light, ward, protection.
		draw_pile.append(_make_card("elum", "ELUM", "Ward Gate", "[]"))
		# Hidden/dev feel: shock, instability, surge.
		draw_pile.append(_make_card("zun", "ZUN", "Forked Shock", "!!"))
		# Hidden/dev feel: mass, body, absurdity.
		draw_pile.append(_make_card("bavo", "BAVO", "Heavy Knot", "##"))

	draw_pile.shuffle()


# CombatManager calls this after creating the deck.
# The opening hands guarantee that ASHA + VORO + KETH can be tested immediately,
# while still giving every mage three different discovery choices.
func deal_opening_hands(mages: Array[MageUnit]) -> void:
	if mages.size() < 3:
		return

	var opening_symbols: Array = [
		["asha", "elum", "zun"],
		["voro", "mira", "iri"],
		["keth", "bavo", "nox"]
	]

	for mage_index: int in range(3):
		var mage: MageUnit = mages[mage_index]
		for symbol_id: String in opening_symbols[mage_index]:
			var card := _take_specific_card(symbol_id)
			if card != null:
				mage.hand.append(card)
		hand_updated.emit(mage)


# MageUnit calls this while drawing back to the required hand size.
# If the draw pile is empty, the discard pile is shuffled back into it.
func draw_card() -> SymbolCardData:
	if draw_pile.is_empty():
		_recycle_discard_pile()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()


# MageUnit calls this after a selected chant card is used.
func discard_card(card: SymbolCardData) -> void:
	if card != null:
		discard_pile.append(card)


# This helper creates a new Resource instance for one physical deck card.
func _make_card(
	symbol_id: String,
	spoken_word: String,
	display_name: String,
	visual_hint: String
) -> SymbolCardData:
	return SymbolCardData.new().configure(
		symbol_id,
		spoken_word,
		display_name,
		visual_hint
	)


# Opening-hand setup uses this to remove one requested symbol from the shared deck.
func _take_specific_card(symbol_id: String) -> SymbolCardData:
	for index: int in range(draw_pile.size()):
		if draw_pile[index].symbol_id == symbol_id:
			return draw_pile.pop_at(index)
	return draw_card()


# Recycling is intentionally simple for the MVP: move, clear, then shuffle.
func _recycle_discard_pile() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()
