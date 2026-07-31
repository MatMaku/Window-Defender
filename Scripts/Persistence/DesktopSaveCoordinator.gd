extends Node
class_name DesktopSaveCoordinator

const GAME_SCHEMA_VERSION: int = 1

signal save_finished(result: PersistenceResult)
signal restore_finished(result: PersistenceResult)

@export var content_registry: GameContentRegistry
@export var desktop: Desktop
@export var window_manager: WindowManager
@export var enemy_manager: EnemyManager
@export var firewall_navigation_manager: Node
@export var game_clock_manager: GameClockManager
@export var enemy_spawn_director: EnemySpawnDirector
@export var shooting_manager: ShootingManager
@export var reload_manager: ReloadManager
@export var repair_manager: RepairManager
@export var taskbar: Taskbar

var _system_state: GameSystemState
var _weapon_state: GameWeaponState
var _reload_stats_state: GameReloadStatsState
var _miner_state: GameMinerState
var _economy_state: GameEconomyState
var _ram_state: GameRamState
var _desktop_state: GameDesktopState
var _upgrade_state: GameUpgradeState
var _clock_state: GameClockState
var _run_state: GameRunState

var _initialization_finished: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_states()

	var tree: SceneTree = get_tree()
	var was_paused: bool = tree.paused
	tree.paused = true

	call_deferred(
		"_initialize_session",
		was_paused
	)


func create_save_snapshot() -> PersistenceResult:
	if not _initialization_finished:
		return PersistenceResult.failure(
			&"session_not_ready",
			"The Desktop session is not ready to save."
		)

	return _create_save_snapshot()


func _create_save_snapshot() -> PersistenceResult:
	var dependency_result: PersistenceResult = (
		_validate_dependencies()
	)
	if not dependency_result.success:
		return dependency_result

	var snapshot: Dictionary = {
		"schema_version": GAME_SCHEMA_VERSION,
		"states": {
			"system": _system_state.create_save_snapshot(),
			"weapon": _weapon_state.create_save_snapshot(),
			"reload_stats": (
				_reload_stats_state.create_save_snapshot()
			),
			"miner": _miner_state.create_save_snapshot(),
			"economy": _economy_state.create_save_snapshot(),
			"ram": _ram_state.create_save_snapshot(),
			"desktop": _desktop_state.create_save_snapshot(),
			"upgrades": _upgrade_state.create_save_snapshot(),
			"clock": _clock_state.create_save_snapshot(),
			"run": _run_state.create_save_snapshot()
		},
		"desktop": {
			"shortcuts": (
				desktop.create_shortcuts_save_snapshot()
			),
			"windows": (
				window_manager.create_windows_save_snapshot()
			)
		},
		"enemies": enemy_manager.create_enemies_save_snapshot(),
		"processes": {
			"shooting": shooting_manager.create_save_snapshot(),
			"reload": reload_manager.create_save_snapshot(),
			"repair": repair_manager.create_save_snapshot()
		}
	}

	var validation_result: PersistenceResult = (
		GameSaveValidator.validate(
			snapshot,
			content_registry
		)
	)
	if not validation_result.success:
		return validation_result

	return PersistenceResult.ok(snapshot)


func restore_save_snapshot(
	snapshot: Dictionary
) -> PersistenceResult:
	var validation_result: PersistenceResult = (
		GameSaveValidator.validate(
			snapshot,
			content_registry
		)
	)
	if not validation_result.success:
		return validation_result

	_stop_gameplay_processing()
	firewall_navigation_manager.call("begin_restore")
	_clear_runtime_for_restore()
	GameState.reset_run()

	var states: Dictionary = snapshot.get(
		"states",
		{}
	) as Dictionary
	_restore_specialized_states(states)

	var desktop_snapshot: Dictionary = snapshot.get(
		"desktop",
		{}
	) as Dictionary
	var shortcut_result: PersistenceResult = (
		desktop.restore_shortcuts(
			desktop_snapshot.get("shortcuts", []) as Array,
			content_registry
		)
	)
	if not shortcut_result.success:
		return _handle_restore_failure(shortcut_result)

	var window_result: PersistenceResult = (
		window_manager.restore_windows(
			desktop_snapshot.get("windows", []) as Array,
			content_registry
		)
	)
	if not window_result.success:
		return _handle_restore_failure(window_result)

	var enemies: Array = snapshot.get("enemies", []) as Array
	var enemy_result: PersistenceResult = (
		enemy_manager.restore_enemies(
			enemies,
			content_registry
		)
	)
	if not enemy_result.success:
		return _handle_restore_failure(enemy_result)

	var navigation_ready: bool = bool(
		await firewall_navigation_manager.call(
			"finish_restore"
		)
	)
	if not navigation_ready:
		return _handle_restore_failure(
			PersistenceResult.failure(
				&"firewall_navigation_restore_failed",
				"Could not rebuild Firewall navigation."
			)
		)

	var processes: Dictionary = snapshot.get(
		"processes",
		{}
	) as Dictionary
	shooting_manager.restore_from_save_snapshot(
		processes.get("shooting", {}) as Dictionary
	)
	reload_manager.restore_from_save_snapshot(
		processes.get("reload", {}) as Dictionary
	)
	repair_manager.restore_from_save_snapshot(
		processes.get("repair", {}) as Dictionary
	)

	if not _system_state.is_destroyed():
		game_clock_manager.start_clock()
		enemy_spawn_director.start_director(false)

	return PersistenceResult.ok()


