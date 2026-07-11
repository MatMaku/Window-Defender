extends Node
class_name RuntimeGameState

@export var start_data: GameStartData

@onready var system_state: GameSystemState = $SystemState
@onready var weapon_state: GameWeaponState = $WeaponState
@onready var reload_stats_state: GameReloadStatsState = $ReloadStatsState
@onready var miner_state: GameMinerState = $MinerState
@onready var economy_state: GameEconomyState = $EconomyState
@onready var ram_state: GameRamState = $RamState
@onready var desktop_state: GameDesktopState = $DesktopState
@onready var upgrade_state: GameUpgradeState = $UpgradeState
@onready var run_state: GameRunState = $RunState
@onready var enemy_snapshot_state: GameEnemySnapshotState = $EnemySnapshotState


# ================================================================
# PROXY VARIABLES: SYSTEM
# ================================================================

var max_system_integrity: float:
	get:
		return system_state.max_system_integrity
	set(value):
		set_max_system_integrity(value)


var current_system_integrity: float:
	get:
		return system_state.current_system_integrity
	set(value):
		system_state.current_system_integrity = clampf(
			value,
			0.0,
			system_state.max_system_integrity
		)

		system_integrity_changed.emit(
			system_state.current_system_integrity,
			system_state.max_system_integrity
		)


# ================================================================
# PROXY VARIABLES: WEAPON
# ================================================================

var shot_damage: float:
	get:
		return weapon_state.shot_damage
	set(value):
		set_shot_damage(value)


var fire_cooldown_seconds: float:
	get:
		return weapon_state.fire_cooldown_seconds
	set(value):
		set_fire_cooldown(value)


var max_ammo: int:
	get:
		return weapon_state.max_ammo
	set(value):
		set_max_ammo(value)


var current_ammo: int:
	get:
		return weapon_state.current_ammo
	set(value):
		weapon_state.set_current_ammo(value)

		ammo_changed.emit(
			weapon_state.current_ammo,
			weapon_state.max_ammo
		)


# ================================================================
# PROXY VARIABLES: RELOAD
# ================================================================

var normal_reload_duration: float:
	get:
		return reload_stats_state.normal_reload_duration
	set(value):
		set_normal_reload_duration(value)


var perfect_reload_finish_delay: float:
	get:
		return reload_stats_state.perfect_reload_finish_delay
	set(value):
		set_perfect_reload_finish_delay(value)


var reload_failure_penalty_duration: float:
	get:
		return reload_stats_state.reload_failure_penalty_duration
	set(value):
		set_reload_failure_penalty_duration(value)


# ================================================================
# PROXY VARIABLES: MINER
# ================================================================

var miner_crypto_per_tick: int:
	get:
		return miner_state.miner_crypto_per_tick
	set(value):
		set_miner_crypto_per_tick(value)


var miner_interval_seconds: float:
	get:
		return miner_state.miner_interval_seconds
	set(value):
		set_miner_interval_seconds(value)


# ================================================================
# PROXY VARIABLES: ECONOMY
# ================================================================

var crypto: int:
	get:
		return economy_state.crypto
	set(value):
		economy_state.crypto = maxi(
			0,
			value
		)

		crypto_changed.emit(
			economy_state.crypto
		)


var virus_data: int:
	get:
		return economy_state.virus_data
	set(value):
		economy_state.virus_data = maxi(
			0,
			value
		)

		virus_data_changed.emit(
			economy_state.virus_data
		)


var total_enemy_kills: int:
	get:
		return economy_state.total_enemy_kills
	set(value):
		economy_state.total_enemy_kills = maxi(
			0,
			value
		)

		enemy_kills_changed.emit(
			economy_state.total_enemy_kills
		)


# ================================================================
# PROXY VARIABLES: RAM
# ================================================================

var max_ram: int:
	get:
		return ram_state.max_ram
	set(value):
		set_max_ram(value)


