extends Control
class_name SpellResultBannerController


@export var title_label: Label
@export var category_label: Label
@export var auto_hide_seconds: float = 1.4


var _hide_tween: Tween


func _ready() -> void:
	set_process(false)
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if category_label == null:
		category_label = find_child("CategoryLabel", true, false) as Label
	visible = false


func show_result(result: Dictionary) -> void:
	if title_label == null or category_label == null:
		return

	if _hide_tween != null:
		_hide_tween.kill()
		_hide_tween = null

	title_label.text = String(result.get("result_name", "Unknown Chant"))
	category_label.text = _category_text(String(result.get("result_type", "fallback")))
	visible = true
	modulate.a = 1.0

	if auto_hide_seconds > 0.0:
		_hide_tween = create_tween()
		_hide_tween.tween_interval(auto_hide_seconds)
		_hide_tween.tween_property(self, "modulate:a", 0.0, 0.18)
		_hide_tween.tween_callback(func() -> void:
			visible = false
		)


func _category_text(result_type: String) -> String:
	match result_type:
		"workable":
			return "Known Spell"
		"disaster":
			return "Disaster Spell"
		"op":
			return "Rare Spell"
		"funny":
			return "Strange Spell"
		"invalid":
			return "Invalid Chant"
		_:
			return "Unknown Chant"
