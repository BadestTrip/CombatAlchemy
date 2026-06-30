extends Node
class_name SpellbookRecorder

var discovered_signatures: Array[String] = []
var cast_history: Array[String] = []


func record_cast(result: SpellResultData) -> void:
	cast_history.append(result.display_name)
	if result.is_signature and not discovered_signatures.has(result.signature_id):
		discovered_signatures.append(result.signature_id)
