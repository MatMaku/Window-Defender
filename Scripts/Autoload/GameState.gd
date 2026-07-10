extends Node
class_name RuntimeGameState

# VARIABLES: SYSTEM
var max_system_integrity: float = 100.0
var current_system_integrity: float = 100.0

# VARIABLES: WEAPON
var shot_damage: float = 1.0
var fire_cooldown_seconds: float = 1.0
var max_ammo: int = 6
var current_ammo: int = 6

# VARIABLES: RELOAD
var normal_reload_duration: float = 1.45
var perfect_reload_finish_delay: float = 0.35
var reload_failure_penalty_duration: float = 0.85

# VARIABLES: MINER
var miner_crypto_per_tick: int = 1
var miner_interval_seconds: float = 5.0

# VARIABLES: ECONOMY
var crypto: int = 1000
var virus_data: int = 1000
var total_enemy_kills: int = 0

# VARIABLES: RAM
var max_ram: int = 100
var used_ram: int = 0

# VARIABLES: DESKTOP RESOLUTION
var desktop_resolution_tiers: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

var desktop_resolution_tier: int = 0
var desktop_resolution: Vector2i = Vector2i(1280, 720)

# VARIABLES: UPGRADES
var purchased_upgrade_counts: Dictionary = {}
var auto_fire_unlocked: bool = false
var area_shot_unlocked: bool = false
var area_shot_max_targets: int = 0

# VARIABLES: DESKTOP SHORTCUTS
# Save-friendly structure:
# { "shooting": Vector2(40, 140), "ammo": Vector2(40, 240) }

var desktop_shortcuts: Dictionary = {}

# VARIABLES: RUN PROGRESS
var run_total_elapsed_time: float = 0.0
var enemy_spawn_stage_index: int = 0
var enemy_spawn_stage_elapsed_time: float = 0.0
var enemy_spawn_budget: float = 0.0

# VARIABLES: ENEMY SNAPSHOTS
var active_enemy_snapshots: Array = []

# VARIABLES: INTERNAL
var _system_destroyed: bool = false

# LIFECYCLE
func _ready() -> void:
	_sync_desktop_resolution_from_tier()
	_emit_all_state()

# SYSTEM
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
	if max_system_integrity <= 0.0:
		return 0.0

	return current_system_integrity / max_system_integrity


func is_system_destroyed() -> bool:
	return _system_destroyed

# WEAPON
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
		current_ammo = mini(
			current_ammo,
			max_ammo
		)

	ammo_changed.emit(
		current_ammo,
		max_ammo
	)


func set_shot_damage(new_damage: float) -> void:
	shot_damage = maxf(0.01, new_damage)
	_emit_weapon_stats_changed()


func set_fire_cooldown(new_cooldown_seconds: float) -> void:
	fire_cooldown_seconds = maxf(
		0.05,
		new_cooldown_seconds
	)

	_emit_weapon_stats_changed()


func _emit_weapon_stats_changed() -> void:
	weapon_stats_changed.emit(
		shot_damage,
		fire_cooldown_seconds
	)

# RELOAD
func set_normal_reload_duration(new_duration: float) -> void:
	normal_reload_duration = maxf(0.05, new_duration)
	_emit_reload_stats_changed()


func set_perfect_reload_finish_delay(new_delay: float) -> void:
	perfect_reload_finish_delay = maxf(0.0, new_delay)
	_emit_reload_stats_changed()


func set_reload_failure_penalty_duration(new_duration: float) -> void:
	reload_failure_penalty_duration = maxf(0.0, new_duration)
	_emit_reload_stats_changed()


func _emit_reload_stats_changed() -> void:
	reload_stats_changed.emit(
		normal_reload_duration,
		perfect_reload_finish_delay,
		reload_failure_penalty_duration
	)

# MINER
func set_miner_crypto_per_tick(new_amount: int) -> void:
	miner_crypto_per_tick = maxi(0, new_amount)
	_emit_miner_stats_changed()


func set_miner_interval_seconds(new_interval: float) -> void:
	miner_interval_seconds = maxf(0.05, new_interval)
	_emit_miner_stats_changed()


func _emit_miner_stats_changed() -> void:
	miner_stats_changed.emit(
		miner_crypto_per_tick,
		miner_interval_seconds
	)

# ECONOMY
func add_crypto(amount: int) -> void:
	if amount <= 0:
		return

	crypto += amount
	crypto_changed.emit(crypto)


func can_spend_crypto(amount: int) -> bool:
	if amount < 0:
		return false

	return crypto >= amount


