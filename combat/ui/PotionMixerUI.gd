class_name PotionMixerUI
extends Control

signal reagent_selected(reagent: StringName)
signal heat_power_changed(power: float)
signal fire_toggle_requested

@export var presentation_profile: BrewingPresentationProfileData = preload("res://combat/potions/brewing/BrewingPresentationProfile_Default.tres")

@onready var _flask_view: FlaskView = $FlaskView
@onready var _heat_control: HeatControl = $HeatControl
@onready var _burner: AlchemicalBurner = $AlchemicalBurner
@onready var _audio_feedback: BrewingAudioFeedback = $BrewingAudioFeedback
@onready var _reagent_buttons: Array[Button] = [
	$ReagentButtons/RedButton, $ReagentButtons/GreenButton, $ReagentButtons/BlueButton,
]
@onready var _count_labels: Array[Label] = [$RedCount, $GreenCount, $BlueCount]
@onready var _result_labels: Array[Label] = [$CheckResult1, $CheckResult2]
@onready var _feedback: Label = $CheckFeedback

var _inventory: ReagentInventory
var _buttons_editable := true
var _prepared := false
var _suspended := false
var _layer_count := 0
var _heat_power := 0.5
var _fire_active := false
var _check_results: Dictionary = {}
var _feedback_tween: Tween


func _ready() -> void:
	_flask_view.presentation_profile = presentation_profile
	_heat_control.configure(presentation_profile)
	_burner.presentation_profile = presentation_profile
	visibility_changed.connect(_refresh_animation)
	reset_view()
	set_heat_power(presentation_profile.default_heat_power)
	set_fire_active(false)


func configure_inventory(inventory: ReagentInventory) -> void:
	if _inventory != null and _inventory.availability_changed.is_connected(_on_availability_changed):
		_inventory.availability_changed.disconnect(_on_availability_changed)
	_inventory = inventory
	if _inventory != null:
		_inventory.availability_changed.connect(_on_availability_changed)
	_refresh_inventory()


func set_open(is_open: bool) -> void:
	visible = is_open
	_refresh_animation()


func show_mixing(layers: Array[StringName]) -> void:
	_prepared = false
	_layer_count = layers.size()
	_clear_check_results()
	_flask_view.set_layers(layers)
	_set_reagent_buttons_visible(true)
	_set_reagent_buttons_enabled(_layer_count < 3)
	_refresh_animation()


func show_brewing(
	layers: Array[StringName], state: int, height: float, power: float,
	blend: float, profile: Resource = null, final_color: Color = Color.WHITE
) -> void:
	if state == BrewingReaction.State.COMPLETED:
		show_ready(final_color)
		return
	_prepared = false
	_layer_count = layers.size()
	_flask_view.show_brewing(layers, state, height, power, blend, profile, final_color)
	set_heat_power(power)
	_audio_feedback.set_heating(state == BrewingReaction.State.HEATING, height, power)
	_set_reagent_buttons_visible(true)
	_set_reagent_buttons_enabled(state == BrewingReaction.State.IDLE and _layer_count < 3)
	_refresh_animation()


func show_ready(color: Color, quality_score: int = 0) -> void:
	_prepared = true
	_flask_view.show_ready(color, quality_score == 2)
	_audio_feedback.set_heating(false, 0.0, _heat_power)
	if quality_score == 2:
		_audio_feedback.play_perfect_brew()
	_set_reagent_buttons_visible(false)
	_set_reagent_buttons_enabled(false)
	_refresh_animation()


func show_mix_failure() -> void:
	_flask_view.show_failure()
	_set_reagent_buttons_visible(not _prepared)
	_set_reagent_buttons_enabled(not _prepared and _layer_count < 3)


func reset_view() -> void:
	_prepared = false
	_layer_count = 0
	_clear_check_results()
	_flask_view.reset_view()
	_audio_feedback.set_heating(false, 0.0, _heat_power)
	_set_reagent_buttons_visible(true)
	_set_reagent_buttons_enabled(true)
	_refresh_animation()


## Synchronizes controller-driven power without emitting a second change signal.
func set_heat_power(power: float) -> void:
	_heat_power = clampf(power, 0.0, 1.0)
	_heat_control.set_heat_power(_heat_power)
	_burner.set_heat_power(_heat_power)
	_audio_feedback.set_fire_state(_fire_active, _heat_power)


