extends Node

# Responsibility: Route high-level game actions to registered scenes.

const SCENE_TRANSITION_NODE_PATH: String = "/root/SceneTransition"
const DEFAULT_SCENE_REGISTRY_PATH: String = "res://globals/resources/SceneRegistry_Default.tres"

## Whether registered scene changes should use SceneTransition when it is available.
@export var use_ink_transition: bool = true
## Optional registry override. The default registry is loaded when this is not assigned.
@export var scene_registry: SceneRegistryData

var _loaded_scene_registry: SceneRegistryData


## Starts a new game by loading the registered combat scene.
func start_new_game() -> void:
	_route_to_scene(_get_combat_scene(), "combat")


## Returns to the registered main menu scene.
func go_to_main_menu() -> void:
	_route_to_scene(_get_main_menu_scene(), "main menu")


## Requests a clean application shutdown from the active SceneTree.
func quit_game() -> void:
	get_tree().quit()


func _route_to_scene(scene: PackedScene, scene_label: String) -> void:
	if scene == null:
		push_error("GameManager could not route to %s; the registered scene is missing." % scene_label)
		return

	var scene_path: String = scene.resource_path
	var transition_node: Node = get_node_or_null(SCENE_TRANSITION_NODE_PATH)
	if _is_transition_busy(transition_node):
		return

	if _try_transition_to_scene(transition_node, scene_path):
		return

	var error: Error
	if scene_path.is_empty():
		error = get_tree().change_scene_to_packed(scene)
	else:
		error = get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error(
			"GameManager could not load the %s scene (error %d): %s"
			% [scene_label, error, scene_path]
		)


func _is_transition_busy(transition_node: Node) -> bool:
	return (
		use_ink_transition
		and transition_node != null
		and transition_node.has_method("is_busy")
		and bool(transition_node.call("is_busy"))
	)


func _try_transition_to_scene(transition_node: Node, scene_path: String) -> bool:
	if (
		not use_ink_transition
		or scene_path.is_empty()
		or transition_node == null
		or not transition_node.has_method("transition_to_scene")
	):
		return false

	transition_node.call("transition_to_scene", scene_path)
	return true


func _get_main_menu_scene() -> PackedScene:
	var registry: SceneRegistryData = _get_scene_registry()
	return registry.main_menu_scene if registry != null else null


func _get_combat_scene() -> PackedScene:
	var registry: SceneRegistryData = _get_scene_registry()
	return registry.combat_scene if registry != null else null


func _get_scene_registry() -> SceneRegistryData:
	if scene_registry != null:
		return scene_registry
	if _loaded_scene_registry != null:
		return _loaded_scene_registry

	var loaded_resource: Resource = load(DEFAULT_SCENE_REGISTRY_PATH)
	_loaded_scene_registry = loaded_resource as SceneRegistryData
	if _loaded_scene_registry == null:
		push_error(
			"GameManager could not load SceneRegistryData at %s."
			% DEFAULT_SCENE_REGISTRY_PATH
		)
	return _loaded_scene_registry
