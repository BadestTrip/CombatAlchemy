# SymbolCardData.gd
# Attach this script to a Resource, not to a scene node.
# It stores the player-facing information for one magical symbol card.
# SymbolLibraryData owns these resources so designers can edit them in Inspector.
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

# Keep hidden design meaning here for developers. The combat UI never shows it.
@export_multiline var developer_note: String = ""

# This is available for future rune presentation without changing effect logic.
@export var card_color: Color = Color.WHITE

# Optional prototype rune art used by the rune wheel. Final art can replace this
# in SymbolLibrary_Default.tres without rewriting UI logic.
@export var placeholder_icon: Texture2D


# Code fallbacks and tests may use this helper to create a symbol resource.
# Normal gameplay reads editable resources from SymbolLibrary_Default.tres.
func configure(
	new_symbol_id: String,
	new_spoken_word: String,
	new_display_name: String,
	new_visual_hint: String,
	new_developer_note: String = "",
	new_card_color: Color = Color.WHITE,
	new_placeholder_icon: Texture2D = null
) -> SymbolCardData:
	symbol_id = new_symbol_id
	spoken_word = new_spoken_word
	display_name = new_display_name
	visual_hint = new_visual_hint
	developer_note = new_developer_note
	card_color = new_card_color
	placeholder_icon = new_placeholder_icon
	return self
