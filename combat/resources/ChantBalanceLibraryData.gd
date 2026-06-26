# ChantBalanceLibraryData.gd
# Central numeric tuning for the active authored chants.
extends Resource
class_name ChantBalanceLibraryData


@export_group("Damage")
@export var razor_comet_damage: int = 7
@export var heavy_word_damage: int = 8

@export_group("Heal")
@export var holy_pigeon_heal: int = 3

@export_group("Shield")
@export var stone_halo_shield: int = 8

@export_group("OP")
@export var severed_thunder_damage: int = 12
@export_range(0.0, 1.0, 0.01) var severed_thunder_stun_chance: float = 1.0
@export var severed_thunder_stun_duration: int = 1

@export_group("Disaster")
@export var thunder_vomit_enemy_damage: int = 4
@export var thunder_vomit_self_damage: int = 2

@export_group("Funny")
@export var great_belly_confuse_duration: int = 1
