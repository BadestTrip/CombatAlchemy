extends Node

enum GameState {
	MAIN_MENU,
	COMBAT
}

var current_state: GameState = GameState.MAIN_MENU

const START_MENU_SCENE: String = "res://scenes/start_menu.tscn"
const COMBAT_TEST_SCENE: String = "res://scenes/combat_test.tscn"


func go_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	get_tree().change_scene_to_file(START_MENU_SCENE)


func start_new_game() -> void:
	current_state = GameState.COMBAT
	get_tree().change_scene_to_file(COMBAT_TEST_SCENE)


func restart_combat() -> void:
	current_state = GameState.COMBAT
	get_tree().change_scene_to_file(COMBAT_TEST_SCENE)


func quit_game() -> void:
	get_tree().quit()
