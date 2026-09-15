extends Node

# Responsibility: Verify the scene-backed main-menu layout, settings controls,
# native-resolution artwork, and ambient animation contracts.

const MAIN_MENU_SCENE_PATH: String = "res://mainmenu/MainMenu.tscn"
const START_MENU_SCENE_PATH: String = "res://mainmenu/StartMenu.tscn"
const BACKDROP_SCENE_PATH: String = "res://mainmenu/MainMenuBackdrop.tscn"
const SETTINGS_VIEW_SCENE_PATH: String = "res://mainmenu/MainMenuSettingsView.tscn"
const AUDIO_STEP_SCENE_PATH: String = "res://mainmenu/AudioStepControl.tscn"
const COMMAND_BUTTON_SCENE_PATH: String = "res://mainmenu/MainMenuCommandButton.tscn"
const BASE_TEXTURE_PATH: String = "res://sprites/main_menu/animated/main_menu_lab_base.png"
const TRANSPARENT_LAYER_PATHS: Array[String] = [
	"res://sprites/main_menu/animated/clouds_far.png",
	"res://sprites/main_menu/animated/clouds_near.png",
	"res://sprites/main_menu/animated/foliage_frames.png",
	"res://sprites/main_menu/animated/note_frames.png",
]

var _failures: Array[String] = []
var _owned_nodes: Array[Node] = []