func _initialize_session(was_paused: bool) -> void:
	var dependency_result: PersistenceResult = (
		_validate_dependencies()
	)
	if not dependency_result.success:
		_finish_initialization(
			dependency_result,
			was_paused
		)
		return

	if not taskbar.save_requested.is_connected(
		_on_save_requested
	):
		taskbar.save_requested.connect(_on_save_requested)

	if not save_finished.is_connected(
		taskbar.present_save_result
	):
		save_finished.connect(
			taskbar.present_save_result
		)

	if not taskbar.return_to_main_menu_requested.is_connected(
		_on_return_to_main_menu_requested
	):
		taskbar.return_to_main_menu_requested.connect(
			_on_return_to_main_menu_requested
		)

	var request_result: PersistenceResult = (
		ProfileService.consume_pending_session()
	)
	var request: Dictionary = (
		request_result.get_data_copy() as Dictionary
	)
	var mode: int = int(
		request.get(
			"mode",
			ProfileSessionService.SessionMode.NONE
		)
	)

	var initialization_result: PersistenceResult
	if mode == ProfileSessionService.SessionMode.LOAD_GAME:
		initialization_result = await restore_save_snapshot(
			request.get(
				"game_snapshot",
				{}
			) as Dictionary
		)
	else:
		initialization_result = _initialize_new_game()

	_finish_initialization(
		initialization_result,
		was_paused
	)


func _initialize_new_game() -> PersistenceResult:
	_stop_gameplay_processing()
	_clear_runtime_for_restore()
	firewall_navigation_manager.call("cancel_restore")
	GameState.reset_run()

	desktop.spawn_initial_shortcuts()
	_run_state.set_spawn_mode(
		enemy_spawn_director.initial_spawn_mode
	)

	var initial_snapshot_result: PersistenceResult = (
		_create_save_snapshot()
	)
	var initial_save_result: PersistenceResult = (
		_persist_snapshot_result(
			initial_snapshot_result
		)
	)
	if not initial_save_result.success:
		return initial_save_result

	game_clock_manager.start_clock()
	enemy_spawn_director.start_director(false)
	return PersistenceResult.ok()


func _on_save_requested() -> void:
	var tree: SceneTree = get_tree()
	var was_paused: bool = tree.paused
	tree.paused = true

	var snapshot_result: PersistenceResult = (
		create_save_snapshot()
	)
	var result: PersistenceResult = (
		_persist_snapshot_result(snapshot_result)
	)

	tree.paused = was_paused
	save_finished.emit(result)

	if not result.success:
		push_warning(
			"Save failed [%s]: %s" % [
				str(result.code),
				result.message
			]
		)


func _persist_snapshot_result(
	snapshot_result: PersistenceResult
) -> PersistenceResult:
	if not snapshot_result.success:
		return snapshot_result

	return ProfileService.save_active_game(
		snapshot_result.get_data_copy() as Dictionary
	)


func _on_return_to_main_menu_requested() -> void:
	var tree: SceneTree = get_tree()
	var was_paused: bool = tree.paused
	var clock_was_running: bool = (
		game_clock_manager.is_clock_running()
	)
	var director_was_running: bool = (
		enemy_spawn_director.is_running()
	)

	tree.paused = true
	_stop_gameplay_processing()

	var result: PersistenceResult = (
		ProfileService.return_to_main_menu()
	)
	if result.success:
		return

	if clock_was_running:
		game_clock_manager.start_clock()

	if director_was_running:
		enemy_spawn_director.start_director(false)

	tree.paused = was_paused
	taskbar.complete_return_to_main_menu(false)
	push_warning(
		"Return to main menu failed [%s]: %s" % [
			str(result.code),
			result.message
		]
	)


