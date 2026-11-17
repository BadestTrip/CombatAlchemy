extends Node

# Responsibility: Verify scene-backed status presentation and compatible actor wiring.

const STATUS_BAR_SCENE_PATH := "res://combat/actors/ActorStatusBar.tscn"
const STATUS_COMPONENT_SCRIPT_PATH := "res://combat/actors/StatusEffectComponent.gd"
const ACTOR_SCENE_PATHS := [
	"res://combat/actors/PlayerActor.tscn",
	"res://combat/actors/TargetActor.tscn",
	"res://combat/enemies/Pursuer.tscn",
	"res://combat/enemies/Skirmisher.tscn",
]

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	_test_status_bar_scene()
	_test_compatible_actor_wiring()
	for failure in _failures:
		push_error(failure)
	print("StatusPresentationTests: %s (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_status_bar_scene() -> void:
	_expect(ResourceLoader.exists(STATUS_BAR_SCENE_PATH), "ActorStatusBar scene exists")
	if not ResourceLoader.exists(STATUS_BAR_SCENE_PATH):
		return
	var scene := load(STATUS_BAR_SCENE_PATH) as PackedScene
	var bar := scene.instantiate() if scene != null else null
	_expect(bar != null, "ActorStatusBar scene instantiates")
	if bar == null:
		return
	_expect(bar.has_method(&"set_statuses"), "ActorStatusBar exposes set_statuses")
	for slot_index in range(1, 5):
		_expect(bar.get_node_or_null("StatusSlot%d" % slot_index) != null, "ActorStatusBar has fixed status slot %d" % slot_index)
	bar.free()


func _test_compatible_actor_wiring() -> void:
	_expect(FileAccess.file_exists(STATUS_COMPONENT_SCRIPT_PATH), "StatusEffectComponent script exists")
	for scene_path in ACTOR_SCENE_PATHS:
		var scene := load(scene_path) as PackedScene
		_expect(scene != null, "%s parses" % scene_path.get_file())
		if scene == null:
			continue
		var actor := scene.instantiate() as Node
		var statuses := actor.get_node_or_null(^"StatusEffects")
		var health_bar := actor.get_node_or_null(^"ActorHealthBar")
		_expect(statuses != null, "%s exposes StatusEffects" % scene_path.get_file())
		_expect(health_bar != null, "%s retains ActorHealthBar" % scene_path.get_file())
		if health_bar != null:
			_expect(health_bar.get_node_or_null(^"StatusBar") != null, "%s health bar contains a status row" % scene_path.get_file())
		actor.free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
