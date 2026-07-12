extends Resource
class_name RuneData

@export var id: String = ""
@export var display_name: String = ""
@export var role: String = ""
@export var element: String = ""
@export var tags: Array[String] = []
@export var base_power: int = 1
@export var instability_modifier: int = 0


static func make(
		p_id: String,
		p_display_name: String,
		p_role: String,
		p_element: String,
		p_tags: Array,
		p_base_power: int,
		p_instability_modifier: int = 0
) -> RuneData:
	var data := RuneData.new()
	data.id = p_id
	data.display_name = p_display_name
	data.role = p_role
	data.element = p_element
	data.tags = []
	for tag in p_tags:
		data.tags.append(str(tag))
	data.base_power = p_base_power
	data.instability_modifier = p_instability_modifier
	return data
