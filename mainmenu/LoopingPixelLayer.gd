class_name LoopingPixelLayer
extends Control

# Responsibility: Move two identical pixel-art strips at integer positions and
# wrap them without a visible seam.

## Horizontal movement rate. Positive values move to the right.
@export_range(-32.0, 32.0, 0.25) var speed_pixels_per_second: float = 4.0
## Width of one authored strip in pixels.
@export_range(1.0, 4096.0, 1.0) var loop_width: float = 2048.0

@onready var _tile_a: TextureRect = get_node_or_null("TileA") as TextureRect
@onready var _tile_b: TextureRect = get_node_or_null("TileB") as TextureRect

var _travel: float = 0.0


func _ready() -> void:
	if _tile_a == null or _tile_b == null:
		push_error("LoopingPixelLayer requires TileA and TileB TextureRects.")
		set_process(false)
		return
	_layout_tiles()


func _process(delta: float) -> void:
	_travel = fposmod(_travel + speed_pixels_per_second * delta, loop_width)
	_layout_tiles()


func _layout_tiles() -> void:
	if _tile_a == null or _tile_b == null:
		return
	var snapped_x := roundf(_travel)
	_tile_a.position.x = snapped_x
	_tile_b.position.x = snapped_x - loop_width
