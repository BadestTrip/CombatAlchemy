extends Node

enum GameState {
	MAIN_MENU,
	COMBAT
}

const SCENE_TRANSITION_NODE_PATH: String = "/root/SceneTransition"
const DEFAULT_SCENE_REGISTRY_PATH: String = "res://globals/resources/SceneRegistry_Default.tres"

@export var use_ink_transition: bool = true
@export var scene_registry: SceneRegistryData

var current_state: GameState = GameState.MAIN_MENU

var _loaded_scene_registry: SceneRegistryData


func go_to_main_menu() -> void:
	_change_state_and_scene(GameState.MAIN_MENU, _get_main_menu_scene())


func start_new_game() -> void:
	_change_state_and_scene(GameState.COMBAT, _get_combat_scene())


func complete_combat(_victory: bool) -> void:
	current_state = GameState.COMBAT


func quit_game() -> void:
	get_tree().quit()


func _change_state_and_scene(next_state: GameState, scene: PackedScene) -> void:
	if scene == null:
		push_error("GameManager could not change scene; registry scene is missing.")
		return

	var scene_path := scene.resource_path
	var transition_node := get_node_or_null(SCENE_TRANSITION_NODE_PATH)

	if use_ink_transition and transition_node != null and transition_node.has_method("is_busy"):
		if bool(transition_node.call("is_busy")):
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
