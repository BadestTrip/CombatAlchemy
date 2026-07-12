extends Node
class_name RuneGrammarInterpreter

var _rune_catalog: Dictionary = {}


func _ready() -> void:
	_ensure_catalog()


func get_rune_catalog() -> Dictionary:
	_ensure_catalog()
	return _rune_catalog


func interpret(sequence: Array) -> SpellResultData:
	_ensure_catalog()

	var result := SpellResultData.new()
	result.set_sequence(sequence)

	if sequence.is_empty():
		result.display_name = "No Chant"
		result.generated_name = "No Chant"
		result.description = "Add runes before casting."
		return result

	var tags: Array[String] = []
	var power := 0
	for rune_id in sequence:
		var rune := _rune_catalog.get(str(rune_id)) as RuneData
		if rune == null:
			continue
		power += rune.base_power
		_add_tags(tags, rune.tags)

	var key := _sequence_key(sequence)
	match key:
		"ASHA":
			result.generated_name = "Kindled Spark"
			result.description = "A small source of heat gathers into a weak flame."
			_add_tags(tags, ["fire", "damage"])
		"ELUM":
			result.generated_name = "Quiet Ward"
			result.description = "A soft light gathers into a defensive shell."
			_add_tags(tags, ["shield", "protection", "ward", "light"])
		"ASHA,VORO":
			result.generated_name = "Moving Flame"
			result.description = "Fire is given motion and launched toward the target."
			_add_tags(tags, ["fire", "projectile", "damage"])
		"KETH,VORO,ASHA":
			result.generated_name = "Igniting Thrown Cut"
			result.description = "A thrown edge cuts first, then catches with delayed heat."
			_add_tags(tags, ["cut", "edge", "projectile", "fire", "damage"])
		_:
			result.generated_name = _build_generated_name(sequence)
			result.description = _build_generated_description(sequence)

	result.display_name = result.generated_name
	result.set_tags(tags)
	result.power = power
	return result


func _ensure_catalog() -> void:
	if not _rune_catalog.is_empty():
		return

	_rune_catalog = {
		"ASHA": RuneData.make("ASHA", "Asha", "source", "fire", ["source", "fire", "damage"], 2, 0),
		"VORO": RuneData.make("VORO", "Voro", "motion", "force", ["motion", "projectile"], 2, 1),
		"KETH": RuneData.make("KETH", "Keth", "edge", "metal", ["edge", "cut", "damage"], 2, 0),
		"ELUM": RuneData.make("ELUM", "Elum", "ward", "light", ["shield", "protection", "ward", "light"], 1, -1),
		"ZUN": RuneData.make("ZUN", "Zun", "shock", "storm", ["shock", "damage", "unstable"], 3, 2),
		"BAVO": RuneData.make("BAVO", "Bavo", "stone", "earth", ["stone", "shield"], 2, 0),
	}


func _build_generated_name(sequence: Array) -> String:
	var words := PackedStringArray()
	for rune_id in sequence:
		var rune := _rune_catalog.get(str(rune_id)) as RuneData
		if rune == null:
			words.append(str(rune_id).capitalize())
		else:
			words.append(rune.display_name)
	return " ".join(words)


func _build_generated_description(sequence: Array) -> String:
	if sequence.size() == 1:
		return "%s forms a simple effect." % str(sequence[0])
	return "The chant reads left to right, combining source, motion, shape, and risk."


func _add_tags(tags: Array[String], new_tags: Array) -> void:
	for tag in new_tags:
		var tag_string := str(tag)
		if not tags.has(tag_string):
			tags.append(tag_string)


func _sequence_key(sequence: Array) -> String:
	var parts := PackedStringArray()
	for rune_id in sequence:
		parts.append(str(rune_id))
	return ",".join(parts)
