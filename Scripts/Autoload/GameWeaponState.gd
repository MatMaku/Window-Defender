extends Node
class_name GameWeaponState

var shot_damage: float = 1.0
var fire_cooldown_seconds: float = 1.0

var max_ammo: int = 6
var current_ammo: int = 6


func reset_from_start_data(start_data: GameStartData) -> void:
	shot_damage = maxf(
		0.01,
		start_data.shot_damage
	)

	fire_cooldown_seconds = maxf(
		0.05,
		start_data.fire_cooldown_seconds
	)

	max_ammo = maxi(
		1,
		start_data.max_ammo
	)

	current_ammo = max_ammo


func consume_ammo(amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if current_ammo < amount:
		return false

	current_ammo -= amount
	return true


func refill_ammo() -> void:
	current_ammo = max_ammo


func set_max_ammo(
	new_maximum: int,
	refill: bool = false
) -> void:
	max_ammo = maxi(
		1,
		new_maximum
	)

	if refill:
		current_ammo = max_ammo
	else:
		current_ammo = mini(
			current_ammo,
			max_ammo
		)


func set_current_ammo(new_current_ammo: int) -> void:
	current_ammo = clampi(
		new_current_ammo,
		0,
		max_ammo
	)


func set_shot_damage(new_damage: float) -> void:
	shot_damage = maxf(
		0.01,
		new_damage
	)


func set_fire_cooldown(new_cooldown_seconds: float) -> void:
	fire_cooldown_seconds = maxf(
		0.05,
		new_cooldown_seconds
	)
