extends Node
class_name SignatureSpellResolver

var _signatures: Dictionary = {}


func _ready() -> void:
	_ensure_signatures()


func find_signature(sequence: Array) -> SignatureSpellData:
	_ensure_signatures()
	return _signatures.get(_sequence_key(sequence)) as SignatureSpellData


func _ensure_signatures() -> void:
	if not _signatures.is_empty():
		return

	_signatures = {
		"ASHA,VORO,KETH": SignatureSpellData.make(
			"razor_comet",
			"Razor Comet",
			["ASHA", "VORO", "KETH"],
			["signature", "fire", "projectile", "edge", "cut", "damage"],
			"A burning blade is accelerated into a clean comet strike.",
			5,
			1
		),
		"ELUM,BAVO,VORO": SignatureSpellData.make(
			"stone_halo",
			"Stone Halo",
			["ELUM", "BAVO", "VORO"],
			["signature", "shield", "stone", "protection", "ward"],
			"Stone and light orbit the caster as a moving halo.",
			3,
			0
		),
		"ZUN,ZUN,ZUN": SignatureSpellData.make(
			"thunder_vomit",
			"Thunder Vomit",
			["ZUN", "ZUN", "ZUN"],
			["signature", "shock", "damage", "unstable"],
			"A deeply unsafe surge dumps storm energy in a violent burst.",
			-4,
			4
		),
	}


func _sequence_key(sequence: Array) -> String:
	var parts := PackedStringArray()
	for rune_id in sequence:
		parts.append(str(rune_id))
	return ",".join(parts)
