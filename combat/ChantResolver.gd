# ChantResolver.gd
# Attach this script to the ChantResolver node in CombatScene.tscn.
# It builds a chant lookup from Inspector-assigned SpellRecipeData resources,
# applies their SpellEffectData entries, and handles balance-driven miscasts.
extends Node
class_name ChantResolver


# Emitted after a chant has been fully applied.
signal chant_resolved(result: Dictionary)


# Add SpellRecipeData resources here. Order inside each recipe remains meaningful.
@export_group("Spell Recipes")
@export var spell_recipes: Array[SpellRecipeData] = []

# Assign CombatBalance_Default.tres here to tune fallback miscasts.
@export_group("Balance")
@export var balance: CombatBalanceData

# These switches make data setup easier to diagnose without changing gameplay code.
@export_group("Debug")
@export var log_unknown_chants: bool = true
@export var allow_fallback_miscasts: bool = true


# Authored chant keys map directly to editable SpellRecipeData resources.
var spellbook: Dictionary = {}

# Infinite Wink reads this runtime history. It should not be exported.
var previous_successful_spell_key: String = ""

# A missing Inspector resource uses this safe in-memory default.
var _fallback_balance: CombatBalanceData


# Godot calls this after exported recipe resources have been assigned.
func _ready() -> void:
	_build_spellbook()


# RoundManager calls this after the player presses Cast.
# Card order is preserved when building "word_word_word".
func resolve_chant(
	symbols: Array[SymbolCardData],
	target: EnemyUnit,
	context: Dictionary
) -> Dictionary:
	if symbols.size() != 3:
		return _invalid_result("A chant requires exactly three symbols.")

	var symbol_ids: PackedStringArray = []
	var spoken_words: PackedStringArray = []
	for card: SymbolCardData in symbols:
		if card == null:
			return _invalid_result("A chant slot is empty.")
		symbol_ids.append(card.symbol_id)
		spoken_words.append(card.spoken_word)

	var chant_key := "_".join(symbol_ids)
	var log_lines: Array[String] = []
	_append_shouted_words(log_lines, spoken_words, context)

	var result: Dictionary
	if spellbook.has(chant_key):
		result = _resolve_authored_chant(
			chant_key,
			spoken_words,
			target,
			context,
			log_lines
		)
	elif allow_fallback_miscasts:
		result = _resolve_fallback_miscast(
			chant_key,
			symbol_ids,
			spoken_words,
			target,
			context,
			log_lines
		)
	else:
		log_lines.append("The words fail to lock, but fallback miscasts are disabled.")
		result = _make_result(
			chant_key,
			spoken_words,
			"Unknown Chant",
			"fallback",
			false,
			log_lines
		)

	chant_resolved.emit(result)
	return result


# Build the runtime lookup from data instead of registering 30 keys in code.
func _build_spellbook() -> void:
	spellbook.clear()

	for recipe: SpellRecipeData in spell_recipes:
		if recipe == null:
			continue

		var key := recipe.get_chant_key()
		if key.is_empty():
			push_warning("Spell recipe has empty chant key.")
			continue
		if spellbook.has(key):
			push_warning("Duplicate spell key: " + key)
			continue

		# The dictionary stores the Resource itself so every effect remains editable.
		spellbook[key] = recipe


