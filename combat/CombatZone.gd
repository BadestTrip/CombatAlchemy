extends PanelContainer
class_name CombatZone

signal hazard_added(zone: CombatZone, hazard_id: StringName)

@export var zone_id: StringName
@export var display_name: String

var units: Array[CombatUnit] = []
var reaction_objects: Array[ReactionObject] = []
var hazards: Array[StringName] = []
var adjacent_zones: Array[CombatZone] = []

var _units_label: Label
var _objects_label: Label
var _hazards_label: Label


func _ready() -> void:
	add_to_group("combat_zones")
	custom_minimum_size = Vector2(230.0, 180.0)
	_build_placeholder_visuals()
	refresh_display()


func set_adjacent_zones(zones: Array[CombatZone]) -> void:
	adjacent_zones = zones


func is_adjacent_to(other_zone: CombatZone) -> bool:
	return other_zone != null and adjacent_zones.has(other_zone)


func can_enter() -> bool:
	return not has_hazard(&"collapsed")


func add_unit(unit: CombatUnit) -> void:
	if unit != null and not units.has(unit):
		units.append(unit)
		refresh_display()


func remove_unit(unit: CombatUnit) -> void:
	units.erase(unit)
	refresh_display()


func add_object(object: ReactionObject) -> void:
	if object != null and not reaction_objects.has(object):
		reaction_objects.append(object)
		refresh_display()


func remove_object(object: ReactionObject) -> void:
	reaction_objects.erase(object)
	refresh_display()


func add_hazard(hazard_id: StringName) -> void:
	if hazard_id == &"" or hazards.has(hazard_id):
		return
	hazards.append(hazard_id)
	hazard_added.emit(self, hazard_id)
	refresh_display()


func remove_hazard(hazard_id: StringName) -> void:
	hazards.erase(hazard_id)
	refresh_display()


func has_hazard(hazard_id: StringName) -> bool:
	return hazards.has(hazard_id)


func get_units() -> Array[CombatUnit]:
	return units.duplicate()


func get_reaction_objects() -> Array[ReactionObject]:
	return reaction_objects.duplicate()


func get_living_units() -> Array[CombatUnit]:
	var living: Array[CombatUnit] = []
	for unit: CombatUnit in units:
		if unit.is_alive:
			living.append(unit)
	return living


func refresh_display() -> void:
	if _units_label == null:
		return

	var unit_lines: PackedStringArray = []
	for unit: CombatUnit in units:
		if unit.is_alive:
			var team_marker := "H" if unit.team == CombatUnit.Team.HERO else "E"
			unit_lines.append("[%s] %s  %d/%d HP" % [
				team_marker,
				unit.unit_name,
				unit.current_hp,
				unit.max_hp
			])
	_units_label.text = "Units: -"
	if not unit_lines.is_empty():
		_units_label.text = "Units:\n" + "\n".join(unit_lines)

	var object_lines: PackedStringArray = []
	for object: ReactionObject in reaction_objects:
		if not object.is_destroyed:
			object_lines.append(object.display_name)
	_objects_label.text = "Objects: -"
	if not object_lines.is_empty():
		_objects_label.text = "Objects: " + ", ".join(object_lines)

	var hazard_names: PackedStringArray = []
	for hazard: StringName in hazards:
		hazard_names.append(String(hazard).capitalize())
	_hazards_label.text = "Hazards: -"
	if not hazard_names.is_empty():
		_hazards_label.text = "Hazards: " + ", ".join(hazard_names)

	modulate = Color(0.58, 0.58, 0.58) if has_hazard(&"collapsed") else Color.WHITE


func _build_placeholder_visuals() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.17, 0.16, 0.96)
	style.border_color = Color(0.48, 0.42, 0.28)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var title := Label.new()
	title.text = display_name
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.38))
	content.add_child(title)

	_units_label = Label.new()
	_units_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_units_label)

	_objects_label = Label.new()
	_objects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objects_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.98))
	content.add_child(_objects_label)

	_hazards_label = Label.new()
	_hazards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hazards_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.28))
	content.add_child(_hazards_label)
