extends Node
class_name TutorialHighlighter


@export var tutorial_overlay: ColorRect
@export var tutorial_focus_layer: Control

@export_range(0.0, 1.0, 0.01) var overlay_alpha: float = 0.56
@export var highlight_scale: float = 1.045
@export var highlight_pulse_seconds: float = 0.48
@export var highlight_gold: Color = Color(1.0, 0.82, 0.28, 1.0)


var _focused_target: Control
var _focus_proxy: Control
var _pulse_tween: Tween
var _warned_missing_nodes: bool = false


func _ready() -> void:
	_resolve_nodes()
	set_process(false)
	if tutorial_overlay != null:
		tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tutorial_focus_layer != null:
		tutorial_focus_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_tree() -> void:
	clear_all()


func _process(_delta: float) -> void:
	refresh_focus_position()


func apply_presentation(settings: CombatTutorialPresentationData) -> void:
	if settings == null:
		return

	_resolve_nodes()
	overlay_alpha = settings.dim_overlay_alpha
	highlight_scale = maxf(1.0, settings.highlight_scale)
	highlight_pulse_seconds = maxf(0.01, settings.highlight_pulse_seconds)
	highlight_gold = settings.highlight_gold
	if tutorial_overlay != null and is_instance_valid(tutorial_overlay):
		var overlay_color := settings.dim_overlay_color
		overlay_color.a = overlay_alpha
		tutorial_overlay.color = overlay_color


func set_overlay_visible(is_visible: bool) -> void:
	_resolve_nodes()
	if tutorial_overlay != null and not is_instance_valid(tutorial_overlay):
		tutorial_overlay = null
	if tutorial_overlay == null:
		_warn_missing_nodes()
		return

	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_color := tutorial_overlay.color
	overlay_color.a = overlay_alpha
	tutorial_overlay.color = overlay_color
	tutorial_overlay.visible = is_visible


func set_dim_strength(alpha: float) -> void:
	overlay_alpha = clampf(alpha, 0.0, 1.0)
	if tutorial_overlay != null and not is_instance_valid(tutorial_overlay):
		tutorial_overlay = null
	if tutorial_overlay == null:
		return
	var overlay_color := tutorial_overlay.color
	overlay_color.a = overlay_alpha
	tutorial_overlay.color = overlay_color


func focus_target(target: Control) -> void:
	_resolve_nodes()
	if target == null:
		clear_focus()
		return
	if tutorial_focus_layer != null and not is_instance_valid(tutorial_focus_layer):
		tutorial_focus_layer = null
	if tutorial_focus_layer == null:
		_warn_missing_nodes()
		return

	clear_focus()
	_focused_target = target
	_focus_proxy = _create_proxy(target)
	_focus_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_proxy.focus_mode = Control.FOCUS_NONE
	tutorial_focus_layer.add_child(_focus_proxy)
	refresh_focus_position()
	_start_proxy_pulse()
	set_process(true)


func clear_focus() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null

	if _focus_proxy != null:
		_focus_proxy.queue_free()
		_focus_proxy = null

	_focused_target = null
	set_process(false)


func clear_all() -> void:
	clear_focus()
	set_overlay_visible(false)


func refresh_focus_position() -> void:
	if _focused_target == null or _focus_proxy == null or tutorial_focus_layer == null:
		return
	if not is_instance_valid(_focused_target) or not is_instance_valid(tutorial_focus_layer):
		clear_focus()
		return

	var global_rect := _focused_target.get_global_rect()
	var layer_transform := tutorial_focus_layer.get_global_transform()
	var local_pos := layer_transform.affine_inverse() * global_rect.position
	_focus_proxy.position = local_pos
	_focus_proxy.size = global_rect.size
	_focus_proxy.custom_minimum_size = global_rect.size
	_focus_proxy.pivot_offset = global_rect.size * 0.5


func _resolve_nodes() -> void:
	if tutorial_overlay != null and not is_instance_valid(tutorial_overlay):
		tutorial_overlay = null
	if tutorial_focus_layer != null and not is_instance_valid(tutorial_focus_layer):
		tutorial_focus_layer = null
	if tutorial_overlay == null:
		tutorial_overlay = _find_scene_node("TutorialOverlay") as ColorRect
	if tutorial_focus_layer == null:
		tutorial_focus_layer = _find_scene_node("TutorialFocusLayer") as Control


func _find_scene_node(node_name: String) -> Node:
	var search_root := get_tree().current_scene
	if search_root == null:
		search_root = owner
	if search_root == null:
		return null
	return search_root.find_child(node_name, true, false)


func _warn_missing_nodes() -> void:
	if _warned_missing_nodes:
		return
	push_warning(
		"TutorialHighlighter is missing TutorialOverlay or TutorialFocusLayer."
	)
	_warned_missing_nodes = true


