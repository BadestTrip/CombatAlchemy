extends Node

const CONFIG_PATH := "user://settings.cfg"

var music_db: float = -6.0
var sfx_db: float = -6.0

func _ready() -> void:
	load_settings()
	apply_audio()

func set_music_db(db: float) -> void:
	music_db = clamp(db, -80.0, 6.0)
	apply_audio()
	save_settings()

func set_sfx_db(db: float) -> void:
	sfx_db = clamp(db, -80.0, 6.0)
	apply_audio()
	save_settings()

func apply_audio() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, music_db)
		AudioServer.set_bus_mute(music_bus, music_db <= -80.0)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_db)
		AudioServer.set_bus_mute(sfx_bus, sfx_db <= -80.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_db", music_db)
	cfg.set_value("audio", "sfx_db", sfx_db)
	cfg.save(CONFIG_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		music_db = float(cfg.get_value("audio", "music_db", music_db))
		sfx_db   = float(cfg.get_value("audio", "sfx_db", sfx_db))
