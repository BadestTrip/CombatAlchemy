extends Control

# Emitted when Back is pressed. Combat pause UI listens to this signal.
signal close_requested

@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/HBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/VBoxContainer/HBoxContainer2/SFXSlider
@onready var back_button: TextureButton = $CenterContainer/VBoxContainer/HBoxContainer3/BackButton


func _ready() -> void:
	if back_button != null:
		back_button.pressed.connect(_on_back_button_pressed)
	if music_slider != null:
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider != null:
		sfx_slider.value_changed.connect(_on_sfx_changed)

	if music_slider != null:
		music_slider.value = clamp(db_to_linear(Settings.music_db), 0.0, 1.0)
	if sfx_slider != null:
		sfx_slider.value = clamp(db_to_linear(Settings.sfx_db), 0.0, 1.0)


func _on_music_changed(v: float) -> void:
	Settings.set_music_db(linear_to_db(max(0.001, v)))


func _on_sfx_changed(v: float) -> void:
	Settings.set_sfx_db(linear_to_db(max(0.001, v)))


func _on_back_button_pressed() -> void:
	visible = false
	close_requested.emit()
