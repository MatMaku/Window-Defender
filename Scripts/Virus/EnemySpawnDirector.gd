extends Node
class_name EnemySpawnDirector

signal director_started
signal director_stopped

signal stage_changed(
	stage_index: int,
	stage: EnemySpawnStageData
)

signal spawn_budget_changed(
	current_budget: float,
	max_budget: float
)

@export var enemy_manager: EnemyManager
@export var system_manager: SystemManager

@export var stages: Array[EnemySpawnStageData] = []

@export var autostart: bool = true
@export var pause_when_system_destroyed: bool = true
@export var reset_budget_on_stage_change: bool = false

@export_category("GameState Sync")

@export var sync_run_progress_to_game_state: bool = true

@export_range(0.05, 5.0, 0.05)
var run_progress_sync_interval: float = 0.25

@export_category("Debug")

@export var debug_print_stage_changes: bool = false
@export var debug_print_spawns: bool = false

var _random: RandomNumberGenerator = RandomNumberGenerator.new()

var _is_running: bool = false

var _total_elapsed_time: float = 0.0
var _stage_elapsed_time: float = 0.0
var _spawn_check_elapsed_time: float = 0.0
var _spawn_budget: float = 0.0

var _stage_index: int = 0
var _run_progress_sync_elapsed_time: float = 0.0


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_random.randomize()
	_connect_signals()

	if autostart:
		call_deferred("start_director")


func _process(delta: float) -> void:
	if not _can_process_director():
		return

	_update_elapsed_time(delta)
	_advance_stage_if_needed()

	var current_stage: EnemySpawnStageData = _get_current_stage()

	if current_stage == null:
		return

	_update_spawn_budget(
		current_stage,
		delta
	)

	_update_spawn_check(
		current_stage,
		delta
	)

	_update_game_state_sync(delta)


func start_director(reset_state: bool = true) -> void:
	if reset_state:
		reset_director_state()

	if _is_running:
		return

	_is_running = true

	director_started.emit()
	_emit_current_stage()
	write_run_progress_to_game_state()


func stop_director() -> void:
	if not _is_running:
		return

	_is_running = false

	write_run_progress_to_game_state()

	director_stopped.emit()


func reset_director_state() -> void:
	_total_elapsed_time = 0.0
	_stage_elapsed_time = 0.0
	_spawn_check_elapsed_time = 0.0
	_spawn_budget = 0.0
	_stage_index = 0
	_run_progress_sync_elapsed_time = 0.0

	_emit_spawn_budget_changed()
	write_run_progress_to_game_state()


func apply_run_progress_from_game_state() -> void:
	if stages.is_empty():
		return

	_total_elapsed_time = maxf(
		0.0,
		GameState.run_total_elapsed_time
	)

	_stage_index = clampi(
		GameState.enemy_spawn_stage_index,
		0,
		stages.size() - 1
	)

	_stage_elapsed_time = maxf(
		0.0,
		GameState.enemy_spawn_stage_elapsed_time
	)

	_spawn_budget = maxf(
		0.0,
		GameState.enemy_spawn_budget
	)

	_spawn_check_elapsed_time = 0.0
	_run_progress_sync_elapsed_time = 0.0

	_clamp_budget_to_current_stage()
	_emit_current_stage()
	_emit_spawn_budget_changed()

	write_run_progress_to_game_state()


func write_run_progress_to_game_state() -> void:
	if not sync_run_progress_to_game_state:
		return

	GameState.set_run_progress(
		_total_elapsed_time,
		_stage_index,
		_stage_elapsed_time,
		_spawn_budget
	)


func get_total_elapsed_time() -> float:
	return _total_elapsed_time


func get_current_stage_index() -> int:
	return _stage_index


func get_current_spawn_budget() -> float:
	return _spawn_budget


func is_running() -> bool:
	return _is_running


func _resolve_references() -> void:
	if enemy_manager == null:
		enemy_manager = (
			get_node_or_null("../EnemyManager")
			as EnemyManager
		)

	if system_manager == null:
		system_manager = (
			get_node_or_null("../SystemManager")
			as SystemManager
		)


func _validate_dependencies() -> bool:
	if enemy_manager == null:
		push_error(
			"EnemySpawnDirector requires an EnemyManager reference."
		)
		return false

	if stages.is_empty():
		push_error(
			"EnemySpawnDirector requires at least one spawn stage."
		)
		return false

	return true


func _connect_signals() -> void:
	if not pause_when_system_destroyed:
		return

	if system_manager == null:
		return

	if system_manager.system_destroyed.is_connected(
		_on_system_destroyed
	):
		return

	system_manager.system_destroyed.connect(
		_on_system_destroyed
	)


func _can_process_director() -> bool:
	return (
		_is_running
		and not stages.is_empty()
	)


func _update_elapsed_time(delta: float) -> void:
	_total_elapsed_time += delta
	_stage_elapsed_time += delta


func _get_current_stage() -> EnemySpawnStageData:
	if stages.is_empty():
		return null

	_stage_index = clampi(
		_stage_index,
		0,
		stages.size() - 1
	)

	return stages[_stage_index]


