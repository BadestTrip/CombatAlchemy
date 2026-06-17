# DeckManager.gd
# Deprecated for the current full-rune-palette prototype.
# Kept only in case we later test deck/hand variants again. The active
# CombatScene does not instantiate this manager, deal hands, draw, or discard.
# Older deck experiments can still use it as a shared draw/discard manager.
extends Node
class_name DeckManager


# Emitted whenever a mage draws or discards a card.
# CombatUIController listens indirectly through RoundManager and refreshes hands.
signal hand_updated(mage: MageUnit)


# Assign CombatBalance_Default.tres here to control deck and hand sizes.
@export_group("Balance")
@export var balance: CombatBalanceData

# Assign SymbolLibrary_Default.tres here to define the available symbols.
@export_group("Symbols")
@export var symbol_library: SymbolLibraryData

# Edit these arrays to guarantee specific opening chant combinations.
@export_group("Opening Hands")
@export var mage_1_opening_symbols: Array[String] = [
	"asha", "iri", "zun", "elum"
]
@export var mage_2_opening_symbols: Array[String] = [
	"voro", "bavo", "iri", "zun"
]
@export var mage_3_opening_symbols: Array[String] = [
	"keth", "asha", "nox", "mira"
]


# The current shared draw pile. The last array item is drawn first.
# This is runtime state and should not be exposed in Inspector.
var draw_pile: Array[SymbolCardData] = []

# Used cards wait here until the draw pile is empty.
# This is runtime state and should not be exposed in Inspector.
var discard_pile: Array[SymbolCardData] = []

# A missing Inspector resource uses this safe in-memory default.
var _fallback_balance: CombatBalanceData


# CombatManager calls this once when a new combat scene starts.
# Each library entry is duplicated for every physical card in the shared deck.
func create_starter_deck() -> void:
	draw_pile.clear()
	discard_pile.clear()

	if symbol_library == null or symbol_library.symbols.is_empty():
		push_warning(
			"DeckManager needs a non-empty SymbolLibraryData resource. "
			+ "No starter cards were created."
		)
		return

	var settings := _get_balance()
	var copy_count := maxi(0, settings.copies_per_symbol_in_shared_deck)

	# Duplicate templates so two copies of one symbol remain separate cards.
	for copy_index: int in range(copy_count):
		for symbol: SymbolCardData in symbol_library.symbols:
			if symbol == null or symbol.symbol_id.is_empty():
				push_warning("DeckManager skipped an empty symbol resource.")
				continue
			var physical_card := symbol.duplicate(true) as SymbolCardData
			if physical_card != null:
				draw_pile.append(physical_card)

	draw_pile.shuffle()


# CombatManager calls this after creating the deck.
# Scripted arrays guarantee test chants; random cards fill any remaining slots.
func deal_opening_hands(mages: Array[MageUnit]) -> void:
	if mages.size() < 3:
		push_warning("DeckManager expected three mages for opening hands.")
		return

	var settings := _get_balance()
	var hand_size := mini(
		maxi(0, settings.starting_hand_size),
		maxi(0, settings.max_hand_size)
	)
	if settings.starting_hand_size > settings.max_hand_size:
		push_warning(
			"starting_hand_size is larger than max_hand_size. "
			+ "Opening hands were capped."
		)

	var opening_symbols: Array[Array] = [
		mage_1_opening_symbols,
		mage_2_opening_symbols,
		mage_3_opening_symbols
	]

	for mage_index: int in range(3):
		var mage: MageUnit = mages[mage_index]
		mage.hand.clear()

		# Scripted cards are optional and never exceed max hand size.
		if settings.use_scripted_opening_hands:
			var requested_symbols: Array = opening_symbols[mage_index]
			if requested_symbols.size() > settings.max_hand_size:
				push_warning(
					"Mage %d opening symbols exceed max_hand_size and were capped."
					% (mage_index + 1)
				)
			var scripted_count := mini(requested_symbols.size(), hand_size)
			for symbol_index: int in range(scripted_count):
				var symbol_id := String(requested_symbols[symbol_index])
				var card := _take_specific_card(symbol_id)
				if card != null:
					mage.hand.append(card)

		# Random dealing also fills short scripted arrays.
		while mage.hand.size() < hand_size:
			var card := draw_card()
			if card != null:
				mage.hand.append(card)
			else:
				break
		hand_updated.emit(mage)


# MageUnit calls this while drawing back to the required hand size.
# If the draw pile is empty, the discard pile is shuffled back into it.
func draw_card() -> SymbolCardData:
	if draw_pile.is_empty():
		if _get_balance().reshuffle_discard_when_deck_empty:
			_recycle_discard_pile()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()


# MageUnit calls this after a selected chant card is used.
func discard_card(card: SymbolCardData) -> void:
	if card != null:
		discard_pile.append(card)


# Opening-hand setup uses this to remove one requested symbol from the shared deck.
func _take_specific_card(symbol_id: String) -> SymbolCardData:
	for index: int in range(draw_pile.size()):
		if draw_pile[index].symbol_id == symbol_id:
			return draw_pile.pop_at(index)
	push_warning(
		"Opening hand requested missing symbol '%s'; drawing a random card."
		% symbol_id
	)
	return draw_card()


# Recycling is intentionally simple for the MVP: move, clear, then shuffle.
func _recycle_discard_pile() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()


# Missing scene wiring should warn but should not crash combat setup.
func _get_balance() -> CombatBalanceData:
	if balance != null:
		return balance
	if _fallback_balance == null:
		_fallback_balance = CombatBalanceData.new()
		push_warning(
			"DeckManager has no CombatBalanceData assigned; using script defaults."
		)
	return _fallback_balance