func try_spend_crypto(amount: int) -> bool:
	if amount <= 0:
		return false

	if not can_spend_crypto(amount):
		return false

	crypto -= amount
	crypto_changed.emit(crypto)

	return true


func add_virus_data(amount: int) -> void:
	if amount <= 0:
		return

	virus_data += amount
	virus_data_changed.emit(virus_data)


func can_spend_virus_data(amount: int) -> bool:
	if amount < 0:
		return false

	return virus_data >= amount


func try_spend_virus_data(amount: int) -> bool:
	if amount <= 0:
		return false

	if not can_spend_virus_data(amount):
		return false

	virus_data -= amount
	virus_data_changed.emit(virus_data)

	return true


func register_enemy_kill(virus_data_reward: int = 1) -> void:
	total_enemy_kills += 1

	enemy_kills_changed.emit(
		total_enemy_kills
	)

	add_virus_data(virus_data_reward)


func can_afford_resources(
	crypto_cost: int,
	virus_data_cost: int
) -> bool:
	return (
		can_spend_crypto(crypto_cost)
		and can_spend_virus_data(virus_data_cost)
	)


func try_spend_resources(
	crypto_cost: int,
	virus_data_cost: int
) -> bool:
	if not can_afford_resources(
		crypto_cost,
		virus_data_cost
	):
		return false

	if crypto_cost > 0:
		crypto -= crypto_cost
		crypto_changed.emit(crypto)

	if virus_data_cost > 0:
		virus_data -= virus_data_cost
		virus_data_changed.emit(virus_data)

	return true

# RAM
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
	return maxi(
		0,
		max_ram - used_ram
	)


func get_available_ram_ratio() -> float:
	if max_ram <= 0:
		return 0.0

	return float(get_available_ram()) / float(max_ram)

# DESKTOP RESOLUTION
func set_desktop_resolution_tier(new_tier: int) -> void:
	if desktop_resolution_tiers.is_empty():
		return

	var safe_tier: int = clampi(
		new_tier,
		0,
		desktop_resolution_tiers.size() - 1
	)

	if desktop_resolution_tier == safe_tier:
		return

	desktop_resolution_tier = safe_tier
	_sync_desktop_resolution_from_tier()

	desktop_resolution_changed.emit(
		desktop_resolution,
		desktop_resolution_tier
	)


func set_desktop_resolution(
	new_resolution: Vector2i,
	new_tier: int = -1
) -> void:
	var safe_resolution: Vector2i = Vector2i(
		maxi(320, new_resolution.x),
		maxi(180, new_resolution.y)
	)

	if new_tier >= 0:
		desktop_resolution_tier = new_tier

	if desktop_resolution == safe_resolution:
		return

	desktop_resolution = safe_resolution

	desktop_resolution_changed.emit(
		desktop_resolution,
		desktop_resolution_tier
	)


func get_next_desktop_resolution_tier() -> int:
	if desktop_resolution_tiers.is_empty():
		return desktop_resolution_tier

	return mini(
		desktop_resolution_tier + 1,
		desktop_resolution_tiers.size() - 1
	)


func has_next_desktop_resolution_tier() -> bool:
	return (
		not desktop_resolution_tiers.is_empty()
		and desktop_resolution_tier
			< desktop_resolution_tiers.size() - 1
	)


func _sync_desktop_resolution_from_tier() -> void:
	if desktop_resolution_tiers.is_empty():
		return

	desktop_resolution_tier = clampi(
		desktop_resolution_tier,
		0,
		desktop_resolution_tiers.size() - 1
	)

	desktop_resolution = desktop_resolution_tiers[
		desktop_resolution_tier
	]

# UPGRADES
func get_upgrade_purchase_count(upgrade_id: StringName) -> int:
	if upgrade_id == StringName():
		return 0

	var key: String = str(upgrade_id)

	if not purchased_upgrade_counts.has(key):
		return 0

	return maxi(
		0,
		int(purchased_upgrade_counts[key])
	)


func set_upgrade_purchase_count(
	upgrade_id: StringName,
	purchase_count: int
) -> void:
	if upgrade_id == StringName():
		return

	purchased_upgrade_counts[str(upgrade_id)] = maxi(
		0,
		purchase_count
	)

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)


func increment_upgrade_purchase_count(
	upgrade_id: StringName,
	amount: int = 1
) -> int:
	if upgrade_id == StringName():
		return 0

	var new_count: int = (
		get_upgrade_purchase_count(upgrade_id)
		+ maxi(0, amount)
	)

	set_upgrade_purchase_count(
		upgrade_id,
		new_count
	)

	return new_count


