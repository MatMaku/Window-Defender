extends Node
class_name GameWeaponState

signal ammo_changed(
	current_ammo: int,
	max_ammo: int
)

signal weapon_stats_changed(
	damage: float,
	fire_cooldown_seconds: float
)

var shot_damage: float:
	get:
		return _shot_damage

var fire_cooldown_seconds: float:
	get:
		return _fire_cooldown_seconds

var max_ammo: int:
	get:
		return _max_ammo

var current_ammo: int:
	get:
		return _current_ammo

var _shot_damage: float = 1.0
var _fire_cooldown_seconds: float = 1.0
var _max_ammo: int = 6
var _current_ammo: int = 6


func reset_from_start_data(start_data: GameStartData) -> void:
	_shot_damage = maxf(
		0.01,
		start_data.shot_damage
	)

	_fire_cooldown_seconds = maxf(
		0.05,
		start_data.fire_cooldown_seconds
	)

	_max_ammo = maxi(
		1,
		start_data.max_ammo
	)

	_current_ammo = _max_ammo

	_emit_ammo_changed()
	_emit_weapon_stats_changed()


func consume_ammo(amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if _current_ammo < amount:
		return false

	_current_ammo -= amount
	_emit_ammo_changed()
	return true


func refill_ammo() -> void:
	_current_ammo = _max_ammo
	_emit_ammo_changed()


func set_max_ammo(
	new_maximum: int,
	refill: bool = false
) -> void:
	_max_ammo = maxi(
		1,
		new_maximum
	)

	if refill:
		_current_ammo = _max_ammo
	else:
		_current_ammo = mini(
			_current_ammo,
			_max_ammo
		)

	_emit_ammo_changed()


func set_shot_damage(new_damage: float) -> void:
	_shot_damage = maxf(
		0.01,
		new_damage
	)

	_emit_weapon_stats_changed()


func set_fire_cooldown(new_cooldown_seconds: float) -> void:
	_fire_cooldown_seconds = maxf(
		0.05,
		new_cooldown_seconds
	)

	_emit_weapon_stats_changed()


func _emit_ammo_changed() -> void:
	ammo_changed.emit(
		_current_ammo,
		_max_ammo
	)


func _emit_weapon_stats_changed() -> void:
	weapon_stats_changed.emit(
		_shot_damage,
		_fire_cooldown_seconds
	)
