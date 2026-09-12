extends Node2D

# Responsibility: Provide an isolated preview surface for crystal piles and
# shatter bursts. It is not part of the active scene flow.

const SHATTER_SCENE: PackedScene = preload("res://vfx/reactive_crystal/PotionShatterParticles.tscn")
const PALETTE: AlchemyPaletteData = preload("res://shared/alchemy/ChargedNeonPalette.tres")

@onready var _burst_origin: Marker2D = get_node_or_null("BurstOrigin") as Marker2D
@onready var _bursts: Node2D = get_node_or_null("Bursts") as Node2D
@onready var _controls: Control = get_node_or_null("UI/BurstControls") as Control


func _ready() -> void:
	if _burst_origin == null or _bursts == null or _controls == null:
		push_error("ReactiveCrystalVFXWorkshop is missing its burst preview dependencies.")
		return
	for child in _controls.get_children():
		var button := child as Button
		if button == null:
			continue
		button.pressed.connect(_on_burst_button_pressed.bind(StringName(button.name).to_lower()))


func _on_burst_button_pressed(color_id: StringName) -> void:
	var burst := SHATTER_SCENE.instantiate() as PotionShatterParticles
	if burst == null:
		return
	_bursts.add_child(burst)
	burst.play_burst(_burst_origin.global_position, PALETTE.get_color(color_id), Vector2.UP)