func _advance_stage_if_needed() -> void:
	while true:
		var current_stage: EnemySpawnStageData = (
			_get_current_stage()
		)

		if current_stage == null:
			return

		if current_stage.is_infinite():
			return

		if _stage_elapsed_time < current_stage.duration_seconds:
			return

		if _stage_index >= stages.size() - 1:
			_stage_elapsed_time = current_stage.duration_seconds
			return

		_stage_elapsed_time -= current_stage.duration_seconds
		_stage_index += 1
		_spawn_check_elapsed_time = 0.0

		_on_stage_changed()


func _on_stage_changed() -> void:
	_clamp_budget_to_current_stage()

	if reset_budget_on_stage_change:
		_spawn_budget = 0.0

	var current_stage: EnemySpawnStageData = (
		_get_current_stage()
	)

	if current_stage == null:
		return

	if debug_print_stage_changes:
		print(
			"EnemySpawnDirector stage changed to: ",
			current_stage.stage_name
		)

	stage_changed.emit(
		_stage_index,
		current_stage
	)

	_emit_spawn_budget_changed()
	write_run_progress_to_game_state()


func _update_spawn_budget(
	stage: EnemySpawnStageData,
	delta: float
) -> void:
	var max_budget: float = (
		stage.get_safe_max_stored_budget()
	)

	var threat_gain: float = (
		maxf(0.0, stage.threat_per_second)
		* delta
	)

	_spawn_budget = minf(
		_spawn_budget + threat_gain,
		max_budget
	)

	spawn_budget_changed.emit(
		_spawn_budget,
		max_budget
	)


func _update_spawn_check(
	stage: EnemySpawnStageData,
	delta: float
) -> void:
	_spawn_check_elapsed_time += delta

	var spawn_check_interval: float = (
		stage.get_safe_spawn_check_interval()
	)

	if _spawn_check_elapsed_time < spawn_check_interval:
		return

	_spawn_check_elapsed_time -= spawn_check_interval

	_try_spawn_from_stage(stage)


func _try_spawn_from_stage(
	stage: EnemySpawnStageData
) -> void:
	var max_alive: int = maxi(
		0,
		stage.max_alive_enemies
	)

	var current_alive: int = (
		enemy_manager.get_active_enemy_count()
	)

	if current_alive >= max_alive:
		return

	var available_slots: int = max_alive - current_alive

	var spawn_attempts: int = mini(
		maxi(1, stage.max_spawns_per_check),
		available_slots
	)

	var spawned_count: int = 0

	for _spawn_index: int in range(spawn_attempts):
		var entry: EnemySpawnEntryData = (
			_choose_spawn_entry(stage)
		)

		if entry == null:
			break

		var enemy: DesktopVirus = (
			enemy_manager.spawn_enemy_from_spawn_entry(
				entry
			)
		)

		if enemy == null:
			break

		_consume_spawn_budget(
			entry.threat_cost
		)

		spawned_count += 1

		if debug_print_spawns:
			print(
				"Spawned enemy: ",
				entry.display_name,
				" | budget: ",
				_spawn_budget
			)

	if spawned_count <= 0:
		return

	_emit_spawn_budget_changed()
	write_run_progress_to_game_state()


func _choose_spawn_entry(
	stage: EnemySpawnStageData
) -> EnemySpawnEntryData:
	var total_weight: int = _get_total_eligible_weight(stage)

	if total_weight <= 0:
		return null

	var roll: int = _random.randi_range(
		1,
		total_weight
	)

	var running_weight: int = 0

	for entry: EnemySpawnEntryData in stage.enemy_pool:
		if not _is_entry_eligible(entry):
			continue

		running_weight += maxi(
			0,
			entry.weight
		)

		if roll <= running_weight:
			return entry

	return null


func _get_total_eligible_weight(
	stage: EnemySpawnStageData
) -> int:
	var total_weight: int = 0

	for entry: EnemySpawnEntryData in stage.enemy_pool:
		if not _is_entry_eligible(entry):
			continue

		total_weight += maxi(
			0,
			entry.weight
		)

	return total_weight


func _is_entry_eligible(
	entry: EnemySpawnEntryData
) -> bool:
	if entry == null:
		return false

	return entry.can_spawn(
		_total_elapsed_time,
		_spawn_budget
	)


func _consume_spawn_budget(amount: float) -> void:
	_spawn_budget = maxf(
		0.0,
		_spawn_budget - maxf(0.0, amount)
	)


func _clamp_budget_to_current_stage() -> void:
	var current_stage: EnemySpawnStageData = (
		_get_current_stage()
	)

	if current_stage == null:
		return

	_spawn_budget = minf(
		_spawn_budget,
		current_stage.get_safe_max_stored_budget()
	)


func _emit_current_stage() -> void:
	var current_stage: EnemySpawnStageData = (
		_get_current_stage()
	)

	if current_stage == null:
		return

	stage_changed.emit(
		_stage_index,
		current_stage
	)

	_emit_spawn_budget_changed()


func _emit_spawn_budget_changed() -> void:
	var current_stage: EnemySpawnStageData = (
		_get_current_stage()
	)

	if current_stage == null:
		return

	spawn_budget_changed.emit(
		_spawn_budget,
		current_stage.get_safe_max_stored_budget()
	)


func _update_game_state_sync(delta: float) -> void:
	if not sync_run_progress_to_game_state:
		return

	_run_progress_sync_elapsed_time += delta

	if _run_progress_sync_elapsed_time < run_progress_sync_interval:
		return

	_run_progress_sync_elapsed_time = 0.0

	write_run_progress_to_game_state()


func _on_system_destroyed() -> void:
	stop_director()
