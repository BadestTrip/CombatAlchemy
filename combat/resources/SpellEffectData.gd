# SpellEffectData.gd
# Create this as a Resource nested inside a SpellRecipeData resource.
# It describes one data-driven combat operation; ChantResolver applies it.
extends Resource
class_name SpellEffectData


# These generic operations cover the current authored chants.
# A few extra operations preserve existing MVP behavior without hardcoded values.
enum EffectType {
	DAMAGE_TARGET,
	DAMAGE_ALL_ENEMIES,
	DAMAGE_ALL_MAGES,
	SHIELD_ALL_MAGES,
	SHIELD_RANDOM_MAGE,
	HEAL_TARGET_ENEMY,
	APPLY_STATUS_TARGET,
	RANDOM_HITS_ENEMIES,
	DISCARD_RANDOM_MAGE_CARD,
	MODIFY_TARGET_NEXT_ATTACK,
	SWAP_RANDOM_ENEMY_INTENTS,
	REPEAT_PREVIOUS_SPELL,
	RANDOM_UNIT_DAMAGE,
	LOG_ONLY,
	DAMAGE_RANDOM_MAGE,
	SHIELD_TARGET_ENEMY,
	HEAL_ALL_MAGES,
	MODIFY_ALL_ENEMIES_NEXT_ATTACK,
	QUIET_WARD,
	CONDITIONAL_PREVIOUS_ROUND_DAMAGE,
	IDIOT_STAR_RANDOM_OUTCOME,
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