func _ready() -> void:
	_test_required_files_exist()
	await _test_audio_step_control()
	await _test_settings_view()
	_test_backdrop_art_and_animation()
	await _test_main_menu_navigation()
	_free_owned_nodes()

	if _failures.is_empty():
		print("MainMenuTests: PASS (menu contracts)")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("MainMenuTests: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _test_required_files_exist() -> void:
	for path in [
		MAIN_MENU_SCENE_PATH,
		START_MENU_SCENE_PATH,
		BACKDROP_SCENE_PATH,
		SETTINGS_VIEW_SCENE_PATH,
		AUDIO_STEP_SCENE_PATH,
		COMMAND_BUTTON_SCENE_PATH,
		BASE_TEXTURE_PATH,
	]:
		_expect(ResourceLoader.exists(path), "%s exists" % path)


func _test_audio_step_control() -> void:
	var control := _instantiate_scene(AUDIO_STEP_SCENE_PATH)
	if control == null:
		return
	add_child(control)
	await get_tree().process_frame

	_expect(control.has_signal(&"step_changed"), "AudioStepControl exposes step_changed")
	_expect(control.has_method(&"set_step"), "AudioStepControl exposes set_step")
	_expect(control.has_method(&"get_step"), "AudioStepControl exposes get_step")
	_expect(_has_property(control, &"label_text"), "AudioStepControl exports label_text")
	_expect(_has_property(control, &"initial_step"), "AudioStepControl exports initial_step")

	var reported_steps: Array[int] = []
	if control.has_signal(&"step_changed"):
		control.connect(&"step_changed", func(step: int) -> void: reported_steps.append(step))
	if control.has_method(&"set_step") and control.has_method(&"get_step"):
		control.call(&"set_step", -4)
		_expect(int(control.call(&"get_step")) == 0, "audio step clamps below zero")
		control.call(&"set_step", 14)
		_expect(int(control.call(&"get_step")) == 10, "audio step clamps above ten")
		control.call(&"set_step", 7, true)
		_expect(reported_steps == [7], "set_step emits only when requested")

	var segments := control.get_node_or_null("ControlRow/Segments")
	_expect(segments != null and segments.get_child_count() == 10, "audio control authors ten segments")


func _test_settings_view() -> void:
	var view := _instantiate_scene(SETTINGS_VIEW_SCENE_PATH)
	if view == null:
		return
	add_child(view)
	await get_tree().process_frame

	_expect(view.has_signal(&"close_requested"), "MainMenuSettingsView exposes close_requested")
	for method_name in [&"open", &"close", &"focus_default", &"set_interaction_enabled"]:
		_expect(view.has_method(method_name), "MainMenuSettingsView exposes %s" % method_name)

	if view.has_method(&"open"):
		view.call(&"open")
		_expect(view.visible, "settings view opens without replacing the backdrop")
	if view.has_method(&"close"):
		view.call(&"close")
		_expect(not view.visible, "settings view closes in place")

	var script: Script = view.get_script()
	if script != null and script.has_method(&"step_to_db") and script.has_method(&"db_to_step"):
		_expect(is_equal_approx(float(script.call(&"step_to_db", 0)), -80.0), "step zero maps to -80 dB")
		_expect(is_equal_approx(float(script.call(&"step_to_db", 10)), 0.0), "step ten maps to 0 dB")
		_expect(int(script.call(&"db_to_step", -80.0)) == 0, "-80 dB maps to step zero")
		_expect(int(script.call(&"db_to_step", 0.0)) == 10, "0 dB maps to step ten")
	else:
		_expect(false, "MainMenuSettingsView exposes audio step conversion helpers")


func _test_backdrop_art_and_animation() -> void:
	if ResourceLoader.exists(BASE_TEXTURE_PATH):
		var base_image := _load_texture_image(BASE_TEXTURE_PATH)
		_expect(base_image != null and base_image.get_size() == Vector2i(1920, 1080), "menu base is native 1920x1080")

	for path in TRANSPARENT_LAYER_PATHS:
		_expect(ResourceLoader.exists(path), "%s exists" % path)
		if not ResourceLoader.exists(path):
			continue
		var image := _load_texture_image(path)
		_expect(image != null and image.detect_alpha() != Image.ALPHA_NONE, "%s has transparency" % path)
		if image != null:
			_expect(image.get_pixel(0, 0).a == 0.0, "%s keeps a transparent corner" % path)

	for cloud_path in [TRANSPARENT_LAYER_PATHS[0], TRANSPARENT_LAYER_PATHS[1]]:
		if not ResourceLoader.exists(cloud_path):
			continue
		var cloud := _load_texture_image(cloud_path)
		var seamless := true
		for y in cloud.get_height():
			if cloud.get_pixel(0, y) != cloud.get_pixel(cloud.get_width() - 1, y):
				seamless = false
				break
		_expect(seamless, "%s has matching wrap columns" % cloud_path)

	var backdrop := _instantiate_scene(BACKDROP_SCENE_PATH)
	if backdrop == null:
		return
	add_child(backdrop)
	_expect(is_equal_approx(float(backdrop.get("far_cloud_speed")), 4.0), "far clouds move at 4 pixels per second")
	_expect(is_equal_approx(float(backdrop.get("near_cloud_speed")), 8.0), "near clouds move at 8 pixels per second")
	_expect(backdrop.get_node_or_null("AmbientAnimation") is AnimationPlayer, "backdrop authors an AnimationPlayer")

	var animated_paths: Array[NodePath] = [
		"Foliage/FoliageLeft",
		"Foliage/FoliageRight",
		"Notes/Note1",
		"Notes/Note2",
		"Notes/Note3",
	]
	for node_path in animated_paths:
		var animated := backdrop.get_node_or_null(node_path) as AnimatedSprite2D
		_expect(animated != null, "%s is an authored AnimatedSprite2D" % node_path)
		if animated != null and animated.sprite_frames != null:
			_expect(animated.sprite_frames.get_frame_count(&"default") == 4, "%s has four animation frames" % node_path)
			_expect(animated.sprite_frames.get_animation_loop(&"default"), "%s loops" % node_path)

	var pile_paths: Array[NodePath] = [
		"ReagentLights/TableRed",
		"ReagentLights/TableGreen",
		"ReagentLights/TableBlue",
		"ReagentLights/ShelfRed",
		"ReagentLights/ShelfGreen",
		"ReagentLights/ShelfBlue",
	]
	var pile_seeds: Array[int] = []
	for node_path in pile_paths:
		var pile := backdrop.get_node_or_null(node_path)
		_expect(pile != null, "%s is authored as a crystal pile" % node_path)
		if pile == null:
			continue
		_expect(pile.has_method(&"set_crystal_color"), "%s exposes crystal color tuning" % node_path)
		_expect(pile.has_method(&"set_glow_strength"), "%s exposes glow tuning" % node_path)
		_expect(pile.has_method(&"set_emitting"), "%s exposes emission control" % node_path)
		_expect(pile.get_node_or_null("DriftMotes") is GPUParticles2D, "%s authors drifting motes" % node_path)
		if _has_property(pile, &"random_seed"):
			pile_seeds.append(int(pile.get("random_seed")))
	_expect(pile_seeds.size() == 6, "all six crystal piles expose a random seed")
	if pile_seeds.size() == 6:
		var unique_seeds: Dictionary = {}
		for seed in pile_seeds:
			unique_seeds[seed] = true
		_expect(unique_seeds.size() == 6, "menu crystal piles use staggered random seeds")
	var table_red := backdrop.get_node_or_null("ReagentLights/TableRed") as Node2D
	var shelf_red := backdrop.get_node_or_null("ReagentLights/ShelfRed") as Node2D
	_expect(
		table_red != null and shelf_red != null and shelf_red.scale.x < table_red.scale.x,
		"shelf deposits are smaller than table piles"
	)
	backdrop.set("reagent_glow_strength", 0.4)
	backdrop.call(&"apply_tuning")
	if table_red != null and _has_property(table_red, &"glow_strength"):
		_expect(is_equal_approx(float(table_red.get("glow_strength")), 0.4), "backdrop glow tuning reaches crystal piles")

	var far_clouds := backdrop.get_node_or_null("CloudWindow/FarClouds") as Control
	if far_clouds != null:
		var tile := far_clouds.get_node_or_null("TileA") as TextureRect
		var start_x := tile.position.x if tile != null else 0.0
		far_clouds.call(&"_process", 1.0)
		_expect(tile != null and tile.position.x > start_x, "positive cloud speed moves strips right")


func _test_main_menu_navigation() -> void:
	var start_menu := _instantiate_scene(START_MENU_SCENE_PATH)
	if start_menu == null:
		return
	add_child(start_menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var menu := start_menu.get_node_or_null("MainMenu")
	_expect(menu != null, "StartMenu instances MainMenu")
	_expect(start_menu.get_node_or_null("SettingsMenu") == null, "StartMenu does not instance pause Settings")
	if menu == null:
		return

	var commands := menu.get_node_or_null("CommandPanel/MainCommands") as Control
	var settings_view := menu.get_node_or_null("CommandPanel/SettingsView") as Control
	var new_game := menu.get_node_or_null("CommandPanel/MainCommands/NewGame/Button") as Button
	var settings := menu.get_node_or_null("CommandPanel/MainCommands/Settings/Button") as Button
	var quit := menu.get_node_or_null("CommandPanel/MainCommands/Quit/Button") as Button
	_expect(commands != null and settings_view != null, "menu authors replaceable command and settings views")
	_expect(new_game != null and settings != null and quit != null, "menu authors three text commands")
	_expect(_count_nodes_of_type(menu, "TextureButton") == 0, "main menu no longer uses painted TextureButtons")
	if new_game == null or settings == null or quit == null or commands == null or settings_view == null:
		return

	_expect(new_game.has_focus(), "New game receives default focus")
	menu.call(&"_on_settings_pressed")
	await get_tree().process_frame
	_expect(not commands.visible and settings_view.visible, "Settings replaces the command list")

	var close_count: Array[int] = [0]
	if settings_view.has_signal(&"close_requested"):
		settings_view.connect(&"close_requested", func() -> void: close_count[0] += 1)
		settings_view.emit_signal(&"close_requested")
		await get_tree().process_frame
		_expect(commands.visible and not settings_view.visible, "Back restores the command list")
		_expect(settings.has_focus(), "Back restores focus to Settings")
		_expect(close_count[0] == 1, "settings emits one close request")

		menu.call(&"_on_settings_pressed")
		await get_tree().process_frame
		var cancel_event := InputEventAction.new()
		cancel_event.action = &"ui_cancel"
		cancel_event.pressed = true
		settings_view.call(&"_unhandled_input", cancel_event)
		await get_tree().process_frame
		_expect(commands.visible and not settings_view.visible, "Escape restores the command list")
		_expect(settings.has_focus(), "Escape restores focus to Settings")

	_expect(menu.has_method(&"set_interaction_enabled"), "MainMenu exposes transition interaction locking")
	if menu.has_method(&"set_interaction_enabled"):
		menu.call(&"set_interaction_enabled", false)
		_expect(new_game.disabled and settings.disabled and quit.disabled, "transition lock disables every command")
		menu.call(&"set_interaction_enabled", true)
		_expect(not new_game.disabled and not settings.disabled and not quit.disabled, "interaction can be restored")


func _instantiate_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads as PackedScene" % path)
	if packed == null:
		return null
	var instance := packed.instantiate()
	_owned_nodes.append(instance)
	return instance


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _load_texture_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	return texture.get_image()


func _count_nodes_of_type(root: Node, type_name: String) -> int:
	var count := 1 if root.is_class(type_name) else 0
	for child in root.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _free_owned_nodes() -> void:
	while not _owned_nodes.is_empty():
		var node: Node = _owned_nodes.pop_back()
		if is_instance_valid(node):
			node.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
