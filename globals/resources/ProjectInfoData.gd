# ProjectInfoData.gd
# Single source of truth for the version plaque shown on the main menu.
extends Resource
class_name ProjectInfoData


@export var project_version: String = ""
@export var current_focus: String = ""
@export var build_label: String = ""
@export var show_focus: bool = true
@export var show_build_label: bool = true
