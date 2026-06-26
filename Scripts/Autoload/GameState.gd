extends Node
class_name RuntimeGameState

signal system_integrity_changed(
	current_integrity: float,
	max_integrity: float
)

signal system_destroyed

signal ammo_changed(
	current_ammo: int,
	max_ammo: int
)

signal weapon_stats_changed(
	damage: float,
	fire_cooldown_seconds: float
)

signal crypto_changed(current_crypto: int)

signal ram_changed(
	used_ram: int,
	max_ram: int
)


# -------------------------------------------------------------------
# SYSTEM
# -------------------------------------------------------------------

var max_system_integrity: float = 100.0
var current_system_integrity: float = 100.0

var _system_destroyed: bool = false


# -------------------------------------------------------------------
# WEAPON
# -------------------------------------------------------------------

var shot_damage: float = 1.0
var fire_cooldown_seconds: float = 1

var max_ammo: int = 6
var current_ammo: int = 6


# -------------------------------------------------------------------
# RELOAD
# -------------------------------------------------------------------

var normal_reload_duration: float = 1.45
var perfect_reload_finish_delay: float = 0.10
var reload_failure_penalty_duration: float = 0.85


# -------------------------------------------------------------------
# ECONOMY
# -------------------------------------------------------------------

var crypto: int = 0

var max_ram: int = 100
var used_ram: int = 0


func _ready() -> void:
	_emit_all_state()


# -------------------------------------------------------------------
# SYSTEM INTEGRITY
# -------------------------------------------------------------------

func take_system_damage(amount: float) -> float:
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

	if applied_damage <= 0.0:
		return 0.0

	system_integrity_changed.emit(
		current_system_integrity,
		max_system_integrity
	)

	if current_system_integrity <= 0.0:
		_system_destroyed = true
		system_destroyed.emit()

	return applied_damage


func heal_system(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if _system_destroyed:
		return 0.0

	var previous_integrity: float = current_system_integrity

	current_system_integrity = minf(
		current_system_integrity + amount,
		max_system_integrity
	)

	var healed_amount: float = (
		current_system_integrity - previous_integrity
	)

	if healed_amount > 0.0:
		system_integrity_changed.emit(
			current_system_integrity,
			max_system_integrity
		)

	return healed_amount


func set_max_system_integrity(
	new_maximum: float,
	fill_integrity: bool = false
) -> void:
	max_system_integrity = maxf(1.0, new_maximum)

	if fill_integrity:
		current_system_integrity = max_system_integrity
	else:
		current_system_integrity = minf(
			current_system_integrity,
			max_system_integrity
		)

	system_integrity_changed.emit(
		current_system_integrity,
		max_system_integrity
	)


func get_system_integrity_ratio() -> float:
	return current_system_integrity / max_system_integrity


func is_system_destroyed() -> bool:
	return _system_destroyed


# -------------------------------------------------------------------
# WEAPON
# -------------------------------------------------------------------

func consume_ammo(amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if current_ammo < amount:
		return false

	current_ammo -= amount

	ammo_changed.emit(
		current_ammo,
		max_ammo
	)

	return true


func refill_ammo() -> void:
	current_ammo = max_ammo

	ammo_changed.emit(
		current_ammo,
		max_ammo
	)


func set_max_ammo(
	new_maximum: int,
	refill: bool = false
) -> void:
	max_ammo = maxi(1, new_maximum)

	if refill:
		current_ammo = max_ammo
	else:
		current_ammo = mini(current_ammo, max_ammo)

	ammo_changed.emit(
		current_ammo,
		max_ammo
	)


func set_shot_damage(new_damage: float) -> void:
	shot_damage = maxf(0.01, new_damage)

	weapon_stats_changed.emit(
		shot_damage,
		fire_cooldown_seconds
	)


func set_fire_cooldown(new_cooldown_seconds: float) -> void:
	fire_cooldown_seconds = maxf(
		0.05,
		new_cooldown_seconds
	)

	weapon_stats_changed.emit(
		shot_damage,
		fire_cooldown_seconds
	)


# -------------------------------------------------------------------
# CRYPTO
# -------------------------------------------------------------------

func add_crypto(amount: int) -> void:
	if amount <= 0:
		return

	crypto += amount
	crypto_changed.emit(crypto)


func try_spend_crypto(amount: int) -> bool:
	if amount <= 0:
		return false

	if crypto < amount:
		return false

	crypto -= amount
	crypto_changed.emit(crypto)

	return true


# -------------------------------------------------------------------
# RAM
# -------------------------------------------------------------------

func try_allocate_ram(amount: int) -> bool:
	if amount <= 0:
		return false

	if used_ram + amount > max_ram:
		return false

	used_ram += amount

	ram_changed.emit(
		used_ram,
		max_ram
	)

	return true


func release_ram(amount: int) -> void:
	if amount <= 0:
		return

	used_ram = maxi(
		0,
		used_ram - amount
	)

	ram_changed.emit(
		used_ram,
		max_ram
	)


func set_max_ram(new_maximum: int) -> void:
	max_ram = maxi(1, new_maximum)

	used_ram = mini(
		used_ram,
		max_ram
	)

	ram_changed.emit(
		used_ram,
		max_ram
	)


func get_available_ram() -> int:
	return max_ram - used_ram


# -------------------------------------------------------------------
# RESET
# -------------------------------------------------------------------

func reset_run() -> void:
	max_system_integrity = 100.0
	current_system_integrity = max_system_integrity
	_system_destroyed = false

	shot_damage = 1.0
	fire_cooldown_seconds = 0.4

	max_ammo = 6
	current_ammo = max_ammo

	normal_reload_duration = 1.45
	perfect_reload_finish_delay = 0.10
	reload_failure_penalty_duration = 0.85

	crypto = 0

	max_ram = 100
	used_ram = 0

	_emit_all_state()


func _emit_all_state() -> void:
	system_integrity_changed.emit(
		current_system_integrity,
		max_system_integrity
	)

	ammo_changed.emit(
		current_ammo,
		max_ammo
	)

	weapon_stats_changed.emit(
		shot_damage,
		fire_cooldown_seconds
	)

	crypto_changed.emit(crypto)

	ram_changed.emit(
		used_ram,
		max_ram
	)
