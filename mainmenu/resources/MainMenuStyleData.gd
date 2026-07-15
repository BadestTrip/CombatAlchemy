## Stores high-level visual tuning for the main-menu scene.
extends Resource
class_name MainMenuStyleData


## Optional texture that replaces the scene's background texture.
@export var background_texture: Texture2D

## Base opacity applied to the decorative alchemy seal.
@export_range(0.0, 1.0, 0.01) var alchemy_seal_opacity: float = 0.52

## Rotation speed applied to the decorative alchemy seal in degrees per second.
@export_range(-30.0, 30.0, 0.1) var alchemy_seal_rotation_speed: float = 3.0

## Controls whether the main-menu shader overlay is visible.
@export var shader_enabled: bool = false

## Strength forwarded to the menu shader's effect_strength parameter.
@export_range(0.0, 2.0, 0.01) var shader_effect_strength: float = 1.0

## Strength forwarded to the menu shader's vignette_strength parameter.
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.38

## Speed forwarded to the menu shader's pulse_speed parameter.
@export_range(0.0, 12.0, 0.1) var pulse_speed: float = 4.5
