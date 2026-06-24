# SpellEffectData.gd
# Create this as a Resource nested inside a SpellRecipeData resource.
# It describes one data-driven combat operation; ChantResolver applies it.
extends Resource
class_name SpellEffectData


# These generic operations cover the current authored chants.
# A few extra operations preserve existing MVP behavior without hardcoded values.
enum EffectType {
	DAMAGE_TARGET = 0,
	DAMAGE_ALL_ENEMIES = 1,
	DAMAGE_ALL_MAGES = 2,
	SHIELD_ALL_MAGES = 3,
	SHIELD_RANDOM_MAGE = 4,
	HEAL_TARGET_ENEMY = 5,
	APPLY_STATUS_TARGET = 6,
	RANDOM_HITS_ENEMIES = 7,
	MODIFY_TARGET_NEXT_ATTACK = 9,
	SWAP_RANDOM_ENEMY_INTENTS = 10,
	REPEAT_PREVIOUS_SPELL = 11,
	RANDOM_UNIT_DAMAGE = 12,
	LOG_ONLY = 13,
	DAMAGE_RANDOM_MAGE = 14,
	SHIELD_TARGET_ENEMY = 15,
	HEAL_ALL_MAGES = 16,
	MODIFY_ALL_ENEMIES_NEXT_ATTACK = 17,
	QUIET_WARD = 18,
	CONDITIONAL_PREVIOUS_ROUND_DAMAGE = 19,
	IDIOT_STAR_RANDOM_OUTCOME = 20,
}


# Select the operation this resource applies.
@export var effect_type: EffectType = EffectType.DAMAGE_TARGET

# DAMAGE and SHIELD effects use amount. MODIFY effects usually use a negative amount.
@export var amount: int = 0

# RANDOM_HITS_ENEMIES and RANDOM_UNIT_DAMAGE use hit_count.
@export var hit_count: int = 1

# APPLY_STATUS_TARGET and other probabilistic effects use chance.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0

# DAMAGE_TARGET can bypass enemy shield when this is enabled.
@export var ignore_shield: bool = false

# APPLY_STATUS_TARGET uses status_id, and special data effects may use it as a label.
@export var status_id: String = ""

# APPLY_STATUS_TARGET uses status_duration.
@export var status_duration: int = 1

# LOG_ONLY uses this text. Other effects may also append it after applying.
@export_multiline var log_text: String = ""
