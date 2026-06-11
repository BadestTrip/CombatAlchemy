extends Node

enum GameState {
	MAIN_MENU,
	COMBAT
}

var current_state: GameState = GameState.MAIN_MENU

const START_MENU_SCENE: String = "res://mainmenu/StartMenu.tscn"
const COMBAT_SCENE: String = "res://combat/CombatScene.tscn"

const SCENE_TRANSITION_NODE_PATH: String = "/root/SceneTransition"

@export var use_ink_transition: bool = true


func go_to_main_menu() -> void:
	_change_state_and_scene(GameState.MAIN_MENU, START_MENU_SCENE)


func start_new_game() -> void:
	_change_state_and_scene(GameState.COMBAT, COMBAT_SCENE)


func restart_combat() -> void:
	_change_state_and_scene(GameState.COMBAT, COMBAT_SCENE)


func quit_game() -> void:
	get_tree().quit()


func _change_state_and_scene(next_state: GameState, scene_path: String) -> void:
	var transition_node := get_node_or_null(SCENE_TRANSITION_NODE_PATH)

	if use_ink_transition and transition_node != null:
		if transition_node.has_method("is_busy"):
			var is_busy := bool(transition_node.call("is_busy"))
			if is_busy:
				return

	current_state = next_state

	if use_ink_transition and transition_node != null and transition_node.has_method("transition_to_scene"):
		transition_node.call("transition_to_scene", scene_path)
		return

	var error := get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("GameManager could not change scene to: " + scene_path)
