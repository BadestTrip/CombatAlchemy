# ProjectInfoData.gd
# Single source of truth for the version plaque shown on the main menu.
extends Resource
class_name ProjectInfoData


@export var project_version: String = "v0.1.3"
@export var current_focus: String = "Architecture Cleanup"
@export var build_label: String = "Prototype"
@export var show_focus: bool = true
@export var show_build_label: bool = true
