extends Node
class_name GameSystemState

var max_system_integrity: float = 100.0
var current_system_integrity: float = 100.0

var _system_destroyed: bool = false


func reset_from_start_data(start_data: GameStartData) -> void:
	max_system_integrity = maxf(
		1.0,
		start_data.max_system_integrity
	)

	current_system_integrity = max_system_integrity
	_system_destroyed = false


func take_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if _system_destroyed:
		return 0.0

	var previous_integrity: float = current_system_integrity

	current_system_integrity = maxf(
		current_system_integrity - amount,
		0.0
	)

	var applied_damage: float = (
		previous_integrity - current_system_integrity
	)

	if current_system_integrity <= 0.0:
		_system_destroyed = true

	return applied_damage


func heal(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if _system_destroyed:
		return 0.0

	var previous_integrity: float = current_system_integrity

	current_system_integrity = minf(
		current_system_integrity + amount,
		max_system_integrity
	)

	return current_system_integrity - previous_integrity


func set_max_integrity(
	new_maximum: float,
	fill_integrity: bool = false
) -> void:
	max_system_integrity = maxf(
		1.0,
		new_maximum
	)

	if fill_integrity:
		current_system_integrity = max_system_integrity
	else:
		current_system_integrity = minf(
			current_system_integrity,
			max_system_integrity
		)


func get_integrity_ratio() -> float:
	if max_system_integrity <= 0.0:
		return 0.0

	return current_system_integrity / max_system_integrity


func is_destroyed() -> bool:
	return _system_destroyed
