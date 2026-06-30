extends Resource
class_name RuneLoadoutData

@export var active_runes: Array[String] = ["ASHA", "VORO", "KETH", "ELUM", "ZUN"]
@export var max_chant_length: int = 5


func get_active_runes() -> Array[String]:
	var copy: Array[String] = []
	for rune_id in active_runes:
		copy.append(rune_id)
	return copy
