# VersionStone.gd
# Purpose:
#   Show a small reusable version plaque on the main menu.
#
# Node assumptions:
#   - Attach this script to the root PanelContainer of VersionStone.tscn.
#   - The scene contains labels named VersionLabel, FocusTitleLabel, and FocusLabel.
#   - MainMenu.tscn places this scene in a corner.
#
# Inspector tuning notes:
#   - version_text and focus_text can be edited per instance.
#   - show_focus hides or reveals the current-focus section.
extends PanelContainer


# The short project version displayed at the top of the plaque.
@export var version_text: String = "v0.1.1":
	set(value):
		version_text = value
		_refresh_labels()

# The current development focus displayed under the version.
@export var focus_text: String = "Combat Experimentation":
	set(value):
		focus_text = value
		_refresh_labels()

# Toggle this off if a build should show only the version number.
@export var show_focus: bool = true:
	set(value):
		show_focus = value
		_refresh_labels()


@onready var version_label: Label = %VersionLabel
@onready var focus_title_label: Label = %FocusTitleLabel
@onready var focus_label: Label = %FocusLabel


# Godot calls this when the scene enters the tree.
func _ready() -> void:
	# This plaque is informational only and should not intercept menu clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_labels()


# Push exported text values into the label nodes.
func _refresh_labels() -> void:
	if not is_node_ready():
		return

	version_label.text = version_text
	focus_title_label.visible = show_focus
	focus_label.visible = show_focus
	focus_label.text = focus_text
