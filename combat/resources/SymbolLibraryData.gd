# SymbolLibraryData.gd
# Create this as a Resource and assign it to CombatUIController in Inspector.
# It is the editable catalog used to build the full rune palette.
extends Resource
class_name SymbolLibraryData


# Add or reorder SymbolCardData resources here to change the rune set.
@export var symbols: Array[SymbolCardData] = []
