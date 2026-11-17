class_name PlayerSpriteData
extends Resource

## Exportable sprite and per-frame socket data; no raw JSON dependency at runtime.
@export var sprite_frames: SpriteFrames
@export var pivot := Vector2(32, 74)
@export var frame_sockets: Dictionary = {}