func _restore_specialized_states(states: Dictionary) -> void:
	_system_state.restore_from_save_snapshot(
		states.get("system", {}) as Dictionary
	)
	_weapon_state.restore_from_save_snapshot(
		states.get("weapon", {}) as Dictionary
	)
	_reload_stats_state.restore_from_save_snapshot(
		states.get("reload_stats", {}) as Dictionary
	)
	_miner_state.restore_from_save_snapshot(
		states.get("miner", {}) as Dictionary
	)
	_economy_state.restore_from_save_snapshot(
		states.get("economy", {}) as Dictionary
	)
	_ram_state.restore_from_save_snapshot(
		states.get("ram", {}) as Dictionary
	)
	_desktop_state.restore_from_save_snapshot(
		states.get("desktop", {}) as Dictionary
	)
	_upgrade_state.restore_from_save_snapshot(
		states.get("upgrades", {}) as Dictionary
	)
	_clock_state.restore_from_save_snapshot(
		states.get("clock", {}) as Dictionary
	)
	_run_state.restore_from_save_snapshot(
		states.get("run", {}) as Dictionary
	)


func _clear_runtime_for_restore() -> void:
	enemy_manager.clear_enemies_for_restore()
	window_manager.clear_windows_for_restore()
	desktop.clear_shortcuts_for_restore()


func _stop_gameplay_processing() -> void:
	game_clock_manager.stop_clock()
	enemy_spawn_director.stop_director()


func _handle_restore_failure(
	error_result: PersistenceResult
) -> PersistenceResult:
	_stop_gameplay_processing()
	_clear_runtime_for_restore()
	firewall_navigation_manager.call("cancel_restore")
	GameState.reset_run()
	desktop.spawn_initial_shortcuts()
	return error_result


func _finish_initialization(
	result: PersistenceResult,
	was_paused: bool
) -> void:
	_initialization_finished = result.success
	get_tree().paused = was_paused
	restore_finished.emit(result)
	ProfileService.complete_session_initialization(result)

	if not result.success:
		push_error(
			"Session initialization failed [%s]: %s" % [
				str(result.code),
				result.message
			]
		)


func _resolve_states() -> void:
	_system_state = GameState.system_state
	_weapon_state = GameState.weapon_state
	_reload_stats_state = GameState.reload_stats_state
	_miner_state = GameState.miner_state
	_economy_state = GameState.economy_state
	_ram_state = GameState.ram_state
	_desktop_state = GameState.desktop_state
	_upgrade_state = GameState.upgrade_state
	_clock_state = GameState.clock_state
	_run_state = GameState.run_state


func _validate_dependencies() -> PersistenceResult:
	if content_registry == null:
		return _missing_dependency("GameContentRegistry")

	if desktop == null:
		return _missing_dependency("Desktop")

	if window_manager == null:
		return _missing_dependency("WindowManager")

	if enemy_manager == null:
		return _missing_dependency("EnemyManager")

	if firewall_navigation_manager == null:
		return _missing_dependency(
			"FirewallNavigationManager"
		)

	if game_clock_manager == null:
		return _missing_dependency("GameClockManager")

	if enemy_spawn_director == null:
		return _missing_dependency("EnemySpawnDirector")

	if shooting_manager == null:
		return _missing_dependency("ShootingManager")

	if reload_manager == null:
		return _missing_dependency("ReloadManager")

	if repair_manager == null:
		return _missing_dependency("RepairManager")

	if taskbar == null:
		return _missing_dependency("Taskbar")

	if (
		_system_state == null
		or _weapon_state == null
		or _reload_stats_state == null
		or _miner_state == null
		or _economy_state == null
		or _ram_state == null
		or _desktop_state == null
		or _upgrade_state == null
		or _clock_state == null
		or _run_state == null
	):
		return _missing_dependency("specialized GameState states")

	return content_registry.validate_registry()


func _missing_dependency(
	dependency_name: String
) -> PersistenceResult:
	return PersistenceResult.failure(
		&"missing_dependency",
		"DesktopSaveCoordinator requires %s."
			% dependency_name
	)
