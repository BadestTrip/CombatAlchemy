# SymbolCardData.gd
# Attach this script to a Resource, not to a scene node.
# It stores the player-facing information for one magical symbol card.
# Hidden symbol meanings are documented only in DeckManager.gd, where the
# starter card definitions are created.
extends Resource
class_name SymbolCardData


# Set this to the lowercase identifier used when building chant keys.
@export var symbol_id: String = ""

# Set this to the word shown in large text and spoken by the mage.
@export var spoken_word: String = ""

# Set this to the optional player-facing name of the symbol.
@export var display_name: String = ""

# Set this to a short placeholder mark shown on the graybox card.
@export var visual_hint: String = ""


# DeckManager calls this helper when it creates starter cards in code.
# Returning self keeps the card setup readable without requiring nine .tres files.
func configure(
	new_symbol_id: String,
	new_spoken_word: String,
	new_display_name: String,
	new_visual_hint: String
) -> SymbolCardData:
	symbol_id = new_symbol_id
	spoken_word = new_spoken_word
	display_name = new_display_name
	visual_hint = new_visual_hint
	return self
