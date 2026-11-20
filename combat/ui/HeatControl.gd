class_name HeatControl
extends Control

signal heat_power_changed(power: float)
signal fire_toggle_requested

@export var presentation_profile: BrewingPresentationProfileData = preload("res://combat/potions/brewing/BrewingPresentationProfile_Default.tres")
@onready var _slider: HSlider = $Slider
@onready var _value_label: Label = $ValueLabel
@onready var _fire_toggle: Button = $FireToggle


func _ready() -> void:
	configure(presentation_profile)
	set_heat_power(presentation_profile.default_heat_power)


func configure(profile: BrewingPresentationProfileData) -> void:
	presentation_profile = profile
	_slider.step = presentation_profile.heat_step


## Programmatic synchronization does not emit heat_power_changed.
func set_heat_power(power: float) -> void:
	var normalized := clampf(power, 0.0, 1.0)
	_slider.set_value_no_signal(normalized)
	_value_label.text = "%d%%" % roundi(normalized * 100.0)


func set_enabled(enabled: bool) -> void:
	set_power_enabled(enabled)
	set_fire_enabled(enabled)


func set_power_enabled(enabled: bool) -> void:
	_slider.editable = enabled
	_slider.scrollable = enabled
	_slider.modulate = Color.WHITE if enabled else Color(0.6, 0.6, 0.6)
	_value_label.modulate = _slider.modulate


func set_fire_enabled(enabled: bool) -> void:
	_fire_toggle.disabled = not enabled


func set_fire_active(active: bool) -> void:
	_fire_toggle.set_pressed_no_signal(active)
	_fire_toggle.text = "ON" if active else "OFF"


func is_fire_active() -> bool:
	return _fire_toggle.button_pressed


func _on_slider_value_changed(power: float) -> void:
	_value_label.text = "%d%%" % roundi(power * 100.0)
	heat_power_changed.emit(power)


func _on_fire_toggle_toggled(_active: bool) -> void:
	fire_toggle_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
