# CombatBalanceData.gd
# Create this as a Resource and assign it to CombatScene managers in Inspector.
# It contains design-time tuning values, never temporary combat state.
extends Resource
class_name CombatBalanceData


# These values are unused in the full-rune-palette prototype.
# They are kept for possible deck/hand variant tests later.
@export_group("Hand / Deck")
@export var starting_hand_size: int = 3
@export var max_hand_size: int = 3
@export var required_chant_cards: int = 3
@export var copies_per_symbol_in_shared_deck: int = 3
@export var reshuffle_discard_when_deck_empty: bool = true
@export var use_scripted_opening_hands: bool = true

# These values control phase order and the pauses between visible actions.
@export_group("Round Flow")
@export var enemy_action_delay_seconds: float = 0.25
@export var next_round_delay_seconds: float = 0.35
@export var auto_start_combat: bool = true
@export var enemy_phase_after_chant: bool = true
# Unused by the current full-rune-palette combat loop.
# Kept for possible deck/hand variant tests later.
@export var draw_to_max_hand_at_round_end: bool = true

# These values control rune placement in the active 1v1 prototype.
@export_group("Rune Palette")
@export var allow_repeated_runes: bool = true
@export var auto_advance_slot_after_rune_pick: bool = true
@export var clear_chant_after_cast: bool = true
@export var rune_button_width: float = 145.0
@export var rune_button_height: float = 72.0

# These values control the modular ritual circle UI.
@export_group("Rune Circle UI")
@export var rune_wheel_starts_expanded: bool = true
@export var auto_expand_wheel_on_slot_click: bool = true
@export var auto_retract_wheel_after_rune_pick: bool = false
@export var rune_wheel_radius: float = 220.0
@export var rune_wheel_tween_seconds: float = 0.2

# These values control the cast presentation sequence.
@export_group("Chant Presentation")
@export var shout_each_rune_seconds: float = 0.45
@export var shout_between_runes_seconds: float = 0.15
@export var spell_result_banner_seconds: float = 1.4

# These values control hidden-by-default secondary panels.
@export_group("Secondary Panels")
@export var secondary_panels_start_closed: bool = true
@export var only_one_secondary_panel_open: bool = true
@export var block_combat_input_when_secondary_panel_open: bool = false

# These are applied when the player MageUnit still uses its script defaults.
@export_group("Mage Defaults")
@export var default_mage_max_hp: int = 20
@export var default_mage_starting_shield: int = 0

# These are applied when an EnemyUnit still uses its script defaults.
@export_group("Enemy Defaults")
@export var default_enemy_max_hp: int = 15
@export var default_enemy_base_attack: int = 3
@export_range(0.0, 1.0, 0.01) var enemy_guard_chance: float = 0.25
@export var enemy_guard_shield: int = 3

# Unknown chants use these values in the existing fallback priority order.
@export_group("Fallback Miscasts")
@export var echo_miscast_enemy_damage: int = 2
@export var echo_miscast_mage_damage: int = 1
@export var overchewed_word_damage: int = 2
@export_range(0.0, 1.0, 0.01) var overchewed_backfire_chance: float = 0.25
@export var overchewed_backfire_damage: int = 1
@export var unstable_spark_damage: int = 3
@export var weak_ward_shield: int = 1
@export var mumbled_spark_damage: int = 1

# These values control graybox card/rune presentation only.
# The legacy names still drive rune buttons for compatibility.
@export_group("UI Debug")
@export var show_card_display_names: bool = true
@export var show_card_visual_hints: bool = true
@export var card_button_width: float = 145.0
@export var card_button_height: float = 72.0
