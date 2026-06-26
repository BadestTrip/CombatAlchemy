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

const START_MENU_SCENE: String = "res://mainmenu/StartMenu.tscn"
const OVERWORLD_SCENE_PATH: String = "res://overworld/OverworldPrototype.tscn"
const COMBAT_SCENE_PATH: String = "res://combat/CombatScene.tscn"

const SCENE_TRANSITION_NODE_PATH: String = "/root/SceneTransition"

@export var use_ink_transition: bool = true


func go_to_main_menu() -> void:
	_change_state_and_scene(GameState.MAIN_MENU, START_MENU_SCENE)


func start_new_game() -> void:
	reset_session_progress()
	_change_state_and_scene(GameState.OVERWORLD, OVERWORLD_SCENE_PATH)


func go_to_overworld() -> void:
	_change_state_and_scene(GameState.OVERWORLD, OVERWORLD_SCENE_PATH)


func start_duel_from_overworld() -> void:
	_change_state_and_scene(GameState.COMBAT, COMBAT_SCENE_PATH)


func restart_combat() -> void:
	_change_state_and_scene(GameState.COMBAT, COMBAT_SCENE_PATH)


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
