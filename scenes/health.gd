extends Node
class_name HealthComponent

signal changed(new_max: float, old_max: float)                   # max health changed only
signal died
signal damaged(amount: float, current: float, max: float)
signal healed(amount: float, current: float, max: float)

var _max: float = 0.0
var _current: float = 0.0
var _dead_emitted: bool = false
var _initialized: bool = false


# Call once from the owning actor (or StatsComponent) after you know max HP.
func configure(max_hp: float, start_current: float = -1.0) -> void:
	_max = max(0.0, max_hp)
	_initialized = true

	if start_current < 0.0:
		_current = _max
	else:
		_current = clamp(start_current, 0.0, _max)

	_dead_emitted = false
	if _current <= 0.0:
		_emit_died_once()


func set_max_health(new_max: float, keep_ratio: bool = true) -> void:
	_require_init()

	new_max = max(0.0, new_max)
	if is_equal_approx(new_max, _max):
		return

	var old_max := _max
	var ratio := 0.0
	if old_max > 0.0:
		ratio = _current / old_max

	_max = new_max

	if keep_ratio:
		_current = clamp(_max * ratio, 0.0, _max)
	else:
		_current = clamp(_current, 0.0, _max)

	changed.emit(_max, old_max)

	if _current <= 0.0:
		_emit_died_once()


func damage(amount: float) -> void:
	_require_init()

	if amount <= 0.0 or is_dead():
		return

	var old := _current
	_current = clamp(_current - amount, 0.0, _max)
	if _current == old:
		return

	damaged.emit(amount, _current, _max)

	if _current <= 0.0:
		_emit_died_once()


func heal(amount: float) -> void:
	_require_init()

	if amount <= 0.0 or is_dead():
		return

	var old := _current
	_current = clamp(_current + amount, 0.0, _max)
	if _current == old:
		return

	healed.emit(amount, _current, _max)


func current() -> float:
	return _current

func max_health() -> float:
	return _max

func is_dead() -> bool:
	return _current <= 0.0


func _emit_died_once() -> void:
	if _dead_emitted:
		return
	_dead_emitted = true
	died.emit()

func _require_init() -> void:
	if _initialized:
		return
	push_error("HealthComponent used before configure(). Call health.configure(max_hp, start_hp) first.")