func get_upgrade_purchase_counts_snapshot() -> Dictionary:
	return purchased_upgrade_counts.duplicate(true)


func set_upgrade_purchase_counts_from_snapshot(snapshot: Dictionary) -> void:
	purchased_upgrade_counts = snapshot.duplicate(true)

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)


func clear_upgrade_purchase_counts() -> void:
	purchased_upgrade_counts.clear()

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)


func set_auto_fire_unlocked(enabled: bool) -> void:
	if auto_fire_unlocked == enabled:
		return

	auto_fire_unlocked = enabled
	auto_fire_changed.emit(auto_fire_unlocked)


func set_area_shot_unlocked(enabled: bool) -> void:
	if area_shot_unlocked == enabled:
		return

	area_shot_unlocked = enabled

	area_shot_changed.emit(
		area_shot_unlocked,
		area_shot_max_targets
	)


func set_area_shot_max_targets(new_amount: int) -> void:
	area_shot_max_targets = maxi(0, new_amount)

	if area_shot_max_targets > 0:
		area_shot_unlocked = true

	area_shot_changed.emit(
		area_shot_unlocked,
		area_shot_max_targets
	)


func add_area_shot_max_targets(amount: int) -> void:
	if amount <= 0:
		return

	set_area_shot_max_targets(
		area_shot_max_targets + amount
	)

# DESKTOP SHORTCUTS
func register_desktop_shortcut(
	program_id: StringName,
	position: Vector2
) -> void:
	if program_id == StringName():
		return

	desktop_shortcuts[str(program_id)] = position

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func unregister_desktop_shortcut(program_id: StringName) -> void:
	if program_id == StringName():
		return

	var key: String = str(program_id)

	if not desktop_shortcuts.has(key):
		return

	desktop_shortcuts.erase(key)

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func update_desktop_shortcut_position(
	program_id: StringName,
	position: Vector2
) -> void:
	if program_id == StringName():
		return

	var key: String = str(program_id)

	if not desktop_shortcuts.has(key):
		return

	desktop_shortcuts[key] = position

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func has_desktop_shortcut(program_id: StringName) -> bool:
	if program_id == StringName():
		return false

	return desktop_shortcuts.has(str(program_id))


func get_desktop_shortcut_position(
	program_id: StringName,
	fallback_position: Vector2 = Vector2.ZERO
) -> Vector2:
	if program_id == StringName():
		return fallback_position

	var key: String = str(program_id)

	if not desktop_shortcuts.has(key):
		return fallback_position

	var stored_position: Variant = desktop_shortcuts[key]

	if stored_position is Vector2:
		return stored_position

	return fallback_position


func get_desktop_shortcuts_snapshot() -> Dictionary:
	return desktop_shortcuts.duplicate(true)


func set_desktop_shortcuts_from_snapshot(shortcuts_snapshot: Dictionary) -> void:
	desktop_shortcuts = shortcuts_snapshot.duplicate(true)

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func clear_desktop_shortcuts() -> void:
	desktop_shortcuts.clear()

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)

# RUN PROGRESS
func set_run_progress(
	total_elapsed_time: float,
	stage_index: int,
	stage_elapsed_time: float,
	spawn_budget: float
) -> void:
	run_total_elapsed_time = maxf(0.0, total_elapsed_time)
	enemy_spawn_stage_index = maxi(0, stage_index)
	enemy_spawn_stage_elapsed_time = maxf(0.0, stage_elapsed_time)
	enemy_spawn_budget = maxf(0.0, spawn_budget)

	run_progress_changed.emit(
		run_total_elapsed_time,
		enemy_spawn_stage_index,
		enemy_spawn_stage_elapsed_time,
		enemy_spawn_budget
	)


func get_run_progress_snapshot() -> Dictionary:
	return {
		"total_elapsed_time": run_total_elapsed_time,
		"stage_index": enemy_spawn_stage_index,
		"stage_elapsed_time": enemy_spawn_stage_elapsed_time,
		"spawn_budget": enemy_spawn_budget
	}


func set_run_progress_from_snapshot(snapshot: Dictionary) -> void:
	set_run_progress(
		float(snapshot.get("total_elapsed_time", 0.0)),
		int(snapshot.get("stage_index", 0)),
		float(snapshot.get("stage_elapsed_time", 0.0)),
		float(snapshot.get("spawn_budget", 0.0))
	)

# ENEMY SNAPSHOTS
func set_enemy_snapshots(enemy_snapshots: Array) -> void:
	active_enemy_snapshots = enemy_snapshots.duplicate(true)

	enemy_snapshots_changed.emit(
		get_enemy_snapshots()
	)


