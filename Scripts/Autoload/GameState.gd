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


func _ready() -> void:
	_ensure_start_data()
	reset_run()


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


func _ensure_start_data() -> void:
	if start_data != null:
		return

	start_data = GameStartData.new()