func _create_proxy(target: Control) -> Control:
	if target is TextureButton:
		return _create_texture_button_proxy(target as TextureButton)
	if target is Button:
		return _create_button_proxy(target as Button)
	if target is Label:
		return _create_label_proxy(target as Label)
	return _create_frame_proxy(target)


func _create_texture_button_proxy(target: TextureButton) -> TextureButton:
	var proxy := TextureButton.new()
	proxy.texture_normal = target.texture_normal
	proxy.texture_hover = target.texture_hover
	proxy.texture_pressed = target.texture_pressed
	proxy.texture_disabled = target.texture_disabled
	proxy.texture_focused = target.texture_focused
	proxy.texture_click_mask = target.texture_click_mask
	proxy.ignore_texture_size = target.ignore_texture_size
	proxy.stretch_mode = target.stretch_mode
	proxy.modulate = _highlight_base_color()
	return proxy


func _create_button_proxy(target: Button) -> Button:
	var proxy := Button.new()
	proxy.text = target.text
	proxy.icon = target.icon
	proxy.expand_icon = target.expand_icon
	proxy.alignment = target.alignment
	proxy.icon_alignment = target.icon_alignment
	proxy.vertical_icon_alignment = target.vertical_icon_alignment
	proxy.clip_text = target.clip_text
	proxy.disabled = false
	proxy.flat = target.flat
	if target.has_theme_font_size_override("font_size"):
		proxy.add_theme_font_size_override(
			"font_size",
			target.get_theme_font_size("font_size")
		)
	_apply_button_gold_style(proxy)
	return proxy


func _create_label_proxy(target: Label) -> Label:
	var proxy := Label.new()
	proxy.text = target.text
	proxy.horizontal_alignment = target.horizontal_alignment
	proxy.vertical_alignment = target.vertical_alignment
	proxy.autowrap_mode = target.autowrap_mode
	proxy.clip_text = target.clip_text
	if target.has_theme_font_size_override("font_size"):
		proxy.add_theme_font_size_override(
			"font_size",
			target.get_theme_font_size("font_size")
		)
	else:
		proxy.add_theme_font_size_override("font_size", 24)
	proxy.add_theme_color_override("font_color", highlight_gold)
	return proxy


func _create_frame_proxy(target: Control) -> PanelContainer:
	var proxy := PanelContainer.new()
	proxy.add_theme_stylebox_override("panel", _make_gold_style())

	var label_texts := _collect_child_label_texts(target)
	if not label_texts.is_empty():
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)

		var label := Label.new()
		label.text = "\n".join(label_texts)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", highlight_gold)

		margin.add_child(label)
		proxy.add_child(margin)
	return proxy


func _collect_child_label_texts(target: Control) -> PackedStringArray:
	var label_texts: PackedStringArray = []
	for child: Node in target.find_children("*", "Label", true, false):
		var label := child as Label
		if label == null or not label.visible:
			continue
		if label.text.strip_edges().is_empty():
			continue
		label_texts.append(label.text)
		if label_texts.size() >= 3:
			break
	return label_texts


func _apply_button_gold_style(proxy: Button) -> void:
	var style := _make_gold_style()
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		proxy.add_theme_stylebox_override(style_name, style)
	for color_name: String in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_disabled_color",
		"font_focus_color"
	]:
		proxy.add_theme_color_override(color_name, highlight_gold)


func _make_gold_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(highlight_gold.r, highlight_gold.g, highlight_gold.b, 0.18)
	style.border_color = highlight_gold
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


func _start_proxy_pulse() -> void:
	if _focus_proxy == null:
		return

	_focus_proxy.scale = Vector2.ONE
	_focus_proxy.modulate = _highlight_base_color()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(
		_focus_proxy,
		"scale",
		Vector2(highlight_scale, highlight_scale),
		highlight_pulse_seconds
	)
	_pulse_tween.parallel().tween_property(
		_focus_proxy,
		"modulate",
		_highlight_peak_color(),
		highlight_pulse_seconds
	)
	_pulse_tween.tween_property(_focus_proxy, "scale", Vector2.ONE, highlight_pulse_seconds)
	_pulse_tween.parallel().tween_property(
		_focus_proxy,
		"modulate",
		_highlight_base_color(),
		highlight_pulse_seconds
	)


func _highlight_base_color() -> Color:
	return Color(highlight_gold.r * 1.18, highlight_gold.g * 1.18, highlight_gold.b * 1.18, 1.0)


func _highlight_peak_color() -> Color:
	return Color(highlight_gold.r * 1.45, highlight_gold.g * 1.45, highlight_gold.b * 1.45, 1.0)