func get_enemy_snapshots() -> Array:
	return active_enemy_snapshots.duplicate(true)


func clear_enemy_snapshots() -> void:
	active_enemy_snapshots.clear()

	enemy_snapshots_changed.emit(
		get_enemy_snapshots()
	)

# RESET
func reset_run() -> void:
	_reset_system_state()
	_reset_weapon_state()
	_reset_reload_state()
	_reset_miner_state()
	_reset_economy_state()
	_reset_ram_state()
	_reset_desktop_resolution_state()
	_reset_upgrade_state()
	_reset_desktop_state()
	_reset_run_progress_state()
	_reset_enemy_snapshot_state()

	_emit_all_state()


func _reset_system_state() -> void:
	max_system_integrity = 100.0
	current_system_integrity = max_system_integrity
	_system_destroyed = false


func _reset_weapon_state() -> void:
	shot_damage = 1.0
	fire_cooldown_seconds = 1.0
	max_ammo = 6
	current_ammo = max_ammo


func _reset_reload_state() -> void:
	normal_reload_duration = 1.45
	perfect_reload_finish_delay = 0.10
	reload_failure_penalty_duration = 0.85


func _reset_miner_state() -> void:
	miner_crypto_per_tick = 1
	miner_interval_seconds = 5.0


func _reset_economy_state() -> void:
	crypto = 0
	virus_data = 0
	total_enemy_kills = 0


func _reset_ram_state() -> void:
	max_ram = 100
	used_ram = 0


func _reset_desktop_resolution_state() -> void:
	desktop_resolution_tier = 0
	_sync_desktop_resolution_from_tier()


func _reset_upgrade_state() -> void:
	purchased_upgrade_counts.clear()
	auto_fire_unlocked = false
	area_shot_unlocked = false
	area_shot_max_targets = 0


func _reset_desktop_state() -> void:
	desktop_shortcuts.clear()


func _reset_run_progress_state() -> void:
	run_total_elapsed_time = 0.0
	enemy_spawn_stage_index = 0
	enemy_spawn_stage_elapsed_time = 0.0
	enemy_spawn_budget = 0.0


func _reset_enemy_snapshot_state() -> void:
	active_enemy_snapshots.clear()


func _emit_all_state() -> void:
	system_integrity_changed.emit(
		current_system_integrity,
		max_system_integrity
	)

	ammo_changed.emit(
		current_ammo,
		max_ammo
	)

	_emit_weapon_stats_changed()
	_emit_reload_stats_changed()
	_emit_miner_stats_changed()

	crypto_changed.emit(crypto)
	virus_data_changed.emit(virus_data)

	enemy_kills_changed.emit(
		total_enemy_kills
	)

	ram_changed.emit(
		used_ram,
		max_ram
	)

	desktop_resolution_changed.emit(
		desktop_resolution,
		desktop_resolution_tier
	)

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)

	auto_fire_changed.emit(auto_fire_unlocked)

	area_shot_changed.emit(
		area_shot_unlocked,
		area_shot_max_targets
	)

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)

	run_progress_changed.emit(
		run_total_elapsed_time,
		enemy_spawn_stage_index,
		enemy_spawn_stage_elapsed_time,
		enemy_spawn_budget
	)

	enemy_snapshots_changed.emit(
		get_enemy_snapshots()
	)

# SIGNALS
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

signal reload_stats_changed(
	normal_reload_duration: float,
	perfect_reload_finish_delay: float,
	reload_failure_penalty_duration: float
)

signal miner_stats_changed(
	crypto_per_tick: int,
	mining_interval_seconds: float
)

signal crypto_changed(current_crypto: int)
signal virus_data_changed(current_virus_data: int)
signal enemy_kills_changed(total_enemy_kills: int)

signal ram_changed(
	used_ram: int,
	max_ram: int
)

signal desktop_resolution_changed(
	new_resolution: Vector2i,
	resolution_tier: int
)

signal upgrade_purchase_counts_changed(
	purchase_counts_snapshot: Dictionary
)

signal auto_fire_changed(enabled: bool)

signal area_shot_changed(
	unlocked: bool,
	max_targets: int
)

signal desktop_shortcuts_changed(shortcuts_snapshot: Dictionary)

signal run_progress_changed(
	total_elapsed_time: float,
	stage_index: int,
	stage_elapsed_time: float,
	spawn_budget: float
)

signal enemy_snapshots_changed(enemy_snapshots: Array)
