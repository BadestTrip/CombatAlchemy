# ChantResolver.gd
# Attach this script to the ChantResolver node in CombatScene.tscn.
# It is the only script that knows authored chant combinations and spell effects.
# RoundManager gives it exactly three ordered cards, one target, and combat context.
extends Node
class_name ChantResolver


# Emitted after a chant has been fully applied.
# RoundManager listens to the returned Dictionary directly, while other future
# presentation systems can listen to this signal for sound or animation.
signal chant_resolved(result: Dictionary)


# Authored keys map to name, category, and an internal effect id.
var spellbook: Dictionary = {}

# Infinite Wink repeats this previous authored spell when one exists.
var previous_successful_spell_key: String = ""


# Godot calls this once when CombatScene is loaded.
func _ready() -> void:
	_build_spellbook()


# RoundManager calls this after the player presses Cast.
# The card order is preserved when building "word_word_word".
# This function applies the effect and returns player-facing result data.
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

	# Joining in array order makes ASHA-VORO-KETH different from ASHA-KETH-VORO.
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
	else:
		result = _resolve_fallback_miscast(
			chant_key,
			symbol_ids,
			spoken_words,
			target,
			context,
			log_lines
		)

	chant_resolved.emit(result)
	return result


# The 30 requested authored results are registered here.
# Effect ids are developer-only and never shown as hidden card meanings.
func _build_spellbook() -> void:
	spellbook.clear()

	# 12 workable spells.
	_add_spell("asha_voro_keth", "Razor Comet", "workable", "razor_comet")
	_add_spell("asha_elum_keth", "Bright Cut", "workable", "bright_cut")
	_add_spell("nox_keth_voro", "Hollow Push", "workable", "hollow_push")
	_add_spell("zun_voro_keth", "Crackbolt", "workable", "crackbolt")
	_add_spell("elum_mira_asha", "Return Glow", "workable", "return_glow")
	_add_spell("mira_keth_asha", "Reversed Blade", "workable", "reversed_blade")
	_add_spell("iri_asha_voro", "Scatterflare", "workable", "scatterflare")
	_add_spell("voro_bavo_keth", "Heavy Word", "workable", "heavy_word")
	_add_spell("nox_elum_mira", "Quiet Ward", "workable", "quiet_ward")
	_add_spell("asha_zun_iri", "Spark Rain", "workable", "spark_rain")
	_add_spell("keth_keth_voro", "Double Sever", "workable", "double_sever")
	_add_spell("elum_bavo_voro", "Stone Halo", "workable", "stone_halo")

	# 5 dangerous but non-crashing disasters.
	_add_spell("zun_zun_zun", "Thunder Vomit", "disaster", "thunder_vomit")
	_add_spell("nox_mira_nox", "Bad Reflection", "disaster", "bad_reflection")
	_add_spell("bavo_iri_zun", "Meat Lightning", "disaster", "meat_lightning")
	_add_spell("asha_asha_nox", "Choked Flame", "disaster", "choked_flame")
	_add_spell("mira_bavo_keth", "Mirror Bloat", "disaster", "mirror_bloat")

	# 4 intentionally overpowered secret discoveries.
	_add_spell("mira_iri_mira", "Infinite Wink", "op", "infinite_wink")
	_add_spell("nox_asha_elum", "Black Sunrise", "op", "black_sunrise")
	_add_spell("keth_mira_zun", "Severed Thunder", "op", "severed_thunder")
	_add_spell("iri_bavo_asha", "Idiot Star", "op", "idiot_star")

	# 9 funny spells that still change combat.
	_add_spell("bavo_bavo_bavo", "Great Belly", "funny", "great_belly")
	_add_spell("iri_iri_iri", "Tiny Parade", "funny", "tiny_parade")
	_add_spell("mira_mira_bavo", "Self Portrait", "funny", "self_portrait")
	_add_spell("asha_bavo_iri", "Hot Potato", "funny", "hot_potato")
	_add_spell("voro_iri_bavo", "Wrong Door", "funny", "wrong_door")
	_add_spell("elum_iri_bavo", "Holy Pigeon", "funny", "holy_pigeon")
	_add_spell("nox_bavo_iri", "Silent Frog", "funny", "silent_frog")
	_add_spell("keth_bavo_mira", "Sword With Face", "funny", "sword_with_face")
	_add_spell("zun_bavo_elum", "Glowing Mistake", "funny", "glowing_mistake")


