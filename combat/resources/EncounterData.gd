extends Resource
class_name EncounterData


@export var encounter_id: String = ""
@export var display_name: String = ""
@export var enemy_name: String = "Enemy"

@export_group("Enemy Stats")
@export var enemy_max_hp: int = 15
@export var enemy_base_attack: int = 3
@export var enemy_starting_shield: int = 0
@export_range(0.0, 1.0, 0.01) var enemy_guard_chance: float = 0.25
@export var enemy_guard_shield: int = 3

@export_group("Presentation")
@export var enemy_sprite: Texture2D
@export var combat_music: AudioStream

@export_group("Tutorial")
@export var is_tutorial_fight: bool = false

@export_group("Session Flags")
@export var marks_training_duel_won: bool = false
@export var marks_miniboss_defeated: bool = false
