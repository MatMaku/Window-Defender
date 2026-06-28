extends Node
class_name RamManager

@export_category("RAM Threshold")

@export_range(0.01, 1.0, 0.01)
var optimal_available_ram_ratio: float = 0.40

@export_category("Opening Performance")

@export_range(1.0, 20.0, 0.1)
var maximum_open_duration_multiplier: float = 6.0

@export_category("Future Runtime Performance")

@export_range(0.05, 1.0, 0.01)
var minimum_runtime_speed_multiplier: float = 0.25


func can_reserve_ram(amount: int) -> bool:
	if amount < 0:
		return false

	return GameState.can_allocate_ram(amount)


func reserve_ram(amount: int) -> bool:
	if amount < 0:
		return false

	if amount == 0:
		return true

	return GameState.try_allocate_ram(amount)


func release_ram(amount: int) -> void:
	if amount <= 0:
		return

	GameState.release_ram(amount)


func get_open_duration_multiplier_for_cost(
	ram_cost: int
) -> float:
	if not can_reserve_ram(ram_cost):
		return 1.0

	var safe_ram_cost: int = maxi(0, ram_cost)

	var projected_used_ram: int = (
		GameState.used_ram + safe_ram_cost
	)

	var projected_available_ram: int = maxi(
		0,
		GameState.max_ram - projected_used_ram
	)

	var projected_available_ratio: float = (
		float(projected_available_ram)
		/ float(maxi(GameState.max_ram, 1))
	)

	return _get_open_duration_multiplier(
		projected_available_ratio
	)


func get_runtime_speed_multiplier() -> float:
	return _get_runtime_speed_multiplier(
		GameState.get_available_ram_ratio()
	)


func _get_open_duration_multiplier(
	available_ram_ratio: float
) -> float:
	var pressure_ratio: float = (
		_get_ram_pressure_ratio(available_ram_ratio)
	)

	return lerpf(
		1.0,
		maximum_open_duration_multiplier,
		pressure_ratio
	)


func _get_runtime_speed_multiplier(
	available_ram_ratio: float
) -> float:
	var pressure_ratio: float = (
		_get_ram_pressure_ratio(available_ram_ratio)
	)

	return lerpf(
		1.0,
		minimum_runtime_speed_multiplier,
		pressure_ratio
	)


func _get_ram_pressure_ratio(
	available_ram_ratio: float
) -> float:
	var safe_available_ratio: float = clampf(
		available_ram_ratio,
		0.0,
		1.0
	)

	if safe_available_ratio >= optimal_available_ram_ratio:
		return 0.0

	return 1.0 - (
		safe_available_ratio
		/ optimal_available_ram_ratio
	)
