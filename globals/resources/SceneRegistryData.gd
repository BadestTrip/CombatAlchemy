class_name SceneRegistryData
extends Resource

# Responsibility: Register the core scenes routed by GameManager.

## Scene loaded when GameManager returns to the main menu.
@export var main_menu_scene: PackedScene
## Scene loaded when GameManager starts a new game.
@export var combat_scene: PackedScene
