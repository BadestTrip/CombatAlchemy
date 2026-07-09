extends Node
class_name InstabilityCalculator


func calculate(sequence: Array, rune_catalog: Dictionary) -> Dictionary:
	var score := maxi(0, sequence.size() - 1)
	var zun_count := 0

	for rune_id_value in sequence:
		var rune_id := str(rune_id_value)
		var rune := rune_catalog.get(rune_id) as RuneData
		if rune != null:
			score += rune.instability_modifier
		if rune_id == "ZUN":
			zun_count += 1

	if zun_count > 1:
		score += (zun_count - 1) * 2

	score = maxi(0, score)
	return {
		"score": score,
		"label": _get_label(score),
	}


func _get_label(score: int) -> String:
	if score >= 9:
		return "Forbidden"
	if score >= 6:
		return "Unstable"
	if score >= 3:
		return "Strained"
	return "Stable"


func get_label_for_score(score: int) -> String:
	return _get_label(score)
