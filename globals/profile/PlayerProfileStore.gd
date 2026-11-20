class_name PlayerProfileStore
extends RefCounted

const VERSION := 2
const DEFAULT_PATH := "user://player_profile.cfg"
var profile_path: String
var last_error := ""

func _init(path := DEFAULT_PATH) -> void:
	profile_path = path

func load_snapshot() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(profile_path):
		if FileAccess.file_exists(_backup_path()):
			var backup_only := _read(_backup_path())
			if not backup_only.is_empty():
				return {"ok": true, "snapshot": backup_only}
			last_error = "Player profile backup could not be loaded. Existing files were preserved."
			return {"ok": false}
		return {"ok": true, "snapshot": _empty_snapshot()}
	var snapshot := _read(profile_path)
	if not snapshot.is_empty():
		return {"ok": true, "snapshot": snapshot}
	var backup := _read(_backup_path())
	if not backup.is_empty():
		return {"ok": true, "snapshot": backup}
	last_error = "Player profile could not be loaded. Existing files were preserved."
	return {"ok": false}

func save_snapshot(snapshot: Dictionary) -> bool:
	last_error = ""
	var quality_score: Variant = snapshot.held.get("quality_score", 0)
	var potency_multiplier: Variant = snapshot.held.get("potency_multiplier", 1.0)
	if not PotionQualityProfileData.is_valid_quality(quality_score, potency_multiplier):
		last_error = "Player profile potion quality is invalid."
		return false
	var config := ConfigFile.new()
	config.set_value("profile", "version", VERSION)
	for reagent in [PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE]:
		config.set_value("reagents", String(reagent), int(snapshot.totals.get(reagent, 0)))
	config.set_value("held", "recipe_id", String(snapshot.held.get("recipe_id", "")))
	var saved_layers := PackedStringArray()
	for layer in snapshot.held.get("layers", []):
		saved_layers.append(String(layer))
	config.set_value("held", "layers", saved_layers)
	config.set_value("held", "quality_score", quality_score)
	config.set_value("held", "potency_multiplier", float(potency_multiplier))
	if config.save(_temp_path()) != OK or _read(_temp_path()).is_empty():
		last_error = "Player profile could not be written."
		return false
	if FileAccess.file_exists(profile_path) and not _read(profile_path).is_empty():
		if not _copy_file(profile_path, _backup_temp_path()) or _read(_backup_temp_path()).is_empty():
			last_error = "Player profile backup could not be written."
			return false
		var backup_old_path := _backup_path() + ".old"
		_remove_if_exists(backup_old_path)
		if FileAccess.file_exists(_backup_path()) and not _rename(_backup_path(), backup_old_path):
			last_error = "Player profile could not preserve its previous backup."
			return false
		if not _rename(_backup_temp_path(), _backup_path()):
			if FileAccess.file_exists(backup_old_path):
				_rename(backup_old_path, _backup_path())
			last_error = "Player profile backup could not be activated."
			return false
		if _read(_backup_path()).is_empty():
			_remove_if_exists(_backup_path())
			if FileAccess.file_exists(backup_old_path):
				_rename(backup_old_path, _backup_path())
			last_error = "Player profile backup verification failed."
			return false
		_remove_if_exists(backup_old_path)
	var old_path := profile_path + ".old"
	_remove_if_exists(old_path)
	if FileAccess.file_exists(profile_path) and not _rename(profile_path, old_path):
		last_error = "Player profile could not preserve its previous save."
		return false
	if not _rename(_temp_path(), profile_path):
		if FileAccess.file_exists(old_path): _rename(old_path, profile_path)
		last_error = "Player profile could not replace its previous save."
		return false
	if _read(profile_path).is_empty():
		_remove_if_exists(profile_path)
		if FileAccess.file_exists(old_path): _rename(old_path, profile_path)
		last_error = "Player profile verification failed."
		return false
	_remove_if_exists(old_path)
	return true

static func delete_test_files(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp", ".bak.old", ".old"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(absolute)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {}
	var version: Variant = config.get_value("profile", "version", -1)
	if typeof(version) != TYPE_INT or version not in [1, VERSION]:
		return {}
	var quality_score: Variant = 0
	var potency_multiplier: Variant = 1.0
	if version == VERSION:
		if not config.has_section_key("held", "quality_score") or not config.has_section_key("held", "potency_multiplier"):
			return {}
		quality_score = config.get_value("held", "quality_score")
		potency_multiplier = config.get_value("held", "potency_multiplier")
	if not PotionQualityProfileData.is_valid_quality(quality_score, potency_multiplier):
		return {}
	var totals: Dictionary = {}
	for reagent in [PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE]:
		totals[reagent] = max(0, int(config.get_value("reagents", String(reagent), 0)))
	var layers: Array[StringName] = []
	for value in config.get_value("held", "layers", []):
		layers.append(StringName(value))
	return {"totals": totals, "held": {
		"recipe_id": StringName(config.get_value("held", "recipe_id", "")),
		"layers": layers,
		"quality_score": quality_score,
		"potency_multiplier": float(potency_multiplier),
	}}

func _empty_snapshot() -> Dictionary:
	return {"totals": {PotionReagent.RED: 0, PotionReagent.GREEN: 0, PotionReagent.BLUE: 0}, "held": {}}
func _temp_path() -> String: return profile_path + ".tmp"
func _backup_path() -> String: return profile_path + ".bak"
func _backup_temp_path() -> String: return profile_path + ".bak.tmp"

func _copy_file(from: String, to: String) -> bool:
	var source := FileAccess.open(from, FileAccess.READ)
	var target := FileAccess.open(to, FileAccess.WRITE)
	if source == null or target == null: return false
	target.store_buffer(source.get_buffer(source.get_length()))
	target = null
	source = null
	return true

func _rename(from: String, to: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)) == OK

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