# Known chants apply their effect resources in array order.
func _resolve_authored_chant(
	chant_key: String,
	spoken_words: PackedStringArray,
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> Dictionary:
	var recipe := spellbook[chant_key] as SpellRecipeData
	if recipe == null:
		return _invalid_result("Spell data could not be loaded.")

	log_lines.append("The chant locks: %s." % recipe.result_name)
	_apply_recipe_effects(recipe, target, context, log_lines)

	# Repeat effects read the previous authored recipe and do not replace it.
	if not _recipe_repeats_previous_spell(recipe):
		previous_successful_spell_key = chant_key

	return _make_result(
		chant_key,
		spoken_words,
		recipe.result_name,
		recipe.result_type,
		true,
		log_lines,
		recipe
	)


# This is the single data-driven effect dispatch point.
# Idiot Star is a grouped random outcome, so its marker consumes the remaining
# supporting effects instead of applying all of them sequentially.
func _apply_recipe_effects(
	recipe: SpellRecipeData,
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	for effect: SpellEffectData in recipe.effects:
		if effect == null:
			continue
		if effect.effect_type == SpellEffectData.EffectType.IDIOT_STAR_RANDOM_OUTCOME:
			_apply_idiot_star_outcome(recipe.effects, target, context, log_lines)
			return

		var clamped_chance := clampf(effect.chance, 0.0, 1.0)
		if clamped_chance < 1.0 and randf() >= clamped_chance:
			continue

		_apply_effect(effect, target, context, log_lines)


# Each match branch explains which exported effect fields it consumes.
func _apply_effect(
	effect: SpellEffectData,
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	match effect.effect_type:
		SpellEffectData.EffectType.DAMAGE_TARGET:
			for hit_index: int in range(maxi(1, effect.hit_count)):
				_damage_enemy(target, effect.amount, log_lines, effect.ignore_shield)

		SpellEffectData.EffectType.DAMAGE_ALL_ENEMIES:
			_damage_all_enemies(context, effect.amount, log_lines)

		SpellEffectData.EffectType.DAMAGE_ALL_MAGES:
			_damage_all_mages(context, effect.amount, log_lines)

		SpellEffectData.EffectType.SHIELD_ALL_MAGES:
			_shield_all_mages(context, effect.amount, log_lines)

		SpellEffectData.EffectType.SHIELD_RANDOM_MAGE:
			var shielded_mage := _random_living_mage(context)
			if shielded_mage != null:
				shielded_mage.gain_shield(effect.amount)
				_append_effect_log(
					log_lines,
					effect.log_text,
					target,
					shielded_mage,
					effect.amount,
					"%s gains %d shield." % [
						shielded_mage.mage_name,
						effect.amount
					]
				)

		SpellEffectData.EffectType.HEAL_TARGET_ENEMY:
			if _is_valid_enemy(target):
				target.heal(effect.amount)
				_append_effect_log(
					log_lines,
					effect.log_text,
					target,
					null,
					effect.amount,
					"%s is healed for %d." % [target.enemy_name, effect.amount]
				)

		SpellEffectData.EffectType.APPLY_STATUS_TARGET:
			if _is_valid_enemy(target):
				target.apply_status(effect.status_id, effect.status_duration)
				_append_effect_log(
					log_lines,
					effect.log_text,
					target,
					null,
					effect.amount,
					"%s gains status '%s'." % [target.enemy_name, effect.status_id]
				)

		SpellEffectData.EffectType.RANDOM_HITS_ENEMIES:
			for hit_index: int in range(maxi(0, effect.hit_count)):
				var random_enemy := _random_living_enemy(context)
				if random_enemy != null:
					_damage_enemy(random_enemy, effect.amount, log_lines)

		SpellEffectData.EffectType.DISCARD_RANDOM_MAGE_CARD:
			var discard_mage := _random_living_mage(context)
			if discard_mage != null:
				var discarded := discard_mage.discard_random_card()
				if discarded != null:
					log_lines.append(
						"%s loses a random card: %s." % [
							discard_mage.mage_name,
							discarded.spoken_word
						]
					)

		SpellEffectData.EffectType.MODIFY_TARGET_NEXT_ATTACK:
			if _is_valid_enemy(target):
				target.modify_next_attack_damage(effect.amount)
				var direction := "less" if effect.amount < 0 else "more"
				log_lines.append(
					"%s will deal %d %s damage next attack." % [
						target.enemy_name,
						absi(effect.amount),
						direction
					]
				)

		SpellEffectData.EffectType.SWAP_RANDOM_ENEMY_INTENTS:
			_swap_random_enemy_intents(
				target,
				context,
				effect.amount,
				log_lines
			)

		SpellEffectData.EffectType.REPEAT_PREVIOUS_SPELL:
			_repeat_previous_spell(
				target,
				context,
				effect.amount,
				log_lines
			)

		SpellEffectData.EffectType.RANDOM_UNIT_DAMAGE:
			_damage_random_living_units(
				context,
				effect.amount,
				effect.hit_count,
				log_lines
			)

		SpellEffectData.EffectType.LOG_ONLY:
			if not effect.log_text.is_empty():
				log_lines.append(effect.log_text)

		SpellEffectData.EffectType.DAMAGE_RANDOM_MAGE:
			var damaged_mage := _random_living_mage(context)
			if damaged_mage != null:
				damaged_mage.take_damage(effect.amount)
				_append_effect_log(
					log_lines,
					effect.log_text,
					target,
					damaged_mage,
					effect.amount,
					"%s takes %d damage." % [
						damaged_mage.mage_name,
						effect.amount
					]
				)

		SpellEffectData.EffectType.SHIELD_TARGET_ENEMY:
			if _is_valid_enemy(target):
				target.gain_shield(effect.amount)
				log_lines.append(
					"%s gains %d shield." % [target.enemy_name, effect.amount]
				)

		SpellEffectData.EffectType.HEAL_ALL_MAGES:
			for mage: MageUnit in _living_mages(context):
				mage.heal(effect.amount)
			log_lines.append(
				"Every living mage is healed for %d." % effect.amount
			)

		SpellEffectData.EffectType.MODIFY_ALL_ENEMIES_NEXT_ATTACK:
			for enemy: EnemyUnit in _living_enemies(context):
				enemy.modify_next_attack_damage(effect.amount)
			var direction := "less" if effect.amount < 0 else "more"
			log_lines.append(
				"All enemies will deal %d %s damage next attack." % [
					absi(effect.amount),
					direction
				]
			)

		SpellEffectData.EffectType.QUIET_WARD:
			_apply_quiet_ward(target, context, log_lines)

		SpellEffectData.EffectType.CONDITIONAL_PREVIOUS_ROUND_DAMAGE:
			var damage := effect.amount
			if _is_valid_enemy(target) and target.was_attacked_last_round:
				damage += effect.hit_count
				if not effect.log_text.is_empty():
					log_lines.append(effect.log_text)
			_damage_enemy(target, damage, log_lines, effect.ignore_shield)

		SpellEffectData.EffectType.IDIOT_STAR_RANDOM_OUTCOME:
			# The recipe-level loop handles this grouped effect before dispatch.
			pass


# Unknown chants keep the original five-priority fallback behavior.
# Every balance number now comes from CombatBalanceData.
func _resolve_fallback_miscast(
	chant_key: String,
	symbol_ids: PackedStringArray,
	spoken_words: PackedStringArray,
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> Dictionary:
	if log_unknown_chants:
		print("Unknown chant resolved as fallback: ", chant_key)
	log_lines.append("The words fail to lock.")

	var settings := _get_balance()
	var result_name := ""
	var counts: Dictionary = {}
	for symbol_id: String in symbol_ids:
		counts[symbol_id] = int(counts.get(symbol_id, 0)) + 1

	# Priority 1: three identical symbols.
	if counts.size() == 1:
		result_name = "Echo Miscast"
		var random_enemy := _random_living_enemy(context)
		var random_mage := _random_living_mage(context)
		if random_enemy != null:
			_damage_enemy(
				random_enemy,
				settings.echo_miscast_enemy_damage,
				log_lines
			)
		if random_mage != null:
			random_mage.take_damage(settings.echo_miscast_mage_damage)
			log_lines.append(
				"%s takes %d backfire damage." % [
					random_mage.mage_name,
					settings.echo_miscast_mage_damage
				]
			)
	# Priority 2: any repeated symbol.
	elif _has_repeated_symbol(counts):
		result_name = "Overchewed Word"
		_damage_enemy(target, settings.overchewed_word_damage, log_lines)
		if randf() < clampf(settings.overchewed_backfire_chance, 0.0, 1.0):
			var backfire_mage := _random_living_mage(context)
			if backfire_mage != null:
				backfire_mage.take_damage(settings.overchewed_backfire_damage)
				log_lines.append(
					"%s takes %d backfire damage." % [
						backfire_mage.mage_name,
						settings.overchewed_backfire_damage
					]
				)
	# Priority 3: any ZUN.
	elif symbol_ids.has("zun"):
		result_name = "Unstable Spark"
		var spark_target := _random_living_enemy(context)
		if spark_target != null:
			_damage_enemy(
				spark_target,
				settings.unstable_spark_damage,
				log_lines
			)
	# Priority 4: any ELUM.
	elif symbol_ids.has("elum"):
		result_name = "Weak Ward"
		_shield_all_mages(context, settings.weak_ward_shield, log_lines)
	# Priority 5: every other unknown order.
	else:
		result_name = "Mumbled Spark"
		_damage_enemy(target, settings.mumbled_spark_damage, log_lines)

	return _make_result(
		chant_key,
		spoken_words,
		result_name,
		"fallback",
		false,
		log_lines
	)


# Infinite Wink applies the previous recipe without consuming more cards.
func _repeat_previous_spell(
	target: EnemyUnit,
	context: Dictionary,
	fallback_shield: int,
	log_lines: Array[String]
) -> void:
	if (
		previous_successful_spell_key.is_empty()
		or not spellbook.has(previous_successful_spell_key)
	):
		log_lines.append("There is no earlier spell to repeat.")
		_shield_all_mages(context, fallback_shield, log_lines)
		return

	var previous_recipe := (
		spellbook[previous_successful_spell_key] as SpellRecipeData
	)
	if previous_recipe == null:
		return
	log_lines.append(
		"Infinite Wink repeats %s for free." % previous_recipe.result_name
	)
	_apply_recipe_effects(previous_recipe, target, context, log_lines)


# Idiot Star uses one marker plus four supporting data effects:
# target damage, all-mage shield, all-enemy damage, and all-mage damage.
func _apply_idiot_star_outcome(
	effects: Array[SpellEffectData],
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	var violence := _find_effect(
		effects,
		SpellEffectData.EffectType.DAMAGE_TARGET
	)
	var protection := _find_effect(
		effects,
		SpellEffectData.EffectType.SHIELD_ALL_MAGES
	)
	var chaos_enemies := _find_effect(
		effects,
		SpellEffectData.EffectType.DAMAGE_ALL_ENEMIES
	)
	var chaos_mages := _find_effect(
		effects,
		SpellEffectData.EffectType.DAMAGE_ALL_MAGES
	)

	match randi_range(0, 2):
		0:
			log_lines.append("Idiot Star chooses violence.")
			if violence != null:
				_apply_effect(violence, target, context, log_lines)
		1:
			log_lines.append("Idiot Star becomes unexpectedly protective.")
			if protection != null:
				_apply_effect(protection, target, context, log_lines)
		2:
			log_lines.append("Idiot Star cannot tell friend from foe.")
			if chaos_enemies != null:
				_apply_effect(chaos_enemies, target, context, log_lines)
			if chaos_mages != null:
				_apply_effect(chaos_mages, target, context, log_lines)


# Wrong Door swaps visible intents. With fewer than two enemies it preserves the
# old fallback and damages the selected target by the resource's amount.
func _swap_random_enemy_intents(
	target: EnemyUnit,
	context: Dictionary,
	fallback_damage: int,
	log_lines: Array[String]
) -> void:
	var enemies := _living_enemies(context)
	if enemies.size() < 2:
		_damage_enemy(target, fallback_damage, log_lines)
		return

	enemies.shuffle()
	var first: EnemyUnit = enemies[0]
	var second: EnemyUnit = enemies[1]
	var first_intent := first.current_intent.duplicate(true)
	first.current_intent = second.current_intent.duplicate(true)
	second.current_intent = first_intent
	log_lines.append(
		"%s and %s walk through the wrong doors and swap intents." % [
			first.enemy_name,
			second.enemy_name
		]
	)


# Quiet Ward cancels the first visible non-attack intent.
func _apply_quiet_ward(
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	for enemy: EnemyUnit in _living_enemies(context):
		var intent_type := String(enemy.current_intent.get("type", ""))
		if intent_type != "attack" and intent_type != "skip":
			enemy.current_intent = {
				"type": "skip",
				"description": (
					"%s's special intent is blocked by Quiet Ward."
					% enemy.enemy_name
				)
			}
			log_lines.append("Quiet Ward blocks %s's intent." % enemy.enemy_name)
			return

	if _is_valid_enemy(target):
		target.apply_status("special_blocked")
	log_lines.append("Quiet Ward waits, but no special intent is active.")


# RANDOM_UNIT_DAMAGE hits different living units when possible, preserving Hot
# Potato's two-target behavior while also supporting Meat Lightning.
func _damage_random_living_units(
	context: Dictionary,
	amount: int,
	hit_count: int,
	log_lines: Array[String]
) -> void:
	var units := _all_living_units(context)
	units.shuffle()
	for hit_index: int in range(mini(maxi(0, hit_count), units.size())):
		_damage_any_unit(units[hit_index], amount, log_lines)


# Repeated combat helpers apply effects and add consistent log lines.
func _damage_enemy(
	target: EnemyUnit,
	amount: int,
	log_lines: Array[String],
	ignore_shield: bool = false
) -> void:
	if not _is_valid_enemy(target) or amount <= 0:
		return
	target.take_damage(amount, ignore_shield)
	var shield_note := " and ignores shield" if ignore_shield else ""
	log_lines.append(
		"%s takes %d damage%s." % [target.enemy_name, amount, shield_note]
	)


func _damage_all_enemies(
	context: Dictionary,
	amount: int,
	log_lines: Array[String]
) -> void:
	for enemy: EnemyUnit in _living_enemies(context):
		_damage_enemy(enemy, amount, log_lines)


func _damage_all_mages(
	context: Dictionary,
	amount: int,
	log_lines: Array[String]
) -> void:
	for mage: MageUnit in _living_mages(context):
		mage.take_damage(amount)
		log_lines.append("%s takes %d damage." % [mage.mage_name, amount])


func _shield_all_mages(
	context: Dictionary,
	amount: int,
	log_lines: Array[String]
) -> void:
	for mage: MageUnit in _living_mages(context):
		mage.gain_shield(amount)
	log_lines.append("All living mages gain %d shield." % amount)


func _damage_any_unit(unit: Node, amount: int, log_lines: Array[String]) -> void:
	if unit is MageUnit:
		var mage := unit as MageUnit
		mage.take_damage(amount)
		log_lines.append("%s takes %d damage." % [mage.mage_name, amount])
	elif unit is EnemyUnit:
		_damage_enemy(unit as EnemyUnit, amount, log_lines)


# Context contains the runtime arrays owned by CombatManager.
func _living_mages(context: Dictionary) -> Array[MageUnit]:
	var living: Array[MageUnit] = []
	var context_mages: Array = context.get("mages", [])
	for value: Variant in context_mages:
		var mage := value as MageUnit
		if mage != null and mage.is_alive:
			living.append(mage)
	return living


func _living_enemies(context: Dictionary) -> Array[EnemyUnit]:
	var living: Array[EnemyUnit] = []
	var context_enemies: Array = context.get("enemies", [])
	for value: Variant in context_enemies:
		var enemy := value as EnemyUnit
		if enemy != null and enemy.is_alive:
			living.append(enemy)
	return living


func _all_living_units(context: Dictionary) -> Array[Node]:
	var units: Array[Node] = []
	for mage: MageUnit in _living_mages(context):
		units.append(mage)
	for enemy: EnemyUnit in _living_enemies(context):
		units.append(enemy)
	return units


func _random_living_mage(context: Dictionary) -> MageUnit:
	var living := _living_mages(context)
	if living.is_empty():
		return null
	return living.pick_random()


func _random_living_enemy(context: Dictionary) -> EnemyUnit:
	var living := _living_enemies(context)
	if living.is_empty():
		return null
	return living.pick_random()


func _is_valid_enemy(target: EnemyUnit) -> bool:
	return target != null and target.is_alive


# Fallback priority 2 uses this helper to detect any count of two or more.
func _has_repeated_symbol(counts: Dictionary) -> bool:
	for value: Variant in counts.values():
		if int(value) >= 2:
			return true
	return false


func _recipe_repeats_previous_spell(recipe: SpellRecipeData) -> bool:
	for effect: SpellEffectData in recipe.effects:
		if (
			effect != null
			and effect.effect_type == SpellEffectData.EffectType.REPEAT_PREVIOUS_SPELL
		):
			return true
	return false


func _find_effect(
	effects: Array[SpellEffectData],
	effect_type: SpellEffectData.EffectType
) -> SpellEffectData:
	for effect: SpellEffectData in effects:
		if effect != null and effect.effect_type == effect_type:
			return effect
	return null


# Resource log text supports a few readable placeholders without a template system.
func _append_effect_log(
	log_lines: Array[String],
	template: String,
	target: EnemyUnit,
	mage: MageUnit,
	amount: int,
	fallback_text: String
) -> void:
	if template.is_empty():
		log_lines.append(fallback_text)
		return

	var line := template.replace("{amount}", str(amount))
	line = line.replace(
		"{target}",
		target.enemy_name if target != null else "the target"
	)
	line = line.replace(
		"{mage}",
		mage.mage_name if mage != null else "a mage"
	)
	log_lines.append(line)


# The first three log lines make it clear which mage spoke each slot.
func _append_shouted_words(
	log_lines: Array[String],
	spoken_words: PackedStringArray,
	context: Dictionary
) -> void:
	var context_mages: Array = context.get("mages", [])
	for index: int in range(spoken_words.size()):
		var speaker_name := "Mage %d" % (index + 1)
		if index < context_mages.size():
			var mage := context_mages[index] as MageUnit
			if mage != null:
				speaker_name = mage.mage_name
		log_lines.append("%s shouts: %s!" % [speaker_name, spoken_words[index]])


# All successful and fallback paths preserve the UI's existing result shape.
func _make_result(
	chant_key: String,
	spoken_words: PackedStringArray,
	result_name: String,
	result_type: String,
	is_known: bool,
	log_lines: Array[String],
	recipe: SpellRecipeData = null
) -> Dictionary:
	return {
		"chant_key": chant_key,
		"spoken_words": spoken_words,
		"result_name": result_name,
		"result_type": result_type,
		"is_known": is_known,
		"recipe": recipe,
		"recipe_path": recipe.resource_path if recipe != null else "",
		"log_lines": log_lines
	}


# Invalid input should not crash combat, even though the UI prevents it.
func _invalid_result(message: String) -> Dictionary:
	return {
		"chant_key": "",
		"spoken_words": PackedStringArray(),
		"result_name": "Broken Chant",
		"result_type": "invalid",
		"is_known": false,
		"recipe": null,
		"recipe_path": "",
		"log_lines": [message]
	}


# Missing scene wiring should warn but should not crash fallback resolution.
func _get_balance() -> CombatBalanceData:
	if balance != null:
		return balance
	if _fallback_balance == null:
		_fallback_balance = CombatBalanceData.new()
		push_warning(
			"ChantResolver has no CombatBalanceData assigned; using script defaults."
		)
	return _fallback_balance
