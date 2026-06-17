# CombatLog.gd
# Attach this script to the CombatLog RichTextLabel in CombatScene.tscn.
# Other combat scripts send readable lines here instead of printing to the console.
extends RichTextLabel
class_name CombatLog


# Emitted whenever a line is added.
# Future sound, accessibility, or transcript systems can listen to it.
signal log_line_added(text: String)


# Godot calls this when the scene loads.
func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true
	clear_log()


# CombatManager calls this once at combat start.
func clear_log() -> void:
	clear()
	append_line("Mage Chant Combat", Color(0.95, 0.78, 0.38))


# Managers call this for every player-facing combat message.
func append_line(text: String, color: Color = Color.WHITE) -> void:
	if text.is_empty():
		return
	push_color(color)
	append_text(text)
	pop()
	append_text("\n")
	log_line_added.emit(text)


# RoundManager uses separators to keep rounds easy to scan.
func append_separator() -> void:
	append_text("--------------------------------\n")
