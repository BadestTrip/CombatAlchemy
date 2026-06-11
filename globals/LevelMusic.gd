extends Node
class_name LevelMusic

@export var music: AudioStream
@export var volume_db: float = 0.0
@export var crossfade: float = 0.8
@export var loop: bool = true
@export var bus: StringName = &"Music"

func get_music() -> AudioStream:
	return music
func get_crossfade() -> float: 
	return crossfade
func get_loop() -> bool: 
	return loop
func get_volume_db(): 
	return volume_db
func get_bus() -> StringName: 
	return bus
