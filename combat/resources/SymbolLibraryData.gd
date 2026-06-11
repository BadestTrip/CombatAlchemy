# SymbolLibraryData.gd
# Create this as a Resource and assign it to DeckManager in Inspector.
# It is the editable catalog used to build physical cards in the shared deck.
extends Resource
class_name SymbolLibraryData


# Add or reorder SymbolCardData resources here to change the shared symbol set.
@export var symbols: Array[SymbolCardData] = []
