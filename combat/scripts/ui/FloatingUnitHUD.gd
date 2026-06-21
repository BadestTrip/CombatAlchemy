extends Control
class_name FloatingUnitHUD


@export_group("Target")
@export var target_unit: Node
@export var offset: Vector2 = Vector2(0.0, -120.0)

@export_group("Node References")
@export var name_label: Label
@export var hp_bar: ProgressBar
@export var shield_label: Label

@export_group("Update")
@export var use_signal_updates: bool = true


func _ready() -> void:
	set_process(false)
	_resolve_nodes()
	if target_unit != null:
		bind_unit(target_unit)


func bind_unit(unit: Node) -> void:
	target_unit = unit
	_resolve_nodes()
	if target_unit == null:
		visible = false
		return

	visible = true
	if use_signal_updates:
		_connect_signal_if_present(&"stats_changed", Callable(self, "refresh"))
		_connect_signal_if_present(&"died", Callable(self, "refresh"))
		_connect_signal_if_present(&"unit_damaged", Callable(self, "_on_unit_stat_signal"))
		_connect_signal_if_present(&"unit_healed", Callable(self, "_on_unit_stat_signal"))
		_connect_signal_if_present(&"unit_shield_changed", Callable(self, "_on_unit_stat_signal"))
		_connect_signal_if_present(&"unit_died", Callable(self, "_on_unit_stat_signal"))
	refresh()


func refresh() -> void:
	if target_unit == null:
		return

	var unit_name := _get_unit_name()
	var current_hp := int(target_unit.get("current_hp"))
	var max_hp := maxi(1, int(target_unit.get("max_hp")))
	var shield := int(target_unit.get("shield"))
	var is_alive := bool(target_unit.get("is_alive"))

	if name_label != null:
		name_label.text = unit_name
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = clampi(current_hp, 0, max_hp)
	if shield_label != null:
		shield_label.text = "Shield %d" % shield if shield > 0 else "No Shield"
	set_visible_for_alive_state()
	modulate = Color(1, 1, 1, 1) if is_alive else Color(0.5, 0.5, 0.5, 1)


func set_visible_for_alive_state() -> void:
	if target_unit == null:
		return
	visible = true


func _resolve_nodes() -> void:
	if name_label == null:
		name_label = find_child("NameLabel", true, false) as Label
	if hp_bar == null:
		hp_bar = find_child("HPBar", true, false) as ProgressBar
	if shield_label == null:
		shield_label = find_child("ShieldLabel", true, false) as Label


func _connect_signal_if_present(signal_name: StringName, callback: Callable) -> void:
	if target_unit == null or not target_unit.has_signal(signal_name):
		return
	if not target_unit.is_connected(signal_name, callback):
		target_unit.connect(signal_name, callback)


func _on_unit_stat_signal(_unit: Node, _value: Variant = null) -> void:
	refresh()


func _get_unit_name() -> String:
	if target_unit is MageUnit:
		return (target_unit as MageUnit).mage_name
	if target_unit is EnemyUnit:
		return (target_unit as EnemyUnit).enemy_name
	return target_unit.name
