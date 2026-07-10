extends Control
class_name RuneMenu


signal spell_cast_requested(combination_key: String, spell_name: String)

const FORWARD_RUNE: RuneData = preload("res://test/runes/data/ForwardRune.tres")
const FLAME_RUNE: RuneData = preload("res://test/runes/data/FlameRune.tres")

const SELECTED_BORDER_COLOR := Color(1.0, 0.92, 0.32, 1.0)
const FILLED_SLOT_BORDER_COLOR := Color(0.80, 0.84, 0.92, 1.0)
const EMPTY_SLOT_COLOR := Color(0.14, 0.16, 0.20, 1.0)
const EMPTY_SLOT_BORDER_COLOR := Color(0.40, 0.45, 0.55, 1.0)
const TEXT_COLOR := Color(0.92, 0.92, 0.86, 1.0)
const SLOT_ORDER: Array[StringName] = [
	RuneSpellBuilder.SLOT_BASE,
	RuneSpellBuilder.SLOT_MOVEMENT,
	RuneSpellBuilder.SLOT_IMPACT,
]

@onready var title_label: Label = %TitleLabel
@onready var base_slot_button: Button = %BaseSlotButton
@onready var movement_slot_button: Button = %MovementSlotButton
@onready var impact_slot_button: Button = %ImpactSlotButton
@onready var runes_label: Label = %RunesLabel
@onready var forward_rune_button: Button = %ForwardRuneButton
@onready var flame_rune_button: Button = %FlameRuneButton
@onready var spell_name_label: Label = %SpellNameLabel
@onready var spell_description_label: Label = %SpellDescriptionLabel
@onready var cast_button: Button = %CastButton
@onready var clear_button: Button = %ClearButton

var _builder := RuneSpellBuilder.new()
var _next_slot_index: int = 0


func _ready() -> void:
	_apply_static_text_style()
	_connect_buttons()
	_builder.combination_changed.connect(_refresh_ui)
	_refresh_ui()


func _connect_buttons() -> void:
	# Slots are only indicators now: rune clicks fill them automatically in order.
	for button: Button in [
		base_slot_button,
		movement_slot_button,
		impact_slot_button,
		forward_rune_button,
		flame_rune_button,
		cast_button,
		clear_button,
	]:
		button.focus_mode = Control.FOCUS_NONE

	for slot_button: Button in [base_slot_button, movement_slot_button, impact_slot_button]:
		slot_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	forward_rune_button.pressed.connect(_place_rune.bind(FORWARD_RUNE))
	flame_rune_button.pressed.connect(_place_rune.bind(FLAME_RUNE))
	cast_button.pressed.connect(_request_cast)
	clear_button.pressed.connect(_clear_slots)


func _apply_static_text_style() -> void:
	for label: Label in [
		title_label,
		runes_label,
		spell_name_label,
		spell_description_label,
	]:
		label.add_theme_color_override("font_color", TEXT_COLOR)

	title_label.add_theme_font_size_override("font_size", 22)
	runes_label.add_theme_font_size_override("font_size", 14)
	spell_name_label.add_theme_font_size_override("font_size", 18)
	spell_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	forward_rune_button.text = FORWARD_RUNE.display_name
	flame_rune_button.text = FLAME_RUNE.display_name
	_apply_button_style(forward_rune_button, FORWARD_RUNE.rune_color.darkened(0.35), FORWARD_RUNE.rune_color)
	_apply_button_style(flame_rune_button, FLAME_RUNE.rune_color.darkened(0.35), FLAME_RUNE.rune_color)
	_apply_button_style(cast_button, Color(0.18, 0.25, 0.18, 1.0), Color(0.52, 0.92, 0.42, 1.0))
	_apply_button_style(clear_button, Color(0.24, 0.18, 0.18, 1.0), Color(0.70, 0.35, 0.30, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
			_request_cast()
			get_viewport().set_input_as_handled()


func _place_rune(rune: RuneData) -> void:
	_builder.set_rune(_get_next_slot_id(), rune)
	_next_slot_index = (_next_slot_index + 1) % SLOT_ORDER.size()
	_refresh_slot_buttons()


func _clear_slots() -> void:
	_next_slot_index = 0
	_builder.clear()


func _refresh_ui() -> void:
	_refresh_slot_buttons()
	spell_name_label.text = _builder.get_result_name()
	spell_description_label.text = _builder.get_result_description()
	cast_button.disabled = not _builder.is_complete()


func _refresh_slot_buttons() -> void:
	_refresh_slot_button(
		base_slot_button,
		"Основа",
		RuneSpellBuilder.SLOT_BASE
	)
	_refresh_slot_button(
		movement_slot_button,
		"Движение",
		RuneSpellBuilder.SLOT_MOVEMENT
	)
	_refresh_slot_button(
		impact_slot_button,
		"Попадание",
		RuneSpellBuilder.SLOT_IMPACT
	)


func _refresh_slot_button(
	button: Button,
	slot_title: String,
	slot_id: StringName
) -> void:
	var rune := _builder.get_slot_rune(slot_id)
	var rune_name := rune.display_name if rune != null else "Пусто"
	button.text = "%s\n%s" % [slot_title, rune_name]

	var background_color := EMPTY_SLOT_COLOR
	var border_color := EMPTY_SLOT_BORDER_COLOR
	if rune != null:
		background_color = rune.rune_color.darkened(0.52)
		border_color = FILLED_SLOT_BORDER_COLOR
	if slot_id == _get_next_slot_id():
		border_color = SELECTED_BORDER_COLOR

	_apply_button_style(button, background_color, border_color, 4 if slot_id == _get_next_slot_id() else 2)


func _get_next_slot_id() -> StringName:
	return SLOT_ORDER[_next_slot_index]


func _request_cast() -> void:
	if not _builder.is_complete():
		return
	spell_cast_requested.emit(_builder.get_combination_key(), _builder.get_result_name())


func _apply_button_style(
	button: Button,
	background_color: Color,
	border_color: Color,
	border_width: int = 2
) -> void:
	var normal := _make_button_style(background_color, border_color, border_width)
	var hover := _make_button_style(background_color.lightened(0.08), border_color.lightened(0.15), border_width)
	var pressed := _make_button_style(background_color.darkened(0.10), border_color, border_width)
	var disabled := _make_button_style(background_color.darkened(0.22), border_color.darkened(0.45), border_width)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", TEXT_COLOR.darkened(0.38))


func _make_button_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	return style
