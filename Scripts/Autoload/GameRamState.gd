extends Node
class_name GameRamState

signal ram_changed(
	used_ram: int,
	max_ram: int
)

var max_ram: int:
	get:
		return _max_ram

var used_ram: int:
	get:
		return _used_ram

var _max_ram: int = 100
var _used_ram: int = 0


func reset_from_start_data(start_data: GameStartData) -> void:
	_max_ram = maxi(
		1,
		start_data.max_ram
	)

	_used_ram = 0
	_emit_ram_changed()


func can_allocate_ram(amount: int) -> bool:
	if amount < 0:
		return false

	return _used_ram + amount <= _max_ram


func try_allocate_ram(amount: int) -> bool:
	if not can_allocate_ram(amount):
		return false

	if amount == 0:
		_emit_ram_changed()
		return true

	_used_ram += amount
	_emit_ram_changed()
	return true


func release_ram(amount: int) -> bool:
	if amount <= 0:
		return false

	_used_ram = maxi(
		0,
		_used_ram - amount
	)

	_emit_ram_changed()
	return true


func set_max_ram(new_maximum: int) -> void:
	_max_ram = maxi(
		1,
		new_maximum
	)

	_used_ram = mini(
		_used_ram,
		_max_ram
	)

	_emit_ram_changed()


func get_available_ram() -> int:
	return maxi(
		0,
		_max_ram - _used_ram
	)


func get_available_ram_ratio() -> float:
	if _max_ram <= 0:
		return 0.0

	return float(get_available_ram()) / float(_max_ram)


func _emit_ram_changed() -> void:
	ram_changed.emit(
		_used_ram,
		_max_ram
	)
