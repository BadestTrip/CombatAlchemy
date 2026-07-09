extends Control
class_name RuneWheelController

signal rune_selected(rune_id: String)

@export var active_runes: Array[String] = ["ASHA", "VORO", "KETH", "ELUM", "ZUN"]
@export var arc_radius: float = 170.0
@export var arc_start_degrees: float = 210.0
@export var arc_end_degrees: float = 330.0
@export var button_size: Vector2 = Vector2(104.0, 92.0)

var _buttons: Array[Button] = []
var _rune_texture_paths := {
	"ASHA": "res://sprites/runes/rune_asha_placeholder.png",
	"VORO": "res://sprites/runes/rune_voro_placeholder.png",
	"KETH": "res://sprites/runes/rune_keth_placeholder.png",
	"ELUM": "res://sprites/runes/rune_elum_placeholder.png",
	"ZUN": "res://sprites/runes/rune_zun_placeholder.png",
	"BAVO": "res://sprites/runes/rune_bavo_placeholder.png",
	"IRI": "res://sprites/runes/rune_iri_placeholder.png",
	"MIRA": "res://sprites/runes/rune_mira_placeholder.png",
	"NOX": "res://sprites/runes/rune_nox_placeholder.png"
}


func _ready() -> void:
	resized.connect(_position_buttons)
	rebuild_buttons()


func rebuild_buttons() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()

	for index in range(active_runes.size()):
		var rune_id := active_runes[index]
		var button := Button.new()
		button.custom_minimum_size = button_size
		button.size = button_size
		button.text = "%d\n%s" % [index + 1, rune_id]
		button.focus_mode = Control.FOCUS_NONE
		button.icon = _load_rune_texture(rune_id)
		button.expand_icon = true
		button.tooltip_text = "Add %s to the chant" % rune_id
		button.pressed.connect(_on_rune_button_pressed.bind(rune_id))
		add_child(button)
		_buttons.append(button)
	call_deferred("_position_buttons")


func select_rune_by_index(index: int) -> void:
	if index < 0 or index >= active_runes.size():
		return
	rune_selected.emit(active_runes[index])


func _on_rune_button_pressed(rune_id: String) -> void:
	rune_selected.emit(rune_id)


func _position_buttons() -> void:
	if _buttons.is_empty():
		return

	var center := Vector2(size.x * 0.5, size.y + 12.0)
	var count := _buttons.size()
	for index in range(count):
		var ratio := 0.5 if count == 1 else float(index) / float(count - 1)
		var angle := deg_to_rad(lerpf(arc_start_degrees, arc_end_degrees, ratio))
		var button := _buttons[index]
		button.size = button_size
		button.position = center + Vector2(cos(angle), sin(angle)) * arc_radius - button_size * 0.5


func _load_rune_texture(rune_id: String) -> Texture2D:
	var path := str(_rune_texture_paths.get(rune_id, ""))
	if path.is_empty():
		return null
	return load(path) as Texture2D