var used_ram: int:
	get:
		return ram_state.used_ram
	set(value):
		ram_state.used_ram = clampi(
			value,
			0,
			ram_state.max_ram
		)

		ram_changed.emit(
			ram_state.used_ram,
			ram_state.max_ram
		)


# ================================================================
# PROXY VARIABLES: DESKTOP
# ================================================================

var desktop_resolution_tiers: Array[Vector2i]:
	get:
		return desktop_state.desktop_resolution_tiers
	set(value):
		desktop_state.set_resolution_tiers(value)

		desktop_resolution_changed.emit(
			desktop_state.desktop_resolution,
			desktop_state.desktop_resolution_tier
		)


var desktop_resolution_tier: int:
	get:
		return desktop_state.desktop_resolution_tier
	set(value):
		set_desktop_resolution_tier(value)


var desktop_resolution: Vector2i:
	get:
		return desktop_state.desktop_resolution
	set(value):
		set_desktop_resolution(value)


var desktop_shortcuts: Dictionary:
	get:
		return desktop_state.desktop_shortcuts
	set(value):
		set_desktop_shortcuts_from_snapshot(value)


# ================================================================
# PROXY VARIABLES: UPGRADES
# ================================================================

var purchased_upgrade_counts: Dictionary:
	get:
		return upgrade_state.purchased_upgrade_counts
	set(value):
		set_upgrade_purchase_counts_from_snapshot(value)


var auto_fire_unlocked: bool:
	get:
		return upgrade_state.auto_fire_unlocked
	set(value):
		set_auto_fire_unlocked(value)


var area_shot_unlocked: bool:
	get:
		return upgrade_state.area_shot_unlocked
	set(value):
		set_area_shot_unlocked(value)


var auto_reload_unlocked: bool:
	get:
		return upgrade_state.auto_reload_unlocked
	set(value):
		set_auto_reload_unlocked(value)


var area_shot_max_targets: int:
	get:
		return upgrade_state.area_shot_max_targets
	set(value):
		set_area_shot_max_targets(value)


# ================================================================
# PROXY VARIABLES: RUN
# ================================================================

var run_total_elapsed_time: float:
	get:
		return run_state.run_total_elapsed_time
	set(value):
		set_run_progress(
			value,
			run_state.enemy_spawn_stage_index,
			run_state.enemy_spawn_stage_elapsed_time,
			run_state.enemy_spawn_budget
		)


var enemy_spawn_stage_index: int:
	get:
		return run_state.enemy_spawn_stage_index
	set(value):
		set_run_progress(
			run_state.run_total_elapsed_time,
			value,
			run_state.enemy_spawn_stage_elapsed_time,
			run_state.enemy_spawn_budget
		)


var enemy_spawn_stage_elapsed_time: float:
	get:
		return run_state.enemy_spawn_stage_elapsed_time
	set(value):
		set_run_progress(
			run_state.run_total_elapsed_time,
			run_state.enemy_spawn_stage_index,
			value,
			run_state.enemy_spawn_budget
		)


var enemy_spawn_budget: float:
	get:
		return run_state.enemy_spawn_budget
	set(value):
		set_run_progress(
			run_state.run_total_elapsed_time,
			run_state.enemy_spawn_stage_index,
			run_state.enemy_spawn_stage_elapsed_time,
			value
		)


# ================================================================
# PROXY VARIABLES: ENEMY SNAPSHOTS
# ================================================================

var active_enemy_snapshots: Array:
	get:
		return enemy_snapshot_state.active_enemy_snapshots
	set(value):
		set_enemy_snapshots(value)


# ================================================================
# LIFECYCLE
# ================================================================

func _ready() -> void:
	_ensure_start_data()
	reset_run()


func _ensure_start_data() -> void:
	if start_data != null:
		return

	start_data = GameStartData.new()


# ================================================================
# SYSTEM
# ================================================================

