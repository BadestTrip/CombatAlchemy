extends RefCounted
class_name RuneSpellBuilder


signal combination_changed

const SLOT_BASE: StringName = &"base"
const SLOT_MOVEMENT: StringName = &"movement"
const SLOT_IMPACT: StringName = &"impact"

const INCOMPLETE_SPELL_NAME := "Заклинание не завершено"
const UNKNOWN_SPELL_NAME := "Неизвестное заклинание"

const SPELL_NAMES_BY_KEY: Dictionary = {
	"flame|forward|flame": "Огненный шар",
	"forward|flame|flame": "Огненный рывок",
	"forward|forward|forward": "Силовой таран",
	"flame|flame|flame": "Живое пламя",
}

var base_rune: RuneData
var movement_rune: RuneData
var impact_rune: RuneData


# Places or replaces a rune in the requested slot.
func set_rune(slot_id: StringName, rune: RuneData) -> void:
	match slot_id:
		SLOT_BASE:
			base_rune = rune
		SLOT_MOVEMENT:
			movement_rune = rune
		SLOT_IMPACT:
			impact_rune = rune
		_:
			push_warning("Unknown rune slot: %s" % String(slot_id))
			return

	combination_changed.emit()


func clear() -> void:
	base_rune = null
	movement_rune = null
	impact_rune = null
	combination_changed.emit()


func get_slot_rune(slot_id: StringName) -> RuneData:
	match slot_id:
		SLOT_BASE:
			return base_rune
		SLOT_MOVEMENT:
			return movement_rune
		SLOT_IMPACT:
			return impact_rune
	return null


# Returns the player-facing effect text for a rune in a concrete slot.
func get_slot_description(slot_id: StringName) -> String:
	var rune := get_slot_rune(slot_id)
	if rune == null:
		return "не выбрано."

	match slot_id:
		SLOT_BASE:
			return rune.base_description
		SLOT_MOVEMENT:
			return rune.movement_description
		SLOT_IMPACT:
			return rune.impact_description
	return "неизвестный слот."


func get_result_name() -> String:
	if not is_complete():
		return INCOMPLETE_SPELL_NAME

	var key := get_combination_key()
	return String(SPELL_NAMES_BY_KEY.get(key, UNKNOWN_SPELL_NAME))


func get_result_description() -> String:
	return "\n".join([
		"Основа: %s" % get_slot_description(SLOT_BASE),
		"Движение: %s" % get_slot_description(SLOT_MOVEMENT),
		"Попадание: %s" % get_slot_description(SLOT_IMPACT),
	])


func get_combination_key() -> String:
	var ids: PackedStringArray = []
	for slot_id: StringName in [SLOT_BASE, SLOT_MOVEMENT, SLOT_IMPACT]:
		var rune := get_slot_rune(slot_id)
		ids.append(String(rune.rune_id) if rune != null else "")
	return "|".join(ids)


func is_complete() -> bool:
	return base_rune != null and movement_rune != null and impact_rune != null