# This small helper keeps the spell list above readable for beginners.
func _add_spell(
	chant_key: String,
	result_name: String,
	result_type: String,
	effect_id: String
) -> void:
	spellbook[chant_key] = {
		"name": result_name,
		"type": result_type,
		"effect": effect_id
	}


# Known chants come through this path.
# The effect id selects one readable match branch below.
func _resolve_authored_chant(
	chant_key: String,
	spoken_words: PackedStringArray,
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> Dictionary:
	var spell: Dictionary = spellbook[chant_key]
	var result_name := String(spell["name"])
	var result_type := String(spell["type"])
	var effect_id := String(spell["effect"])

	log_lines.append("The chant locks: %s." % result_name)
	_apply_authored_effect(effect_id, target, context, log_lines)

	# Infinite Wink reads the previous spell and should not overwrite it with itself.
	if effect_id != "infinite_wink":
		previous_successful_spell_key = chant_key

	return _make_result(
		chant_key,
		spoken_words,
		result_name,
		result_type,
		true,
		log_lines
	)


# This match contains the concrete gameplay for all 30 authored chants.
# Small helper functions below keep repeated damage/shield code understandable.
func _apply_authored_effect(
	effect_id: String,
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	match effect_id:
		"razor_comet":
			_damage_enemy(target, 7, log_lines)
		"bright_cut":
			_damage_enemy(target, 5, log_lines, true)
		"hollow_push":
			_damage_enemy(target, 4, log_lines)
			if _is_valid_enemy(target):
				target.apply_status("delayed")
				log_lines.append("%s's intent is delayed." % target.enemy_name)
		"crackbolt":
			_damage_enemy(target, 6, log_lines)
			if _is_valid_enemy(target) and randf() < 0.30:
				target.apply_status("stunned")
				log_lines.append("%s is stunned." % target.enemy_name)
		"return_glow":
			_shield_all_mages(context, 3, log_lines)
		"reversed_blade":
			var reversed_damage := 4
			if _is_valid_enemy(target) and target.was_attacked_last_round:
				reversed_damage += 3
				log_lines.append("The blade remembers last round's wound.")
			_damage_enemy(target, reversed_damage, log_lines)
		"scatterflare":
			_damage_all_enemies(context, 3, log_lines)
		"heavy_word":
			log_lines.append("The chant feels impossibly heavy.")
			_damage_enemy(target, 8, log_lines)
		"quiet_ward":
			_apply_quiet_ward(target, context, log_lines)
		"spark_rain":
			for hit_index: int in range(3):
				var random_enemy := _random_living_enemy(context)
				if random_enemy != null:
					_damage_enemy(random_enemy, 2, log_lines)
		"double_sever":
			_damage_enemy(target, 4, log_lines)
			if _is_valid_enemy(target):
				_damage_enemy(target, 4, log_lines)
		"stone_halo":
			var halo_mage := _random_living_mage(context)
			if halo_mage != null:
				halo_mage.gain_shield(8)
				log_lines.append("%s gains 8 shield." % halo_mage.mage_name)
		"thunder_vomit":
			_damage_all_enemies(context, 4, log_lines)
			_damage_all_mages(context, 2, log_lines)
		"bad_reflection":
			var reflected_mage := _random_living_mage(context)
			if reflected_mage != null:
				reflected_mage.take_damage(3)
				log_lines.append(
					"Bad Reflection hits %s for 3 damage." % reflected_mage.mage_name
				)
		"meat_lightning":
			_damage_random_living_unit(context, 10, log_lines)
		"choked_flame":
			_resolve_choked_flame(target, context, log_lines)
		"mirror_bloat":
			if _is_valid_enemy(target):
				target.gain_shield(5)
				target.take_damage(3)
				log_lines.append(
					"%s gains 5 shield, then takes 3 damage." % target.enemy_name
				)
		"infinite_wink":
			_resolve_infinite_wink(target, context, log_lines)
		"black_sunrise":
			_damage_all_enemies(context, 8, log_lines)
			_damage_all_mages(context, 1, log_lines)
		"severed_thunder":
			_damage_enemy(target, 12, log_lines)
			if _is_valid_enemy(target):
				target.apply_status("stunned")
				log_lines.append("%s is stunned." % target.enemy_name)
		"idiot_star":
			_resolve_idiot_star(target, context, log_lines)
		"great_belly":
			if _is_valid_enemy(target):
				target.apply_status("confused")
				log_lines.append("%s is confused and will skip an action." % target.enemy_name)
		"tiny_parade":
			log_lines.append("A tiny parade marches with unbearable confidence.")
			_damage_all_enemies(context, 1, log_lines)
		"self_portrait":
			var portrait_mage := _random_living_mage(context)
			if portrait_mage != null:
				portrait_mage.gain_shield(4)
				log_lines.append("%s admires 4 new shield." % portrait_mage.mage_name)
			if _is_valid_enemy(target):
				target.modify_next_attack_damage(-1)
				log_lines.append("%s will deal 1 less damage next attack." % target.enemy_name)
		"hot_potato":
			_resolve_hot_potato(context, log_lines)
		"wrong_door":
			_resolve_wrong_door(target, context, log_lines)
		"holy_pigeon":
			for mage: MageUnit in _living_mages(context):
				mage.heal(1)
			log_lines.append("Holy Pigeon heals every living mage for 1.")
			if _is_valid_enemy(target):
				target.modify_next_attack_damage(-2)
				log_lines.append("%s will deal 2 less damage next attack." % target.enemy_name)
		"silent_frog":
			if _is_valid_enemy(target):
				target.apply_status("silenced")
				log_lines.append("%s is silenced until damaged or next action." % target.enemy_name)
		"sword_with_face":
			_damage_enemy(target, 3, log_lines)
			log_lines.append("The sword says something rude about the target's posture.")
		"glowing_mistake":
			_shield_all_mages(context, 2, log_lines)
			for enemy: EnemyUnit in _living_enemies(context):
				enemy.modify_next_attack_damage(-1)
			log_lines.append("All enemies will deal 1 less damage next attack.")


# Unknown chants always resolve through one of the five requested priorities.
func _resolve_fallback_miscast(
	chant_key: String,
	symbol_ids: PackedStringArray,
	spoken_words: PackedStringArray,
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> Dictionary:
	log_lines.append("The words fail to lock.")

	var result_name := ""
	var counts: Dictionary = {}
	for symbol_id: String in symbol_ids:
		counts[symbol_id] = int(counts.get(symbol_id, 0)) + 1

	if counts.size() == 1:
		result_name = "Echo Miscast"
		var random_enemy := _random_living_enemy(context)
		var random_mage := _random_living_mage(context)
		if random_enemy != null:
			_damage_enemy(random_enemy, 2, log_lines)
		if random_mage != null:
			random_mage.take_damage(1)
			log_lines.append("%s takes 1 backfire damage." % random_mage.mage_name)
	elif _has_repeated_symbol(counts):
		result_name = "Overchewed Word"
		_damage_enemy(target, 2, log_lines)
		if randf() < 0.25:
			var backfire_mage := _random_living_mage(context)
			if backfire_mage != null:
				backfire_mage.take_damage(1)
				log_lines.append("%s takes 1 backfire damage." % backfire_mage.mage_name)
	elif symbol_ids.has("zun"):
		result_name = "Unstable Spark"
		var spark_target := _random_living_enemy(context)
		if spark_target != null:
			_damage_enemy(spark_target, 3, log_lines)
	elif symbol_ids.has("elum"):
		result_name = "Weak Ward"
		_shield_all_mages(context, 1, log_lines)
	else:
		result_name = "Mumbled Spark"
		_damage_enemy(target, 1, log_lines)

	return _make_result(
		chant_key,
		spoken_words,
		result_name,
		"fallback",
		false,
		log_lines
	)


# Infinite Wink repeats the previous authored effect without consuming more cards.
func _resolve_infinite_wink(
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	if (
		previous_successful_spell_key.is_empty()
		or not spellbook.has(previous_successful_spell_key)
	):
		log_lines.append("There is no earlier spell to repeat.")
		_shield_all_mages(context, 3, log_lines)
		return

	var previous_spell: Dictionary = spellbook[previous_successful_spell_key]
	var previous_name := String(previous_spell["name"])
	var previous_effect := String(previous_spell["effect"])
	log_lines.append("Infinite Wink repeats %s for free." % previous_name)
	_apply_authored_effect(previous_effect, target, context, log_lines)


# Choked Flame helps the enemy and removes an extra random mage card.
func _resolve_choked_flame(
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	if _is_valid_enemy(target):
		target.heal(3)
		log_lines.append("%s is healed for 3." % target.enemy_name)

	var mage := _random_living_mage(context)
	if mage == null:
		return
	var discarded := mage.discard_random_card()
	if discarded != null:
		log_lines.append(
			"%s loses a random card: %s." % [mage.mage_name, discarded.spoken_word]
		)


# Idiot Star deliberately selects one powerful result at random.
func _resolve_idiot_star(
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	var outcome := randi_range(0, 2)
	match outcome:
		0:
			log_lines.append("Idiot Star chooses violence.")
			_damage_enemy(target, 14, log_lines)
		1:
			log_lines.append("Idiot Star becomes unexpectedly protective.")
			_shield_all_mages(context, 10, log_lines)
		2:
			log_lines.append("Idiot Star cannot tell friend from foe.")
			_damage_all_enemies(context, 5, log_lines)
			_damage_all_mages(context, 5, log_lines)


# Hot Potato hits two different random living units when possible.
func _resolve_hot_potato(context: Dictionary, log_lines: Array[String]) -> void:
	var units := _all_living_units(context)
	if units.is_empty():
		return

	var first_unit: Node = units.pick_random()
	_damage_any_unit(first_unit, 2, log_lines)
	units.erase(first_unit)

	if not units.is_empty():
		var second_unit: Node = units.pick_random()
		_damage_any_unit(second_unit, 2, log_lines)


# Wrong Door swaps already visible intents so the UI prediction changes meaningfully.
func _resolve_wrong_door(
	target: EnemyUnit,
	context: Dictionary,
	log_lines: Array[String]
) -> void:
	var enemies := _living_enemies(context)
	if enemies.size() < 2:
		_damage_enemy(target, 2, log_lines)
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


# Quiet Ward cancels the first non-attack intent already visible this round.
# If every enemy is only attacking, the ward remains a readable no-op for this
# simplified AI rather than inventing a hidden enemy spell system.
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
				"description": "%s's special intent is blocked by Quiet Ward." % enemy.enemy_name
			}
			log_lines.append("Quiet Ward blocks %s's intent." % enemy.enemy_name)
			return

	if _is_valid_enemy(target):
		target.apply_status("special_blocked")
	log_lines.append("Quiet Ward waits, but no special intent is active.")


# Repeated combat helpers below apply effects and add consistent log lines.
func _damage_enemy(
	target: EnemyUnit,
	amount: int,
	log_lines: Array[String],
	ignore_shield: bool = false
) -> void:
	if not _is_valid_enemy(target):
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


func _damage_random_living_unit(
	context: Dictionary,
	amount: int,
	log_lines: Array[String]
) -> void:
	var units := _all_living_units(context)
	if units.is_empty():
		return
	_damage_any_unit(units.pick_random(), amount, log_lines)


func _damage_any_unit(unit: Node, amount: int, log_lines: Array[String]) -> void:
	if unit is MageUnit:
		var mage := unit as MageUnit
		mage.take_damage(amount)
		log_lines.append("%s takes %d damage." % [mage.mage_name, amount])
	elif unit is EnemyUnit:
		_damage_enemy(unit as EnemyUnit, amount, log_lines)


# Context contains the arrays owned by CombatManager.
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


# All successful and fallback paths use the same output shape requested by the PDF.
func _make_result(
	chant_key: String,
	spoken_words: PackedStringArray,
	result_name: String,
	result_type: String,
	is_known: bool,
	log_lines: Array[String]
) -> Dictionary:
	return {
		"chant_key": chant_key,
		"spoken_words": spoken_words,
		"result_name": result_name,
		"result_type": result_type,
		"is_known": is_known,
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
		"log_lines": [message]
	}
