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
#   - Assign ProjectInfo_Default.tres so version/focus text has one source.
#   - Label text inside VersionStone.tscn is only a placeholder.
extends PanelContainer


const FALLBACK_VERSION_TEXT: String = "Version unavailable"
const FALLBACK_FOCUS_TEXT: String = "Focus unavailable"


@export var project_info: ProjectInfoData:
	set(value):
		project_info = value
		_refresh_labels()


@onready var version_label: Label = %VersionLabel
@onready var focus_title_label: Label = %FocusTitleLabel
@onready var focus_label: Label = %FocusLabel


var _warned_missing_project_info: bool = false


# Godot calls this when the scene enters the tree.
func _ready() -> void:
	# This plaque is informational only and should not intercept menu clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_labels()


# Push ProjectInfoData values into the label nodes.
func _refresh_labels() -> void:
	if not is_node_ready():
		return

	var info := _get_project_info()
	var version_text := FALLBACK_VERSION_TEXT
	var focus_text := FALLBACK_FOCUS_TEXT
	var should_show_focus := false

	if info != null:
		version_text = info.project_version
		if info.show_build_label and not info.build_label.is_empty():
			version_text = "%s - %s" % [version_text, info.build_label]
		focus_text = info.current_focus
		should_show_focus = info.show_focus

	version_label.text = version_text
	focus_title_label.visible = should_show_focus
	focus_label.visible = should_show_focus
	focus_label.text = focus_text


func _get_project_info() -> ProjectInfoData:
	if project_info != null:
		return project_info
	if not _warned_missing_project_info:
		push_warning(
			"VersionStone has no ProjectInfoData assigned; using placeholders."
		)
		_warned_missing_project_info = true
	return null