func set_fire_active(active: bool) -> void:
	_fire_active = active
	_heat_control.set_fire_active(active)
	_burner.set_active(active)
	_audio_feedback.set_fire_state(active, _heat_power)


func is_fire_active() -> bool:
	return _fire_active


func set_animation_suspended(suspended: bool) -> void:
	_suspended = suspended
	_refresh_animation()


## Index is zero-based, matching BrewingReaction.check_completed.
func show_check_result(index: int, score: int) -> void:
	if index < 0 or index >= _result_labels.size() or _check_results.has(index):
		return
	var result := clampi(score, -1, 1)
	_check_results[index] = result
	_flask_view.show_check_feedback(result)
	_audio_feedback.play_release(result)
	var text := "+1" if result > 0 else str(result)
	_result_labels[index].text = "%d: %s" % [index + 1, text]
	_result_labels[index].show()
	if _feedback_tween != null:
		_feedback_tween.kill()
	_feedback.text = text
	_feedback.modulate.a = 1.0
	_feedback.show()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(presentation_profile.feedback_duration * 0.6)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, presentation_profile.feedback_duration * 0.4)
	_feedback_tween.finished.connect(_on_feedback_finished)
	_refresh_animation()


func _on_feedback_finished() -> void:
	_feedback_tween = null
	_feedback.hide()


func are_reagent_buttons_enabled() -> bool:
	for button in _reagent_buttons:
		if button.disabled:
			return false
	return true


func _refresh_animation() -> void:
	if _heat_control == null:
		return
	var suspended := _suspended or not is_visible_in_tree()
	_flask_view.set_animation_suspended(suspended)
	_burner.set_animation_suspended(suspended)
	_audio_feedback.set_suspended(suspended)
	_heat_control.set_power_enabled(not suspended and not _prepared)
	_heat_control.set_fire_enabled(not suspended)
	_refresh_inventory()
	if _feedback_tween != null and _feedback_tween.is_valid():
		if suspended and _feedback_tween.is_running():
			_feedback_tween.pause()
		elif not suspended and not _feedback_tween.is_running():
			_feedback_tween.play()


func _clear_check_results() -> void:
	_check_results.clear()
	if _feedback_tween != null:
		_feedback_tween.kill()
		_feedback_tween = null
	_feedback.hide()
	for label in _result_labels:
		label.hide()
		label.text = ""


func _set_reagent_buttons_visible(should_show: bool) -> void:
	$ReagentButtons.visible = should_show
	for button in _reagent_buttons:
		button.visible = should_show
	for label in _count_labels:
		label.visible = should_show


func _set_reagent_buttons_enabled(should_enable: bool) -> void:
	_buttons_editable = should_enable
	_refresh_inventory()


func _on_availability_changed(_reagent: StringName, _available: int) -> void:
	_refresh_inventory()


func _refresh_inventory() -> void:
	var reagents: Array[StringName] = [PotionReagent.RED, PotionReagent.GREEN, PotionReagent.BLUE]
	for index in _reagent_buttons.size():
		var count := _inventory.get_available_count(reagents[index]) if _inventory != null else 0
		_count_labels[index].text = _format_count(count)
		_count_labels[index].tooltip_text = "%d available" % count
		_reagent_buttons[index].tooltip_text = "%d available" % count
		_reagent_buttons[index].disabled = not _buttons_editable or _prepared or _suspended or _layer_count >= 3 or count <= 0


func _format_count(count: int) -> String:
	if count < 1000:
		return str(count)
	return "%.1fK" % (float(count) / 1000.0)


func _on_heat_power_changed(power: float) -> void:
	if _prepared or _suspended or not is_visible_in_tree():
		return
	set_heat_power(power)
	heat_power_changed.emit(_heat_power)


func _on_fire_toggle_requested() -> void:
	if _suspended or not is_visible_in_tree():
		return
	fire_toggle_requested.emit()


func _on_red_button_pressed() -> void:
	if not _reagent_buttons[0].disabled:
		reagent_selected.emit(PotionReagent.RED)


func _on_green_button_pressed() -> void:
	if not _reagent_buttons[1].disabled:
		reagent_selected.emit(PotionReagent.GREEN)


func _on_blue_button_pressed() -> void:
	if not _reagent_buttons[2].disabled:
		reagent_selected.emit(PotionReagent.BLUE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
