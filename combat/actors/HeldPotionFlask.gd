class_name HeldPotionFlask
extends Node2D

# Responsibility: Display one colored potion prop at an authored character socket.

@onready var _liquid: Polygon2D = $Liquid


func _ready() -> void:
	hide_potion()


## Shows the flask and colors its liquid for the prepared recipe.
func show_potion(color: Color) -> void:
	if _liquid != null:
		_liquid.color = color
	visible = true


## Hides the held prop without changing its last assigned color.
func hide_potion() -> void:
	visible = false
