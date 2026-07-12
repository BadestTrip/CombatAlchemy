extends Resource
class_name SpellResultData

@export var rune_sequence: Array[String] = []
@export var generated_name: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var tags: Array[String] = []
@export var is_signature: bool = false
@export var signature_id: String = ""
@export var instability_score: int = 0
@export var instability_label: String = "Stable"
@export var power: int = 0
@export var damage: int = 0
@export var shield: int = 0
@export var affects_enemy: bool = false
@export var affects_self: bool = false
@export var effect_type: String = "projectile"
@export var effect_color: Color = Color.WHITE
@export var effect_speed: float = 650.0
@export var effect_radius: float = 8.0
@export var effect_lifetime: float = 0.9
@export var effect_kind: String = "none"
@export var effect_template: ChantEffectTemplateData
@export var projectile_speed: float = 420.0
@export var projectile_lifetime: float = 1.0
@export var projectile_size: float = 10.0


func set_sequence(sequence: Array) -> void:
	rune_sequence = []
	for rune_id in sequence:
		rune_sequence.append(str(rune_id))


func set_tags(new_tags: Array) -> void:
	tags = []
	for tag in new_tags:
		var tag_string := str(tag)
		if not tags.has(tag_string):
			tags.append(tag_string)


func has_tag(tag: String) -> bool:
	return tags.has(tag)
