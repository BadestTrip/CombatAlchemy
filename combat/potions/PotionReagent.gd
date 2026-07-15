class_name PotionReagent
extends RefCounted

# Responsibility: Define the supported potion reagents and their display colors.

const RED: StringName = &"red"
const GREEN: StringName = &"green"
const BLUE: StringName = &"blue"


## Returns whether reagent is a supported potion reagent.
static func is_valid(reagent: StringName) -> bool:
	return reagent == RED or reagent == GREEN or reagent == BLUE


## Returns the display color for reagent, or white for an unknown reagent.
static func get_color(reagent: StringName) -> Color:
	match reagent:
		RED:
			return Color(0.9, 0.16, 0.2)
		GREEN:
			return Color(0.2, 0.78, 0.35)
		BLUE:
			return Color(0.15, 0.45, 0.95)
		_:
			return Color.WHITE
