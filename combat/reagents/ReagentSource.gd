class_name ReagentSource
extends Area2D

const COLLECTION_EFFECT := preload("res://combat/reagents/ReagentCollectionEffect.tscn")

@export var reagent: StringName = PotionReagent.RED
@export_range(1, 999, 1) var doses := 5
@onready var _prompt: Label = $Prompt
@onready var _deposit: Node2D = $Deposit

func _ready() -> void:
	_prompt.visible = false
	_deposit.set("color_id", reagent)

func can_collect() -> bool:
	return doses > 0
func set_prompt_visible(value: bool) -> void:
	_prompt.visible = value and can_collect()
func collect(profile: PlayerProfile, collector_position: Vector2 = global_position) -> int:
	if profile == null or not can_collect() or not profile.collect_reagent(reagent, doses): return 0
	var amount := doses
	doses = 0
	_deposit.visible = false
	_prompt.visible = false
	var effect := COLLECTION_EFFECT.instantiate()
	var effect_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if effect != null and effect_parent != null:
		effect_parent.add_child(effect)
		effect.play(global_position, collector_position, PotionReagent.get_color(reagent))
	return amount
