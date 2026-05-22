extends Node

@export var hero: Combatant
@export var enemy: Combatant

@onready var hero_hp_label: Label = $UI/HeroHP
@onready var enemy_hp_label: Label = $UI/EnemyHP
@onready var log_label: Label = $UI/Log
@onready var attack_button: Button = $UI/AttackButton
@onready var restart_button: Button = $UI/RestartButton
@onready var main_menu_button: Button = $UI/MainMenuButton

var combat_finished: bool = false

func _ready() -> void:
	randomize()
	attack_button.pressed.connect(_on_attack_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_manu_button_pressed)
	main_menu_button.visible = false
	restart_button.visible = false
	update_ui()
	log_label.text = "Combat started!"

func _on_attack_pressed() -> void:
	if combat_finished:
		return

	var hero_result: String = hero.attack(enemy)
	log_label.text = hero_result
	update_ui()

	if enemy.is_dead():
		end_combat("Victory! Enemy defeated.")
		return

	await get_tree().create_timer(0.6).timeout

	var enemy_result: String = enemy.attack(hero)
	log_label.text += "\n" + enemy_result
	update_ui()

	if hero.is_dead():
		end_combat("Defeat! Hero was defeated.")

func end_combat(message: String) -> void:
	combat_finished = true
	attack_button.disabled = true
	restart_button.visible = true
	main_menu_button.visible = true
	log_label.text += "\n" + message

func update_ui() -> void:
	hero_hp_label.text = "Hero HP: %d / %d" % [
		hero.current_hp,
		hero.max_hp
	]

	enemy_hp_label.text = "Enemy HP: %d / %d" % [
		enemy.current_hp,
		enemy.max_hp
	]

func _on_restart_pressed() -> void:
	GameManager.restart_combat()

func _on_main_manu_button_pressed() -> void:
	GameManager.go_to_main_menu()
