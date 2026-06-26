extends Node

enum GameState {
	MAIN_MENU,
	OVERWORLD,
	COMBAT
}

var current_state: GameState = GameState.MAIN_MENU
var learned_chant_keys: Dictionary = {}
var session_cast_history: Array[Dictionary] = []
var first_combat_tutorial_completed: bool = false
var training_duel_won: bool = false

const SCENE_TRANSITION_NODE_PATH: String = "/root/SceneTransition"
const DEFAULT_SCENE_REGISTRY_PATH: String = "res://globals/resources/SceneRegistry_Default.tres"

@export var use_ink_transition: bool = true
@export var scene_registry: SceneRegistryData

var _loaded_scene_registry: SceneRegistryData


func go_to_main_menu() -> void:
	_change_state_and_scene(GameState.MAIN_MENU, _get_main_menu_scene())


func start_new_game() -> void:
	reset_session_progress()
	_change_state_and_scene(GameState.OVERWORLD, _get_overworld_scene())


func go_to_overworld() -> void:
	_change_state_and_scene(GameState.OVERWORLD, _get_overworld_scene())


func start_duel_from_overworld(combat_scene: PackedScene = null) -> void:
	if combat_scene != null:
		_change_state_and_scene(GameState.COMBAT, combat_scene)
		return
	_change_state_and_scene(GameState.COMBAT, _get_combat_scene())


func restart_combat() -> void:
	_change_state_and_scene(GameState.COMBAT, _get_combat_scene())


func quit_game() -> void:
	get_tree().quit()


func reset_session_progress() -> void:
	learned_chant_keys.clear()
	session_cast_history.clear()
	first_combat_tutorial_completed = false
	training_duel_won = false


func remember_learned_chant(chant_key: String) -> void:
	if chant_key.is_empty():
		return
	learned_chant_keys[chant_key] = true


func has_learned_chant(chant_key: String) -> bool:
	return learned_chant_keys.has(chant_key)


func get_learned_chant_keys_snapshot() -> Dictionary:
	return learned_chant_keys.duplicate(true)


func remember_cast_history_entry(entry: Dictionary) -> void:
	session_cast_history.append(entry.duplicate(true))


func replace_session_cast_history(entries: Array[Dictionary]) -> void:
	session_cast_history.clear()
	for entry: Dictionary in entries:
		session_cast_history.append(entry.duplicate(true))


func get_session_cast_history_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for entry: Dictionary in session_cast_history:
		snapshot.append(entry.duplicate(true))
	return snapshot


func _change_state_and_scene(next_state: GameState, scene: PackedScene) -> void:
	if scene == null:
		push_error("GameManager could not change scene; registry scene is missing.")
		return

	var scene_path := scene.resource_path
	var transition_node := get_node_or_null(SCENE_TRANSITION_NODE_PATH)

	if use_ink_transition and transition_node != null:
		if transition_node.has_method("is_busy"):
			var is_busy := bool(transition_node.call("is_busy"))
			if is_busy:
				return

	current_state = next_state

	if (
		use_ink_transition
		and not scene_path.is_empty()
		and transition_node != null
		and transition_node.has_method("transition_to_scene")
	):
		transition_node.call("transition_to_scene", scene_path)
		return

	var error := OK
	if scene_path.is_empty():
		error = get_tree().change_scene_to_packed(scene)
	else:
		error = get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("GameManager could not change scene to: " + scene_path)


func _get_main_menu_scene() -> PackedScene:
	var registry := _get_scene_registry()
	return registry.main_menu_scene if registry != null else null


func _get_overworld_scene() -> PackedScene:
	var registry := _get_scene_registry()
	return registry.overworld_scene if registry != null else null


func _get_combat_scene() -> PackedScene:
	var registry := _get_scene_registry()
	return registry.combat_scene if registry != null else null


func _get_scene_registry() -> SceneRegistryData:
	if scene_registry != null:
		return scene_registry
	if _loaded_scene_registry != null:
		return _loaded_scene_registry

	_loaded_scene_registry = load(DEFAULT_SCENE_REGISTRY_PATH) as SceneRegistryData
	if _loaded_scene_registry == null:
		push_error(
			"GameManager could not load SceneRegistryData at %s."
			% DEFAULT_SCENE_REGISTRY_PATH
		)
	return _loaded_scene_registry
