extends PanelContainer
class_name ExperimentalRuneWheelController

signal rune_selected(rune_id: String)

@export var active_runes: Array[String] = ["ASHA", "VORO", "KETH", "ELUM", "ZUN"]

@onready var rune_button_row: HBoxContainer = $RuneButtonRow

var _buttons: Array[Button] = []


func _ready() -> void:
	rebuild_buttons()


func rebuild_buttons() -> void:
	for child in rune_button_row.get_children():
		child.queue_free()
	_buttons.clear()

	for index in range(active_runes.size()):
		var rune_id := active_runes[index]
		var button := Button.new()
		button.text = "%d  %s" % [index + 1, rune_id]
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Add %s to the chant" % rune_id
		button.pressed.connect(_on_rune_button_pressed.bind(rune_id))
		rune_button_row.add_child(button)
		_buttons.append(button)


func select_rune_by_index(index: int) -> void:
	if index < 0 or index >= active_runes.size():
		return
	rune_selected.emit(active_runes[index])


func _on_rune_button_pressed(rune_id: String) -> void:
	rune_selected.emit(rune_id)