func take_system_damage(amount: float) -> float:
	var was_destroyed: bool = system_state.is_destroyed()

	var applied_damage: float = system_state.take_damage(
		amount
	)

	if applied_damage <= 0.0:
		return 0.0

	system_integrity_changed.emit(
		system_state.current_system_integrity,
		system_state.max_system_integrity
	)

	if (
		not was_destroyed
		and system_state.is_destroyed()
	):
		system_destroyed.emit()

	return applied_damage


func heal_system(amount: float) -> float:
	var healed_amount: float = system_state.heal(
		amount
	)

	if healed_amount > 0.0:
		system_integrity_changed.emit(
			system_state.current_system_integrity,
			system_state.max_system_integrity
		)

	return healed_amount


func set_max_system_integrity(
	new_maximum: float,
	fill_integrity: bool = false
) -> void:
	system_state.set_max_integrity(
		new_maximum,
		fill_integrity
	)

	system_integrity_changed.emit(
		system_state.current_system_integrity,
		system_state.max_system_integrity
	)


func get_system_integrity_ratio() -> float:
	return system_state.get_integrity_ratio()


func is_system_destroyed() -> bool:
	return system_state.is_destroyed()


# ================================================================
# WEAPON
# ================================================================

func consume_ammo(amount: int = 1) -> bool:
	if not weapon_state.consume_ammo(amount):
		return false

	ammo_changed.emit(
		weapon_state.current_ammo,
		weapon_state.max_ammo
	)

	return true


func refill_ammo() -> void:
	weapon_state.refill_ammo()

	ammo_changed.emit(
		weapon_state.current_ammo,
		weapon_state.max_ammo
	)


func set_max_ammo(
	new_maximum: int,
	refill: bool = false
) -> void:
	weapon_state.set_max_ammo(
		new_maximum,
		refill
	)

	ammo_changed.emit(
		weapon_state.current_ammo,
		weapon_state.max_ammo
	)


func set_shot_damage(new_damage: float) -> void:
	weapon_state.set_shot_damage(
		new_damage
	)

	_emit_weapon_stats_changed()


func set_fire_cooldown(new_cooldown_seconds: float) -> void:
	weapon_state.set_fire_cooldown(
		new_cooldown_seconds
	)

	_emit_weapon_stats_changed()


func _emit_weapon_stats_changed() -> void:
	weapon_stats_changed.emit(
		weapon_state.shot_damage,
		weapon_state.fire_cooldown_seconds
	)


# ================================================================
# RELOAD
# ================================================================

func set_normal_reload_duration(new_duration: float) -> void:
	reload_stats_state.set_normal_reload_duration(
		new_duration
	)

	_emit_reload_stats_changed()


func set_perfect_reload_finish_delay(new_delay: float) -> void:
	reload_stats_state.set_perfect_reload_finish_delay(
		new_delay
	)

	_emit_reload_stats_changed()


func set_reload_failure_penalty_duration(new_duration: float) -> void:
	reload_stats_state.set_reload_failure_penalty_duration(
		new_duration
	)

	_emit_reload_stats_changed()


func _emit_reload_stats_changed() -> void:
	reload_stats_changed.emit(
		reload_stats_state.normal_reload_duration,
		reload_stats_state.perfect_reload_finish_delay,
		reload_stats_state.reload_failure_penalty_duration
	)


# ================================================================
# MINER
# ================================================================

func set_miner_crypto_per_tick(new_amount: int) -> void:
	miner_state.set_miner_crypto_per_tick(
		new_amount
	)

	_emit_miner_stats_changed()


func set_miner_interval_seconds(new_interval: float) -> void:
	miner_state.set_miner_interval_seconds(
		new_interval
	)

	_emit_miner_stats_changed()


func _emit_miner_stats_changed() -> void:
	miner_stats_changed.emit(
		miner_state.miner_crypto_per_tick,
		miner_state.miner_interval_seconds
	)


