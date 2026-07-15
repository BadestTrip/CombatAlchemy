extends Node

# Responsibility: Persist audio settings and apply them to the project audio buses.

const CONFIG_PATH: String = "user://settings.cfg"
const AUDIO_SECTION: String = "audio"
const MUSIC_DB_KEY: String = "music_db"
const SFX_DB_KEY: String = "sfx_db"
const MUSIC_BUS_NAME: StringName = &"Music"
const SFX_BUS_NAME: StringName = &"SFX"
const MIN_VOLUME_DB: float = -80.0
const MAX_VOLUME_DB: float = 6.0

## Current Music bus volume in decibels.
var music_db: float = -6.0
## Current SFX bus volume in decibels.
var sfx_db: float = -6.0


func _ready() -> void:
	load_settings()
	apply_audio()


## Updates, applies, and saves the Music bus volume in decibels.
func set_music_db(value_db: float) -> void:
	music_db = clampf(value_db, MIN_VOLUME_DB, MAX_VOLUME_DB)
	apply_audio()
	save_settings()


## Updates, applies, and saves the SFX bus volume in decibels.
func set_sfx_db(value_db: float) -> void:
	sfx_db = clampf(value_db, MIN_VOLUME_DB, MAX_VOLUME_DB)
	apply_audio()
	save_settings()


## Applies the current values to the Music and SFX audio buses.
func apply_audio() -> void:
	_apply_bus_volume(MUSIC_BUS_NAME, music_db)
	_apply_bus_volume(SFX_BUS_NAME, sfx_db)


## Saves the current audio values to user://settings.cfg.
func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(AUDIO_SECTION, MUSIC_DB_KEY, music_db)
	config.set_value(AUDIO_SECTION, SFX_DB_KEY, sfx_db)

	var error: Error = config.save(CONFIG_PATH)
	if error != OK:
		push_error("Settings could not save %s (error %d)." % [CONFIG_PATH, error])


## Loads audio values from user://settings.cfg, retaining defaults when it does not exist.
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(CONFIG_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_warning("Settings could not load %s (error %d)." % [CONFIG_PATH, error])
		return

	music_db = float(config.get_value(AUDIO_SECTION, MUSIC_DB_KEY, music_db))
	sfx_db = float(config.get_value(AUDIO_SECTION, SFX_DB_KEY, sfx_db))


func _apply_bus_volume(bus_name: StringName, value_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("Settings could not find the %s audio bus." % bus_name)
		return

	AudioServer.set_bus_volume_db(bus_index, value_db)
	AudioServer.set_bus_mute(bus_index, value_db <= MIN_VOLUME_DB)
