class_name ProjectInfoData
extends Resource

# Responsibility: Supply the project metadata displayed by the main menu.

## Player-facing project version text.
@export var project_version: String = ""
## Short description of the prototype's current development focus.
@export var current_focus: String = ""
## Player-facing build channel or milestone label.
@export var build_label: String = ""
## Whether the main menu should display current_focus.
@export var show_focus: bool = true
## Whether the main menu should display build_label.
@export var show_build_label: bool = true