# ================================================================
# ECONOMY
# ================================================================

func add_crypto(amount: int) -> void:
	if not economy_state.add_crypto(amount):
		return

	crypto_changed.emit(
		economy_state.crypto
	)


func can_spend_crypto(amount: int) -> bool:
	return economy_state.can_spend_crypto(amount)


func try_spend_crypto(amount: int) -> bool:
	if not economy_state.try_spend_crypto(amount):
		return false

	crypto_changed.emit(
		economy_state.crypto
	)

	return true


func add_virus_data(amount: int) -> void:
	if not economy_state.add_virus_data(amount):
		return

	virus_data_changed.emit(
		economy_state.virus_data
	)


func can_spend_virus_data(amount: int) -> bool:
	return economy_state.can_spend_virus_data(amount)


func try_spend_virus_data(amount: int) -> bool:
	if not economy_state.try_spend_virus_data(amount):
		return false

	virus_data_changed.emit(
		economy_state.virus_data
	)

	return true


func register_enemy_kill(virus_data_reward: int = 1) -> void:
	var previous_virus_data: int = economy_state.virus_data

	economy_state.register_enemy_kill(
		virus_data_reward
	)

	enemy_kills_changed.emit(
		economy_state.total_enemy_kills
	)

	if economy_state.virus_data != previous_virus_data:
		virus_data_changed.emit(
			economy_state.virus_data
		)


func can_afford_resources(
	crypto_cost: int,
	virus_data_cost: int
) -> bool:
	return economy_state.can_afford_resources(
		crypto_cost,
		virus_data_cost
	)


func try_spend_resources(
	crypto_cost: int,
	virus_data_cost: int
) -> bool:
	if not economy_state.try_spend_resources(
		crypto_cost,
		virus_data_cost
	):
		return false

	if crypto_cost > 0:
		crypto_changed.emit(
			economy_state.crypto
		)

	if virus_data_cost > 0:
		virus_data_changed.emit(
			economy_state.virus_data
		)

	return true


# ================================================================
# RAM
# ================================================================

func can_allocate_ram(amount: int) -> bool:
	return ram_state.can_allocate_ram(amount)


func try_allocate_ram(amount: int) -> bool:
	if not ram_state.try_allocate_ram(amount):
		return false

	ram_changed.emit(
		ram_state.used_ram,
		ram_state.max_ram
	)

	return true


func release_ram(amount: int) -> void:
	if not ram_state.release_ram(amount):
		return

	ram_changed.emit(
		ram_state.used_ram,
		ram_state.max_ram
	)


func set_max_ram(new_maximum: int) -> void:
	ram_state.set_max_ram(
		new_maximum
	)

	ram_changed.emit(
		ram_state.used_ram,
		ram_state.max_ram
	)


func get_available_ram() -> int:
	return ram_state.get_available_ram()


func get_available_ram_ratio() -> float:
	return ram_state.get_available_ram_ratio()


# ================================================================
# DESKTOP RESOLUTION
# ================================================================

func set_desktop_resolution_tier(new_tier: int) -> void:
	if not desktop_state.set_desktop_resolution_tier(new_tier):
		return

	desktop_resolution_changed.emit(
		desktop_state.desktop_resolution,
		desktop_state.desktop_resolution_tier
	)


func set_desktop_resolution(
	new_resolution: Vector2i,
	new_tier: int = -1
) -> void:
	if not desktop_state.set_desktop_resolution(
		new_resolution,
		new_tier
	):
		return

	desktop_resolution_changed.emit(
		desktop_state.desktop_resolution,
		desktop_state.desktop_resolution_tier
	)


func get_next_desktop_resolution_tier() -> int:
	return desktop_state.get_next_desktop_resolution_tier()


func has_next_desktop_resolution_tier() -> bool:
	return desktop_state.has_next_desktop_resolution_tier()


