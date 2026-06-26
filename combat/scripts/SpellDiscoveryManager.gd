# SpellDiscoveryManager.gd
# Attach this script to the SpellDiscoveryManager node in CombatScene.tscn.
# It mirrors session-only spell discoveries and cast history from GameManager.
# Nothing here is saved permanently yet.
extends Node
class_name SpellDiscoveryManager


# Emitted only the first time an authored recipe is discovered.
# CombatUIController listens and shows the discovery popup.
signal spell_discovered(recipe: SpellRecipeData, result: Dictionary)

# Emitted after a cast is appended or old entries are trimmed.
# CombatUIController listens and rebuilds the Cast History panel.
signal cast_history_updated(history: Array[Dictionary])

# Emitted whenever the visible discovered recipe set changes.
# CombatUIController listens and rebuilds the Spellbook panel.
signal spellbook_updated


# Keys map to true for quick first-discovery checks.
# This is runtime state and is intentionally not exported or saved.
var discovered_spell_keys: Dictionary = {}

# Each entry is a snapshot of one attempted chant.
# This is runtime state and is intentionally not exported or saved.
var cast_history: Array[Dictionary] = []

# The authored recipe list is supplied by CombatManager from ChantResolver.
var _spell_recipes: Array[SpellRecipeData] = []
var _recipes_by_key: Dictionary = {}
var balance: CombatBalanceData
var _fallback_balance: CombatBalanceData


# CombatManager calls this once before combat starts.
func configure(
	recipes: Array[SpellRecipeData],
	balance_ref: CombatBalanceData = null
) -> void:
	_spell_recipes = recipes
	if balance_ref != null:
		balance = balance_ref
	_rebuild_recipe_lookup()
	_load_session_memory()
	_reveal_initial_recipes()


# RoundManager calls this after every known spell or fallback miscast resolves.
# Discovery logic stays here so UI panels remain presentation-only.
func record_chant_result(
	result: Dictionary,
	recipe: SpellRecipeData = null,
	round_number: int = 0,
	target_name: String = ""
) -> void:
	var is_known := bool(result.get("is_known", false))
	var chant_key := String(result.get("chant_key", ""))

	if recipe == null and is_known:
		recipe = get_recipe_for_key(chant_key)

	var was_new_discovery := false
	if is_known and recipe != null and not discovered_spell_keys.has(chant_key):
		discovered_spell_keys[chant_key] = true
		GameManager.remember_learned_chant(chant_key)
		was_new_discovery = true
		spellbook_updated.emit()

	var should_track := is_known or _get_balance().track_fallback_casts
	if should_track:
		var spoken_words: Array[String] = []
		for word: Variant in result.get("spoken_words", []):
			spoken_words.append(String(word))

		var entry: Dictionary = {
			"chant_key": chant_key,
			"spoken_words": spoken_words,
			"result_name": String(result.get("result_name", "Unknown Result")),
			"result_type": String(result.get("result_type", "invalid")),
			"is_known": is_known,
			"was_new_discovery": was_new_discovery,
			"round": round_number,
			"target": target_name
		}
		cast_history.append(entry)
		GameManager.remember_cast_history_entry(entry)
		_trim_cast_history()
		GameManager.replace_session_cast_history(cast_history)

		cast_history_updated.emit(_get_cast_history_snapshot())

	if was_new_discovery and _get_balance().announce_new_discoveries:
		spell_discovered.emit(recipe, result)


# Spellbook UI uses this ordered list instead of reading the dictionary directly.
func get_discovered_recipes() -> Array[SpellRecipeData]:
	var discovered: Array[SpellRecipeData] = []
	for recipe: SpellRecipeData in _spell_recipes:
		if recipe != null and discovered_spell_keys.has(recipe.get_chant_key()):
			discovered.append(recipe)
	return discovered


# This helper lets discovery recover a recipe if only a chant key is available.
func get_recipe_for_key(chant_key: String) -> SpellRecipeData:
	return _recipes_by_key.get(chant_key) as SpellRecipeData


func get_all_active_recipes() -> Array[SpellRecipeData]:
	var active_recipes: Array[SpellRecipeData] = []
	for recipe: SpellRecipeData in _spell_recipes:
		if recipe != null:
			active_recipes.append(recipe)
	return active_recipes


# Build a safe lookup and warn about malformed or duplicate recipe data.
func _rebuild_recipe_lookup() -> void:
	_recipes_by_key.clear()
	for recipe: SpellRecipeData in _spell_recipes:
		if recipe == null:
			continue
		var chant_key := recipe.get_chant_key()
		if chant_key.is_empty():
			push_warning("Discovery manager skipped a recipe with an empty chant key.")
			continue
		if _recipes_by_key.has(chant_key):
			push_warning("Discovery manager found duplicate chant key: " + chant_key)
			continue
		_recipes_by_key[chant_key] = recipe


func _load_session_memory() -> void:
	discovered_spell_keys = GameManager.get_learned_chant_keys_snapshot()
	cast_history = GameManager.get_session_cast_history_snapshot()
	_trim_cast_history()
	GameManager.replace_session_cast_history(cast_history)
	cast_history_updated.emit(_get_cast_history_snapshot())


# Initially discovered recipes appear without triggering first-cast popups.
func _reveal_initial_recipes() -> void:
	if _get_balance().reveal_initially_discovered_spells:
		for recipe: SpellRecipeData in _spell_recipes:
			if recipe != null and recipe.initially_discovered:
				var chant_key := recipe.get_chant_key()
				discovered_spell_keys[chant_key] = true
				GameManager.remember_learned_chant(chant_key)
	spellbook_updated.emit()


# Keep only the newest configured number of attempts.
func _trim_cast_history() -> void:
	var limit := maxi(1, _get_balance().max_cast_history_entries)
	while cast_history.size() > limit:
		cast_history.pop_front()


func _get_cast_history_snapshot() -> Array[Dictionary]:
	# Preserve the signal's typed Array[Dictionary] contract while still
	# sending detached snapshots that presentation code cannot mutate.
	var history_snapshot: Array[Dictionary] = []
	for history_entry: Dictionary in cast_history:
		history_snapshot.append(history_entry.duplicate(true))
	return history_snapshot


func _get_balance() -> CombatBalanceData:
	if balance != null:
		return balance
	if _fallback_balance == null:
		_fallback_balance = CombatBalanceData.new()
		push_warning(
			"SpellDiscoveryManager has no CombatBalanceData assigned; using script defaults."
		)
	return _fallback_balance
