## Presents project version and current-focus metadata without intercepting input.
extends PanelContainer


const FALLBACK_VERSION_TEXT: String = "Version unavailable"
const FALLBACK_FOCUS_TEXT: String = "Focus unavailable"


## Metadata displayed by the version stone.
@export var project_info: ProjectInfoData:
	set(value):
		project_info = value
		_refresh_labels()


@onready var _version_label: Label = get_node_or_null("%VersionLabel") as Label
@onready var _focus_title_label: Label = get_node_or_null("%FocusTitleLabel") as Label
@onready var _focus_label: Label = get_node_or_null("%FocusLabel") as Label


var _warned_about_missing_project_info: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _validate_dependencies():
		return
	_refresh_labels()


func _refresh_labels() -> void:
	if not is_node_ready() or not _labels_are_available():
		return

	var info: ProjectInfoData = _get_project_info()
	var version_text: String = FALLBACK_VERSION_TEXT
	var focus_text: String = FALLBACK_FOCUS_TEXT
	var show_focus: bool = false

	if info != null:
		version_text = info.project_version
		if info.show_build_label and not info.build_label.is_empty():
			version_text = "%s - %s" % [version_text, info.build_label]
		focus_text = info.current_focus
		show_focus = info.show_focus

	_version_label.text = version_text
	_focus_title_label.visible = show_focus
	_focus_label.visible = show_focus
	_focus_label.text = focus_text


func _get_project_info() -> ProjectInfoData:
	if project_info != null:
		return project_info
	if not _warned_about_missing_project_info:
		push_warning("VersionStone has no ProjectInfoData; using placeholders.")
		_warned_about_missing_project_info = true
	return null


func _validate_dependencies() -> bool:
	var valid: bool = true
	valid = _require_label(_version_label, "VersionLabel") and valid
	valid = _require_label(_focus_title_label, "FocusTitleLabel") and valid
	valid = _require_label(_focus_label, "FocusLabel") and valid
	return valid


func _labels_are_available() -> bool:
	return (
		_version_label != null
		and _focus_title_label != null
		and _focus_label != null
	)


func _require_label(label: Label, label_name: String) -> bool:
	if label != null:
		return true
	push_error("VersionStone is missing the %s label." % label_name)
	return false
