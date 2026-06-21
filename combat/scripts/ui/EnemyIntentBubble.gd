extends Control
class_name EnemyIntentBubble


@export var enemy_unit: EnemyUnit
@export var intent_label: Label
@export var offset: Vector2 = Vector2(0.0, -180.0)


func _ready() -> void:
	set_process(false)
	if intent_label == null:
		intent_label = find_child("IntentLabel", true, false) as Label
	if enemy_unit != null:
		bind_enemy(enemy_unit)


func bind_enemy(enemy: EnemyUnit) -> void:
	enemy_unit = enemy
	if enemy_unit == null:
		visible = false
		return

	visible = true
	if not enemy_unit.intent_generated.is_connected(_on_intent_generated):
		enemy_unit.intent_generated.connect(_on_intent_generated)
	if enemy_unit.has_signal("intent_changed") and not enemy_unit.intent_changed.is_connected(_on_intent_changed):
		enemy_unit.intent_changed.connect(_on_intent_changed)
	refresh_intent()


func refresh_intent() -> void:
	if intent_label == null:
		return
	if enemy_unit == null or not enemy_unit.is_alive:
		intent_label.text = "No intent"
		return

	var description := String(enemy_unit.current_intent.get("description", "No intent"))
	intent_label.text = description


func _on_intent_generated(_unit: EnemyUnit, _intent: Dictionary) -> void:
	refresh_intent()


func _on_intent_changed() -> void:
	refresh_intent()
