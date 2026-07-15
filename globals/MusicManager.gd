extends AudioStreamPlayer

# Responsibility: Own scene music playback and crossfade between LevelMusic requests.

const MUSIC_BUS_NAME: StringName = &"Music"
const LEVEL_MUSIC_GROUP: StringName = &"level_music"
const FADE_FLOOR_DB: float = -30.0
const MIN_FADE_STEP_SECONDS: float = 0.01

## Target volume used when a caller does not provide a crossfade volume.
@export var default_volume_db: float = 0.0

var _crossfade_tween: Tween
var _loop_enabled: bool = true


func _enter_tree() -> void:
	bus = MUSIC_BUS_NAME
	process_mode = Node.PROCESS_MODE_ALWAYS
	finished.connect(_on_finished)

	var tree: SceneTree = get_tree()
	tree.tree_changed.connect(_apply_from_current_scene)
	tree.node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if not is_inside_tree():
		return
	if node.is_in_group(LEVEL_MUSIC_GROUP):
		call_deferred("_apply_from_current_scene")


func _on_finished() -> void:
	if not is_inside_tree() or stream == null or not _loop_enabled:
		return
	play(0.0)


func _apply_from_current_scene() -> void:
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return

	_apply_from(current_scene)


func _apply_from(root: Node) -> void:
	_silence_local_music_players(root)

	var level_music: LevelMusic = _find_level_music(root)
	if level_music == null:
		return

	var incoming_stream: AudioStream = level_music.get_music()
	if incoming_stream == null:
		return
	_apply_level_music_settings(level_music)

	crossfade_to(
		incoming_stream,
		level_music.get_crossfade(),
		level_music.get_volume_db()
	)


func _find_level_music(root: Node) -> LevelMusic:
	var candidates: Array[Node] = get_tree().get_nodes_in_group(LEVEL_MUSIC_GROUP)
	for candidate: Node in candidates:
		if not root.is_ancestor_of(candidate):
			continue
		if candidate is LevelMusic:
			return candidate as LevelMusic
		push_warning("MusicManager ignored a level_music node without the LevelMusic script.")
	return null


func _apply_level_music_settings(level_music: LevelMusic) -> void:
	_loop_enabled = level_music.get_loop()
	var requested_bus: StringName = level_music.get_bus()
	if AudioServer.get_bus_index(requested_bus) == -1:
		push_warning(
			"MusicManager could not find the %s bus; using %s instead."
			% [requested_bus, MUSIC_BUS_NAME]
		)
		bus = MUSIC_BUS_NAME
		return
	bus = requested_bus


func _kill_crossfade_tween() -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_crossfade_tween = null


## Crossfades to a non-null stream using the active LevelMusic loop and bus settings.
func crossfade_to(
	incoming_stream: AudioStream,
	duration: float = 1.0,
	target_volume_db: float = NAN
) -> void:
	if incoming_stream == null:
		push_warning("MusicManager cannot crossfade to a null AudioStream.")
		return
	var resolved_volume_db: float = (
		default_volume_db if is_nan(target_volume_db) else target_volume_db
	)
	if stream == incoming_stream and playing:
		volume_db = resolved_volume_db
		return

	var half_duration: float = maxf(MIN_FADE_STEP_SECONDS, duration * 0.5)
	_kill_crossfade_tween()
	_crossfade_tween = create_tween()
	_crossfade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_crossfade_tween.tween_property(self, "volume_db", FADE_FLOOR_DB, half_duration)
	_crossfade_tween.tween_callback(_start_stream.bind(incoming_stream))
	_crossfade_tween.tween_property(self, "volume_db", resolved_volume_db, half_duration)


func _start_stream(incoming_stream: AudioStream) -> void:
	stream = incoming_stream
	play()


func _silence_local_music_players(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current_node: Node = stack.pop_back()
		var children: Array[Node] = current_node.get_children()
		for child: Node in children:
			stack.append(child)
			if child is AudioStreamPlayer:
				var local_player: AudioStreamPlayer = child as AudioStreamPlayer
				if local_player != self and local_player.bus == MUSIC_BUS_NAME and local_player.playing:
					local_player.stop()
