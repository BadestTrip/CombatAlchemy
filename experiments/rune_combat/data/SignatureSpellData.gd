extends Resource
class_name SignatureSpellData

@export var id: String = ""
@export var display_name: String = ""
@export var rune_sequence: Array[String] = []
@export var tags: Array[String] = []
@export var description: String = ""
@export var power_modifier: int = 0
@export var instability_modifier: int = 0


static func make(
		p_id: String,
		p_display_name: String,
		p_rune_sequence: Array,
		p_tags: Array,
		p_description: String,
		p_power_modifier: int,
		p_instability_modifier: int = 0
) -> SignatureSpellData:
	var data := SignatureSpellData.new()
	data.id = p_id
	data.display_name = p_display_name
	data.rune_sequence = []
	for rune_id in p_rune_sequence:
		data.rune_sequence.append(str(rune_id))
	data.tags = []
	for tag in p_tags:
		data.tags.append(str(tag))
	data.description = p_description
	data.power_modifier = p_power_modifier
	data.instability_modifier = p_instability_modifier
	return data
