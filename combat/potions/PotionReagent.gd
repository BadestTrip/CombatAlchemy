class_name PotionReagent
extends RefCounted

# Responsibility: Define the supported potion reagents and their display colors.

const RED: StringName = &"red"
const GREEN: StringName = &"green"
const BLUE: StringName = &"blue"
const ALCHEMY_PALETTE: AlchemyPaletteData = preload(
	"res://shared/alchemy/ChargedNeonPalette.tres"
)


## Returns whether reagent is a supported potion reagent.
static func is_valid(reagent: StringName) -> bool:
	return reagent == RED or reagent == GREEN or reagent == BLUE


## Returns the display color for reagent, or white for an unknown reagent.
static func get_color(reagent: StringName) -> Color:
	return ALCHEMY_PALETTE.get_color(reagent)
