extends Control
class_name RuneWheelController

signal rune_selected(rune_id: String)

@export var active_runes: Array[String] = ["ASHA", "VORO", "KETH", "ELUM", "ZUN"]
@export var arc_radius: float = 170.0
@export var arc_start_degrees: float = 210.0
@export var arc_end_degrees: float = 330.0
@export var button_size: Vector2 = Vector2(104.0, 92.0)
@export var rune_button_paths: Array[NodePath] = [
	NodePath("RuneButton1"),
	NodePath("RuneButton2"),
	NodePath("RuneButton3"),
	NodePath("RuneButton4"),
	NodePath("RuneButton5")
]

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
	_collect_buttons()
	rebuild_buttons()


func rebuild_buttons() -> void:
	if _buttons.is_empty():
		_collect_buttons()

	for index in range(_buttons.size()):
		var button := _buttons[index]
		var has_rune := index < active_runes.size()
		button.visible = has_rune
		if not has_rune:
			continue

		var rune_id := active_runes[index]
		button.custom_minimum_size = button_size
		button.size = button_size
		button.text = "%d\n%s" % [index + 1, rune_id]
		button.focus_mode = Control.FOCUS_NONE
		button.icon = _load_rune_texture(rune_id)
		button.expand_icon = true
		button.tooltip_text = "Add %s to the chant" % rune_id
	call_deferred("_position_buttons")


func select_rune_by_index(index: int) -> void:
	if index < 0 or index >= active_runes.size():
		return
	rune_selected.emit(active_runes[index])


func _collect_buttons() -> void:
	_buttons.clear()

	for path in rune_button_paths:
		var button := get_node_or_null(path) as Button
		if button == null:
			continue
		_buttons.append(button)

	if _buttons.is_empty():
		for child in get_children():
			if child is Button:
				_buttons.append(child as Button)

	for index in range(_buttons.size()):
		var button := _buttons[index]
		var pressed_callback := _on_rune_button_pressed.bind(index)
		if not button.pressed.is_connected(pressed_callback):
			button.pressed.connect(pressed_callback)


func _on_rune_button_pressed(index: int) -> void:
	if index < 0 or index >= active_runes.size():
		return
	rune_selected.emit(active_runes[index])


func _position_buttons() -> void:
	if _buttons.is_empty():
		return

	var center := Vector2(size.x * 0.5, size.y + 12.0)
	var count := mini(active_runes.size(), _buttons.size())
	if count <= 0:
		return

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
