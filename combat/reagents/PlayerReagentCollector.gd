class_name PlayerReagentCollector
extends Node

signal collection_failed(message: String)

@export var collection_area_path: NodePath = ^"CollectionArea"
var _profile: PlayerProfile
var _area: Area2D
var _current: ReagentSource
func _ready() -> void:
	_area = get_node_or_null(collection_area_path) as Area2D
func configure(profile: PlayerProfile) -> void: _profile = profile
func _process(_delta: float) -> void:
	if get_tree().paused or _area == null: return
	var sources: Array[ReagentSource] = []
	for area in _area.get_overlapping_areas():
		var source := area as ReagentSource
		if source != null and source.can_collect(): sources.append(source)
	var best := select_nearest_source(sources)
	if best != _current:
		if _current != null: _current.set_prompt_visible(false)
		_current = best
		if _current != null: _current.set_prompt_visible(true)

func select_nearest_source(sources: Array[ReagentSource]) -> ReagentSource:
	var best: ReagentSource
	var origin := _area.global_position if _area != null else Vector2.ZERO
	var best_distance := INF
	for source in sources:
		if source == null or not source.can_collect(): continue
		var distance := source.global_position.distance_squared_to(origin)
		if best == null or distance < best_distance or (is_equal_approx(distance, best_distance) and String(source.get_path()) < String(best.get_path())):
			best = source
			best_distance = distance
	return best
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed(&"collect_reagent") and _current != null:
		var collected := _current.collect(_profile, _area.global_position if _area != null else Vector2.ZERO)
		if collected == 0 and _profile != null and not _profile.last_error.is_empty():
			collection_failed.emit(_profile.last_error)
		_current = null
		get_viewport().set_input_as_handled()