# ================================================================
# UPGRADES
# ================================================================

func set_auto_reload_unlocked(enabled: bool) -> void:
	if not upgrade_state.set_auto_reload_unlocked(enabled):
		return

	auto_reload_changed.emit(
		upgrade_state.auto_reload_unlocked
	)


func get_upgrade_purchase_count(upgrade_id: StringName) -> int:
	return upgrade_state.get_upgrade_purchase_count(
		upgrade_id
	)


func set_upgrade_purchase_count(
	upgrade_id: StringName,
	purchase_count: int
) -> void:
	upgrade_state.set_upgrade_purchase_count(
		upgrade_id,
		purchase_count
	)

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)


func increment_upgrade_purchase_count(
	upgrade_id: StringName,
	amount: int = 1
) -> int:
	var new_count: int = (
		upgrade_state.increment_upgrade_purchase_count(
			upgrade_id,
			amount
		)
	)

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)

	return new_count


func get_upgrade_purchase_counts_snapshot() -> Dictionary:
	return upgrade_state.get_upgrade_purchase_counts_snapshot()


func set_upgrade_purchase_counts_from_snapshot(snapshot: Dictionary) -> void:
	upgrade_state.set_upgrade_purchase_counts_from_snapshot(
		snapshot
	)

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)


func clear_upgrade_purchase_counts() -> void:
	upgrade_state.clear_upgrade_purchase_counts()

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)


func set_auto_fire_unlocked(enabled: bool) -> void:
	if not upgrade_state.set_auto_fire_unlocked(enabled):
		return

	auto_fire_changed.emit(
		upgrade_state.auto_fire_unlocked
	)


func set_area_shot_unlocked(enabled: bool) -> void:
	if not upgrade_state.set_area_shot_unlocked(enabled):
		return

	area_shot_changed.emit(
		upgrade_state.area_shot_unlocked,
		upgrade_state.area_shot_max_targets
	)


func set_area_shot_max_targets(new_amount: int) -> void:
	if not upgrade_state.set_area_shot_max_targets(new_amount):
		return

	area_shot_changed.emit(
		upgrade_state.area_shot_unlocked,
		upgrade_state.area_shot_max_targets
	)


func add_area_shot_max_targets(amount: int) -> void:
	if not upgrade_state.add_area_shot_max_targets(amount):
		return

	area_shot_changed.emit(
		upgrade_state.area_shot_unlocked,
		upgrade_state.area_shot_max_targets
	)


# ================================================================
# DESKTOP SHORTCUTS
# ================================================================

func register_desktop_shortcut(
	program_id: StringName,
	position: Vector2
) -> void:
	desktop_state.register_desktop_shortcut(
		program_id,
		position
	)

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func unregister_desktop_shortcut(program_id: StringName) -> void:
	if not desktop_state.unregister_desktop_shortcut(program_id):
		return

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func update_desktop_shortcut_position(
	program_id: StringName,
	position: Vector2
) -> void:
	if not desktop_state.update_desktop_shortcut_position(
		program_id,
		position
	):
		return

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func has_desktop_shortcut(program_id: StringName) -> bool:
	return desktop_state.has_desktop_shortcut(program_id)


func get_desktop_shortcut_position(
	program_id: StringName,
	fallback_position: Vector2 = Vector2.ZERO
) -> Vector2:
	return desktop_state.get_desktop_shortcut_position(
		program_id,
		fallback_position
	)


func get_desktop_shortcuts_snapshot() -> Dictionary:
	return desktop_state.get_desktop_shortcuts_snapshot()


func set_desktop_shortcuts_from_snapshot(
	shortcuts_snapshot: Dictionary
) -> void:
	desktop_state.set_desktop_shortcuts_from_snapshot(
		shortcuts_snapshot
	)

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


func clear_desktop_shortcuts() -> void:
	desktop_state.clear_desktop_shortcuts()

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)


