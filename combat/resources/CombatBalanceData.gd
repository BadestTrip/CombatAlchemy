# CombatBalanceData.gd
# Create this as a Resource and assign it to CombatScene managers in Inspector.
# It contains design-time tuning values, never temporary combat state.
extends Resource
class_name CombatBalanceData


# These values control deck size and how many cards each mage holds.
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
@export var draw_to_max_hand_at_round_end: bool = true

# These are applied when a MageUnit still uses its script defaults.
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

# These values control graybox card presentation only.
@export_group("UI Debug")
@export var show_card_display_names: bool = true
@export var show_card_visual_hints: bool = true
@export var card_button_width: float = 145.0
@export var card_button_height: float = 72.0
