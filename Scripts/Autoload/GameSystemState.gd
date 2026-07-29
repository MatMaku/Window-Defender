extends Node
class_name GameSystemState

signal system_integrity_changed(
	current_integrity: float,
	max_integrity: float
)

signal system_destroyed

var max_system_integrity: float:
	get:
		return _max_system_integrity

var current_system_integrity: float:
	get:
		return _current_system_integrity

var _max_system_integrity: float = 100.0
var _current_system_integrity: float = 100.0

var _system_destroyed: bool = false


func reset_from_start_data(start_data: GameStartData) -> void:
	_max_system_integrity = maxf(
		1.0,
		start_data.max_system_integrity
	)

	_current_system_integrity = _max_system_integrity
	_system_destroyed = false

	_emit_system_integrity_changed()


func take_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if _system_destroyed:
		return 0.0

	var previous_integrity: float = _current_system_integrity

	_current_system_integrity = maxf(
		_current_system_integrity - amount,
		0.0
	)

	var applied_damage: float = (
		previous_integrity - _current_system_integrity
	)

	if applied_damage <= 0.0:
		return 0.0

	var became_destroyed: bool = false
	if _current_system_integrity <= 0.0:
		_system_destroyed = true
		became_destroyed = true

	_emit_system_integrity_changed()

	if became_destroyed:
		system_destroyed.emit()

	return applied_damage


func heal(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if _system_destroyed:
		return 0.0

	var previous_integrity: float = _current_system_integrity

	_current_system_integrity = minf(
		_current_system_integrity + amount,
		_max_system_integrity
	)

	var healed_amount: float = (
		_current_system_integrity - previous_integrity
	)

	if healed_amount > 0.0:
		_emit_system_integrity_changed()

	return healed_amount


func set_max_integrity(
	new_maximum: float,
	fill_integrity: bool = false
) -> void:
	_max_system_integrity = maxf(
		1.0,
		new_maximum
	)

	if fill_integrity:
		_current_system_integrity = _max_system_integrity
	else:
		_current_system_integrity = minf(
			_current_system_integrity,
			_max_system_integrity
		)

	_emit_system_integrity_changed()


func get_integrity_ratio() -> float:
	if _max_system_integrity <= 0.0:
		return 0.0

	return _current_system_integrity / _max_system_integrity


func is_destroyed() -> bool:
	return _system_destroyed


func create_save_snapshot() -> Dictionary:
	return {
		"max_system_integrity": _max_system_integrity,
		"current_system_integrity": _current_system_integrity
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	_max_system_integrity = maxf(
		1.0,
		float(snapshot.get("max_system_integrity", 1.0))
	)
	_current_system_integrity = clampf(
		float(
			snapshot.get(
				"current_system_integrity",
				_max_system_integrity
			)
		),
		0.0,
		_max_system_integrity
	)
	_system_destroyed = _current_system_integrity <= 0.0

	_emit_system_integrity_changed()
	if _system_destroyed:
		system_destroyed.emit()


func _emit_system_integrity_changed() -> void:
	system_integrity_changed.emit(
		_current_system_integrity,
		_max_system_integrity
	)