# ================================================================
# RUN PROGRESS
# ================================================================

func set_run_progress(
	total_elapsed_time: float,
	stage_index: int,
	stage_elapsed_time: float,
	spawn_budget: float
) -> void:
	run_state.set_run_progress(
		total_elapsed_time,
		stage_index,
		stage_elapsed_time,
		spawn_budget
	)

	run_progress_changed.emit(
		run_state.run_total_elapsed_time,
		run_state.enemy_spawn_stage_index,
		run_state.enemy_spawn_stage_elapsed_time,
		run_state.enemy_spawn_budget
	)


func get_run_progress_snapshot() -> Dictionary:
	return run_state.get_run_progress_snapshot()


func set_run_progress_from_snapshot(snapshot: Dictionary) -> void:
	run_state.set_run_progress_from_snapshot(snapshot)

	run_progress_changed.emit(
		run_state.run_total_elapsed_time,
		run_state.enemy_spawn_stage_index,
		run_state.enemy_spawn_stage_elapsed_time,
		run_state.enemy_spawn_budget
	)


# ================================================================
# ENEMY SNAPSHOTS
# ================================================================

func set_enemy_snapshots(enemy_snapshots: Array) -> void:
	enemy_snapshot_state.set_enemy_snapshots(
		enemy_snapshots
	)

	enemy_snapshots_changed.emit(
		get_enemy_snapshots()
	)


func get_enemy_snapshots() -> Array:
	return enemy_snapshot_state.get_enemy_snapshots()


func clear_enemy_snapshots() -> void:
	enemy_snapshot_state.clear_enemy_snapshots()

	enemy_snapshots_changed.emit(
		get_enemy_snapshots()
	)


# ================================================================
# RESET
# ================================================================

func reset_run() -> void:
	_ensure_start_data()

	system_state.reset_from_start_data(start_data)
	weapon_state.reset_from_start_data(start_data)
	reload_stats_state.reset_from_start_data(start_data)
	miner_state.reset_from_start_data(start_data)
	economy_state.reset_from_start_data(start_data)
	ram_state.reset_from_start_data(start_data)

	desktop_state.reset_resolution_from_start_data(start_data)
	desktop_state.clear_desktop_shortcuts()

	upgrade_state.reset()
	run_state.reset()
	enemy_snapshot_state.reset()

	_emit_all_state()


func _emit_all_state() -> void:
	system_integrity_changed.emit(
		system_state.current_system_integrity,
		system_state.max_system_integrity
	)

	ammo_changed.emit(
		weapon_state.current_ammo,
		weapon_state.max_ammo
	)

	_emit_weapon_stats_changed()
	_emit_reload_stats_changed()
	_emit_miner_stats_changed()

	crypto_changed.emit(
		economy_state.crypto
	)

	virus_data_changed.emit(
		economy_state.virus_data
	)

	enemy_kills_changed.emit(
		economy_state.total_enemy_kills
	)

	ram_changed.emit(
		ram_state.used_ram,
		ram_state.max_ram
	)

	desktop_resolution_changed.emit(
		desktop_state.desktop_resolution,
		desktop_state.desktop_resolution_tier
	)

	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)

	auto_reload_changed.emit(
		upgrade_state.auto_reload_unlocked
	)

	auto_fire_changed.emit(
		upgrade_state.auto_fire_unlocked
	)

	area_shot_changed.emit(
		upgrade_state.area_shot_unlocked,
		upgrade_state.area_shot_max_targets
	)

	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)

	run_progress_changed.emit(
		run_state.run_total_elapsed_time,
		run_state.enemy_spawn_stage_index,
		run_state.enemy_spawn_stage_elapsed_time,
		run_state.enemy_spawn_budget
	)

	enemy_snapshots_changed.emit(
		get_enemy_snapshots()
	)


# ================================================================
# SIGNALS
# ================================================================

signal auto_reload_changed(enabled: bool)

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
