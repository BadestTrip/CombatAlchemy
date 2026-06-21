extends Label
class_name ChantShoutController


signal shout_sequence_started
signal rune_shouted(spoken_word: String, index: int)
signal shout_sequence_finished


@export_group("Node References")
@export var shout_label: Label

@export_group("Timing")
@export var shout_each_rune_seconds: float = 0.45
@export var shout_between_runes_seconds: float = 0.15
@export var hide_after_final_seconds: float = 0.25

@export_group("Visuals")
@export var uppercase_words: bool = true
@export var add_exclamation_mark: bool = true


var is_playing: bool = false


func _ready() -> void:
	set_process(false)
	if shout_label == null:
		shout_label = self
	if shout_label != null:
		shout_label.visible = false


func play_shout_sequence(runes: Array[SymbolCardData]) -> void:
	if is_playing:
		return
	if shout_label == null:
		return

	is_playing = true
	shout_sequence_started.emit()
	for index: int in range(runes.size()):
		var rune := runes[index]
		if rune == null:
			continue
		var word := rune.spoken_word
		if uppercase_words:
			word = word.to_upper()
		if add_exclamation_mark:
			word += "!"

		shout_label.text = word
		shout_label.visible = true
		rune_shouted.emit(word, index)
		await get_tree().create_timer(maxf(0.0, shout_each_rune_seconds)).timeout
		shout_label.visible = false
		await get_tree().create_timer(maxf(0.0, shout_between_runes_seconds)).timeout

	await get_tree().create_timer(maxf(0.0, hide_after_final_seconds)).timeout
	if shout_label != null:
		shout_label.visible = false
	is_playing = false
	shout_sequence_finished.emit()
