# SpellRecipeData.gd
# Create this as a Resource and add it to ChantResolver's spell_recipes array.
# It stores one ordered chant, its player-facing result, and its effect resources.
extends Resource
class_name SpellRecipeData


# Order matters: asha_voro_keth is different from asha_keth_voro.
@export var chant_symbols: Array[String] = []

# This is the spell name shown in the combat log.
@export var result_name: String = ""

# This category is presentation/discovery data, not effect behavior.
@export_enum("workable", "disaster", "op", "funny", "fallback")
var result_type: String = "workable"

# Enable this to show the spell in a fresh runtime spellbook.
@export var initially_discovered: bool = false

# These fields are player-facing spellbook and discovery text.
@export_multiline var player_description: String = ""
@export_multiline var discovery_flavor_text: String = ""

# Effects run in array order.
@export var effects: Array[SpellEffectData] = []

# These optional assets are intentionally unused by the graybox MVP.
@export var optional_vfx_scene: PackedScene
@export var optional_sfx: AudioStream


# ChantResolver calls this while building its lookup dictionary.
func get_chant_key() -> String:
	return "_".join(chant_symbols)
