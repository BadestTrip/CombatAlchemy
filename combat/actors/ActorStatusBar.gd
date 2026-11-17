class_name ActorStatusBar
extends Node2D

# Responsibility: Present up to four active actor statuses in fixed scene-authored slots.

@onready var _slots: Array[Node] = [
	$StatusSlot1,
	$StatusSlot2,
	$StatusSlot3,
	$StatusSlot4,
]


## Replaces the visible snapshots while retaining the authored four-slot layout.
func set_statuses(statuses: Array[Dictionary]) -> void:
	for slot_index in _slots.size():
		var slot := _slots[slot_index]
		if slot_index < statuses.size():
			slot.call(&"set_status", statuses[slot_index])
		else:
			slot.call(&"clear_status")
