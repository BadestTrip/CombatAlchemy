# CombatBalanceData.gd
# Create this as a Resource and assign it to CombatScene in Inspector.
# It contains design-time tuning values, never temporary combat state.
extends Resource
class_name CombatBalanceData


# These values control phase order and the pauses between visible actions.
@export_group("Round Flow")
@export var enemy_action_delay_seconds: float = 0.25
@export var next_round_delay_seconds: float = 0.35
@export var auto_start_combat: bool = true
@export var enemy_phase_after_chant: bool = true

# These values control rune placement in the active 1v1 prototype.
@export_group("Rune / Chant")
@export var required_chant_cards: int = 3
@export var allow_repeated_runes: bool = true
@export var auto_advance_slot_after_rune_pick: bool = true
@export var clear_chant_after_cast: bool = true
@export var rune_button_width: float = 145.0
@export var rune_button_height: float = 72.0

# These values control the central retractable rune wheel.
@export_group("Rune Wheel UI")
@export var rune_wheel_starts_expanded: bool = true
@export var auto_expand_wheel_on_slot_click: bool = true
@export var auto_retract_wheel_after_rune_pick: bool = false
@export var rune_wheel_radius: float = 220.0
@export var rune_wheel_start_angle_degrees: float = -90.0
@export var rune_wheel_clockwise: bool = true
@export var rune_wheel_tween_seconds: float = 0.2

# These values control discovery popups, the spellbook, and cast history.
@export_group("Discovery")
@export var discovery_popup_auto_hide_seconds: float = 2.5
@export var visible_cast_history_entries: int = 10
@export var reveal_initially_discovered_spells: bool = true
@export var max_cast_history_entries: int = 20
@export var track_fallback_casts: bool = true
@export var announce_new_discoveries: bool = true

# These values control the cast presentation sequence.
@export_group("Chant Presentation")
@export var shout_each_rune_seconds: float = 0.45
@export var shout_between_runes_seconds: float = 0.15
@export var spell_result_banner_seconds: float = 1.4

# These values control floating unit HUD update behavior.
@export_group("Floating HUD")
@export var hud_use_signal_updates: bool = true

# These values control hidden-by-default secondary panels.
@export_group("Secondary Panels")
@export var secondary_panels_start_closed: bool = true
@export var only_one_secondary_panel_open: bool = true
@export var block_combat_input_when_secondary_panel_open: bool = false

# These values define the player unit's combat stats.
@export_group("Mage Defaults")
@export var default_mage_max_hp: int = 20
@export var default_mage_starting_shield: int = 0

# These values define the enemy unit's combat stats and intent tuning.
@export_group("Enemy Defaults")
@export var default_enemy_max_hp: int = 15
@export var default_enemy_starting_shield: int = 0
@export var default_enemy_base_attack: int = 3
@export_range(0.0, 1.0, 0.01) var enemy_guard_chance: float = 0.25
@export var enemy_guard_shield: int = 3

# Unknown chants use these values in the existing fallback priority order.
@export_group("Fallback Miscasts")
@export var allow_fallback_miscasts: bool = true
@export var log_unknown_chants: bool = true
@export var echo_miscast_enemy_damage: int = 2
@export var echo_miscast_mage_damage: int = 1
@export var overchewed_word_damage: int = 2
@export_range(0.0, 1.0, 0.01) var overchewed_backfire_chance: float = 0.25
@export var overchewed_backfire_damage: int = 1
@export var unstable_spark_damage: int = 3
@export var weak_ward_shield: int = 1
@export var mumbled_spark_damage: int = 1

# These values control rune presentation debug text only.
@export_group("UI Debug")
@export var show_card_display_names: bool = true
@export var show_card_visual_hints: bool = true
