extends RichTextLabel
class_name CombatLog


func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true
	clear_log()


func clear_log() -> void:
	clear()
	append_event("Bandit Bridge Ambush", Color(0.95, 0.78, 0.38))


func append_event(message: String, color: Color = Color.WHITE) -> void:
	if message.is_empty():
		return
	push_color(color)
	append_text(message)
	pop()
	append_text("\n")


func append_separator() -> void:
	append_text("--------------------------------\n")
