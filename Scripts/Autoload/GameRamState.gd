extends Node
class_name GameRamState

var max_ram: int = 100
var used_ram: int = 0


func reset_from_start_data(start_data: GameStartData) -> void:
	max_ram = maxi(
		1,
		start_data.max_ram
	)

	used_ram = 0


func can_allocate_ram(amount: int) -> bool:
	if amount < 0:
		return false

	return used_ram + amount <= max_ram


func try_allocate_ram(amount: int) -> bool:
	if not can_allocate_ram(amount):
		return false

	if amount == 0:
		return true

	used_ram += amount
	return true


func release_ram(amount: int) -> bool:
	if amount <= 0:
		return false

	used_ram = maxi(
		0,
		used_ram - amount
	)

	return true


func set_max_ram(new_maximum: int) -> void:
	max_ram = maxi(
		1,
		new_maximum
	)

	used_ram = mini(
		used_ram,
		max_ram
	)


func get_available_ram() -> int:
	return maxi(
		0,
		max_ram - used_ram
	)


func get_available_ram_ratio() -> float:
	if max_ram <= 0:
		return 0.0

	return float(get_available_ram()) / float(max_ram)
