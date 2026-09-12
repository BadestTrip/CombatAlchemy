@tool
class_name AlchemyPaletteData
extends Resource

# Responsibility: Provide the shared semantic colors used by alchemy UI and VFX.

const RED: StringName = &"red"
const GREEN: StringName = &"green"
const BLUE: StringName = &"blue"
const HEALTH: StringName = &"health"
const DAMAGE: StringName = &"damage"

## Charged color for the red reagent family.
@export var red_color: Color = Color("ff2e50")
## Charged color for the green reagent family.
@export var green_color: Color = Color("9cff38")
## Charged color for the blue reagent family.
@export var blue_color: Color = Color("29d9ff")
## Prepared health-potion color.
@export var health_color: Color = Color("ff3bd4")
## Prepared damage-potion color.
@export var damage_color: Color = Color("20f5d0")


## Returns the configured semantic color, or white for an unknown identifier.
func get_color(color_id: StringName) -> Color:
	match color_id:
		RED:
			return red_color
		GREEN:
			return green_color
		BLUE:
			return blue_color
		HEALTH:
			return health_color
		DAMAGE:
			return damage_color
		_:
			return Color.WHITE
