extends Resource
class_name CombatTutorialPresentationData


@export_group("Visibility")
@export var hide_normal_ui_during_tutorial: bool = true
@export var reveal_full_ui_after_tutorial: bool = true
@export var start_rune_wheel_retracted: bool = true
@export var hide_debug_buttons_during_tutorial: bool = true

@export_group("Objective Text")
@export var objective_font_size: int = 32
@export var objective_panel_min_height: float = 140.0
@export var objective_color: Color = Color(1.0, 0.9, 0.56, 1.0)
@export var continue_prompt: String = "Press Space / Click to continue"

@export_group("Overlay")
@export_range(0.0, 1.0, 0.01) var dim_overlay_alpha: float = 0.56
@export var dim_overlay_color: Color = Color(0.0, 0.0, 0.0, 0.56)

@export_group("Highlight")
@export var highlight_scale: float = 1.045
@export var highlight_pulse_seconds: float = 0.48
@export var highlight_gold: Color = Color(1.0, 0.82, 0.28, 1.0)

@export_group("Tutorial Text")
@export_multiline var text_intro: String = "This is your first duel. First, open your runes."
@export_multiline var text_open_runes: String = "Chants are formed by 3 runes.\nPress Runes to reveal your rune wheel."
@export_multiline var text_choose_asha: String = "First chant: ASHA -> VORO -> KETH\nClick ASHA."
@export_multiline var text_choose_voro: String = "Good. Now click VORO."
@export_multiline var text_choose_keth: String = "Now click KETH."
@export_multiline var text_cast: String = "The chant is ready.\nClick Cast."
@export_multiline var text_result: String = "Razor Comet is now a learned spell.\nDifferent rune orders create differemt results."
@export_multiline var text_enemy_intent: String = "Enemy intent shows what the enemy will do after your chant."
@export_multiline var text_open_log: String = "Open Log to read what happened."
@export_multiline var text_explain_log: String = "The Log records combat events and spell effects."
@export_multiline var text_open_history: String = "Open History to see chants you tried."
@export_multiline var text_explain_history: String = "History remembers your attempted chants this fight."
@export_multiline var text_open_spellbook: String = "Open Chants to see learned spells."
@export_multiline var text_explain_spellbook: String = "Discovered spells are listed here."
@export_multiline var text_free_experiment: String = "Now experiment with any three runes."
