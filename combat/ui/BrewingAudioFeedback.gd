class_name BrewingAudioFeedback
extends Node

# Responsibility: Present brewing state through replaceable SFX streams.

@onready var _fire_loop: AudioStreamPlayer = $FireLoop
@onready var _boil_loop: AudioStreamPlayer = $BoilLoop

var _fire_active := false
var _heating := false
var _suspended := false
var _power := 0.0
var _height := 0.0


func _ready() -> void:
	_fire_loop.finished.connect(_refresh_loops)
	_boil_loop.finished.connect(_refresh_loops)


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()


func set_fire_state(active: bool, power: float) -> void:
	_fire_active = active
	_power = clampf(power, 0.0, 1.0)
	_refresh_loops()


func set_heating(active: bool, height: float, power: float) -> void:
	_heating = active
	_height = clampf(height, 0.0, 1.0)
	_power = clampf(power, 0.0, 1.0)
	_refresh_loops()


func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	_refresh_loops()


func play_release(score: int) -> void:
	var player: AudioStreamPlayer
	match clampi(score, -1, 1):
		-1:
			player = $ReleaseBad
		0:
			player = $ReleaseNormal
		1:
			player = $ReleasePerfect
	if player != null and not _suspended:
		player.play()


func play_perfect_brew() -> void:
	if not _suspended:
		$PerfectBrew.play()


func _refresh_loops() -> void:
	_fire_loop.volume_db = lerpf(-22.0, -10.0, _power)
	_boil_loop.volume_db = lerpf(-24.0, -7.0, _height)
	_boil_loop.pitch_scale = lerpf(0.85, 1.2, _height)
	_set_loop_playing(_fire_loop, _fire_active and _power > 0.0 and not _suspended)
	_set_loop_playing(
		_boil_loop,
		_fire_active and _heating and _power > 0.0 and not _suspended
	)


func _set_loop_playing(player: AudioStreamPlayer, should_play: bool) -> void:
	if should_play:
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()
