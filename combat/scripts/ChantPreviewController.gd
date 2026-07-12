extends PanelContainer
class_name ChantPreviewController

@onready var title_label: Label = $VBox/Title
@onready var sequence_label: Label = $VBox/Sequence
@onready var description_label: Label = $VBox/Description
@onready var stability_label: Label = $VBox/Stability
@onready var effect_label: Label = $VBox/Effect


func update_preview(result: SpellResultData) -> void:
	title_label.text = result.display_name
	sequence_label.text = "Sequence: %s" % _sequence_to_text(result.rune_sequence)
	if result.is_signature:
		description_label.text = "Generated: %s\n%s" % [result.generated_name, result.description]
	else:
		description_label.text = result.description
	stability_label.text = "Stability: %s (%d)" % [result.instability_label, result.instability_score]
	effect_label.text = "Effect %s  Damage %d  Shield %d" % [result.effect_type, result.damage, result.shield]


func _sequence_to_text(sequence: Array[String]) -> String:
	if sequence.is_empty():
		return "(empty)"
	var parts := PackedStringArray()
	for rune_id in sequence:
		parts.append(rune_id)
	return " -> ".join(parts)
