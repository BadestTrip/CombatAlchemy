extends AudioStreamPlayer

@export var default_volume_db: float = 0.0
var _tween: Tween

func _enter_tree() -> void:
	bus = "Music"
	process_mode = Node.PROCESS_MODE_ALWAYS
	finished.connect(_on_finished)

	var tree: SceneTree = get_tree()
	tree.connect("tree_changed", Callable(self, "_apply_from_current_scene"))
	tree.connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(n: Node) -> void:
	# simple guard: if we're exiting, do nothing
	if !is_inside_tree():
		return
	if n.is_in_group("level_music"):
		# extra guard: only defer if we're still inside tree
		call_deferred("_apply_from_current_scene")

func _on_finished() -> void:
	# simple guard for shutdown
	if !is_inside_tree():
		return
	play(0.0)

func _apply_from_current_scene() -> void:
	# minimal, quit-safe guards:
	if !is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene == null:
		return
	_apply_from(scene)

func _apply_from(root: Node) -> void:
	_silence_local_music_players(root)

	var lm: LevelMusic = _find_level_music(root)
	if lm == null:
		return

	var stream_in: AudioStream = lm.get_music()
	if stream_in == null:
		return

	var xfade: float = lm.get_crossfade()
	var vol_db: float = lm.get_volume_db()

	crossfade_to(stream_in, xfade, vol_db)

func _find_level_music(root: Node) -> LevelMusic:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("level_music")
	for n: Node in nodes:
		if root.is_ancestor_of(n):
			return n as LevelMusic
	return null

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func crossfade_to(stream_in: AudioStream, duration: float = 1.0, to_db: float = default_volume_db) -> void:
	if stream_in == null:
		return
	if stream == stream_in and playing:
		volume_db = to_db
		return

	var half: float = maxf(0.01, duration * 0.5)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", -30.0, half)
	_tween.tween_callback(func() -> void:
		stream = stream_in
		play()
	)
	_tween.tween_property(self, "volume_db", to_db, half)

func _silence_local_music_players(root: Node) -> void:
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var children: Array[Node] = n.get_children()
		for ch: Node in children:
			stack.push_back(ch)
			if ch is AudioStreamPlayer:
				var p: AudioStreamPlayer = ch as AudioStreamPlayer
				if p != self and p.bus == "Music" and p.playing:
					p.stop()
