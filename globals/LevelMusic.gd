class_name LevelMusic
extends Node

# Responsibility: Describe the background music requested by a scene.

## Audio stream requested by this scene.
@export var music: AudioStream
## Target playback volume in decibels.
@export var volume_db: float = 0.0
## Total crossfade duration in seconds.
@export var crossfade: float = 0.8
## Loop preference exposed to music consumers.
@export var loop: bool = true
## Audio bus preference exposed to music consumers.
@export var bus: StringName = &"Music"


## Returns the scene's requested audio stream.
func get_music() -> AudioStream:
	return music


## Returns the scene's crossfade duration in seconds.
func get_crossfade() -> float:
	return crossfade


## Returns whether the scene requests looping playback.
func get_loop() -> bool:
	return loop


## Returns the scene's target playback volume in decibels.
func get_volume_db() -> float:
	return volume_db


## Returns the scene's requested audio bus.
func get_bus() -> StringName:
	return bus
