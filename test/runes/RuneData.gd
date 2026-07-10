extends Resource
class_name RuneData


# Data-only description of a rune. The UI reads these fields, but does not own
# the spell rules itself.
@export var rune_id: StringName
@export var display_name: String = ""
@export_multiline var base_description: String = ""
@export_multiline var movement_description: String = ""
@export_multiline var impact_description: String = ""
@export var rune_color: Color = Color.WHITE
