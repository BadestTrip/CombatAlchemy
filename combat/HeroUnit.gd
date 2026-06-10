extends CombatUnit
class_name HeroUnit

@export var hero_class: StringName

var available_actions: Array[StringName] = []


func _ready() -> void:
	team = Team.HERO
	super._ready()
	add_to_group("heroes")
	_configure_actions()


func _configure_actions() -> void:
	match hero_class:
		&"warrior":
			available_actions = [&"strike", &"push"]
		&"hunter":
			available_actions = [&"shoot", &"cut_rope"]
		&"alchemist":
			available_actions = [&"ignite", &"throw_oil"]
		_:
			available_actions = []


func get_action_display_name(action_id: StringName) -> String:
	match action_id:
		&"strike":
			return "Strike"
		&"push":
			return "Push"
		&"shoot":
			return "Shoot"
		&"cut_rope":
			return "Cut Rope"
		&"ignite":
			return "Ignite"
		&"throw_oil":
			return "Throw Oil"
		_:
			return String(action_id).capitalize()
