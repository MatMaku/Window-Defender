extends Node
class_name EnemySpawnDirector

signal director_started
signal director_stopped

signal day_started(
	game_day_index: int,
	wave_configuration_index: int
)

signal active_period_started(game_day_index: int)
signal rest_period_started(game_day_index: int)

@export var enemy_manager: EnemyManager
@export var system_manager: SystemManager
@export var wave_sequence: WaveSequenceData

@export var autostart: bool = true
@export var pause_when_system_destroyed: bool = true

@export var initial_spawn_mode: GameRunState.SpawnMode = (
	GameRunState.SpawnMode.DAILY_CYCLE
)

@export_category("Debug")

@export var debug_print_phase_changes: bool = false
@export var debug_print_spawns: bool = false

var _random: RandomNumberGenerator = RandomNumberGenerator.new()

var _is_running: bool = false
var _observed_game_day_index: int = -1

var _clock_state: GameClockState
var _run_state: GameRunState


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_random.randomize()
	_connect_signals()

	if autostart:
		call_deferred("start_director")


func _process(_delta: float) -> void:
	if not _is_running:
		return

	_update_automatic_spawn_mode()
	_synchronize_current_day()
	_update_phase()
	_try_spawn_if_due()


func start_director(
	reset_progress: bool = true
) -> void:
	if _is_running:
		return

	if reset_progress:
		_run_state.reset()
		_run_state.set_spawn_mode(
			initial_spawn_mode
		)

	_is_running = true
	_observed_game_day_index = -1

	director_started.emit()

	var entered_infinite_mode: bool = (
		_update_automatic_spawn_mode()
	)
	if not entered_infinite_mode:
		_synchronize_current_day(
			reset_progress
		)

	_update_phase()


func stop_director() -> void:
	if not _is_running:
		return

	_is_running = false
	_run_state.set_spawn_phase(
		GameRunState.SpawnPhase.STOPPED
	)

	director_stopped.emit()


func is_running() -> bool:
	return _is_running


func get_current_game_day_index() -> int:
	return _clock_state.get_game_day_index()


func get_current_wave_configuration_index() -> int:
	if (
		_run_state.spawn_mode
		== GameRunState.SpawnMode.INFINITE
	):
		return wave_sequence.days.size()

	return wave_sequence.get_day_configuration_index(
		get_current_game_day_index()
	)


func get_current_daily_wave() -> DailyWaveData:
	if (
		_run_state.spawn_mode
		== GameRunState.SpawnMode.INFINITE
	):
		return wave_sequence.get_infinite_configuration()

	return wave_sequence.get_day_configuration(
		get_current_game_day_index()
	)


func get_current_spawn_budget() -> float:
	return _run_state.spawn_budget_remaining


func _resolve_references() -> void:
	_clock_state = GameState.clock_state
	_run_state = GameState.run_state

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
	if _clock_state == null:
		push_error(
			"EnemySpawnDirector requires GameClockState."
		)
		return false

	if _run_state == null:
		push_error(
			"EnemySpawnDirector requires GameRunState."
		)
		return false

	if enemy_manager == null:
		push_error(
			"EnemySpawnDirector requires EnemyManager."
		)
		return false

	if wave_sequence == null:
		push_error(
			"EnemySpawnDirector requires WaveSequenceData."
		)
		return false

	if wave_sequence.days.is_empty():
		push_error(
			"EnemySpawnDirector requires at least one daily wave."
		)
		return false

	return true


func _connect_signals() -> void:
	if not _run_state.spawn_mode_changed.is_connected(
		_on_spawn_mode_changed
	):
		_run_state.spawn_mode_changed.connect(
			_on_spawn_mode_changed
		)

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


func _synchronize_current_day(
	force_reset_budget: bool = false
) -> void:
	var current_game_day_index: int = (
		_clock_state.get_game_day_index()
	)
	var run_progress_needs_initialization: bool = (
		_run_state.spawn_phase
		== GameRunState.SpawnPhase.STOPPED
	)

	if (
		not force_reset_budget
		and not run_progress_needs_initialization
		and _observed_game_day_index
			== current_game_day_index
	):
		return

	_observed_game_day_index = current_game_day_index

	var daily_wave: DailyWaveData = (
		get_current_daily_wave()
	)

	if daily_wave == null:
		return

	var run_day_does_not_match: bool = (
		_run_state.game_day_index
		!= current_game_day_index
	)

	if (
		force_reset_budget
		or run_day_does_not_match
		or run_progress_needs_initialization
	):
		_run_state.begin_game_day(
			current_game_day_index,
			_get_current_spawn_budget(daily_wave),
			_clock_state.total_game_minutes
		)

	day_started.emit(
		current_game_day_index,
		get_current_wave_configuration_index()
	)


func _update_phase() -> void:
	var desired_phase: GameRunState.SpawnPhase = (
		_get_desired_phase()
	)

	var phase_changed: bool = (
		_run_state.set_spawn_phase(
			desired_phase
		)
	)

	if phase_changed:
		_run_state.record_spawn_attempt(
			_clock_state.total_game_minutes
		)

	if not phase_changed:
		return

	if debug_print_phase_changes:
		print(
			"EnemySpawnDirector phase: ",
			GameRunState.SpawnPhase.keys()[
				int(desired_phase)
			]
		)

	match desired_phase:
		GameRunState.SpawnPhase.ACTIVE:
			active_period_started.emit(
				_clock_state.get_game_day_index()
			)

		GameRunState.SpawnPhase.REST:
			rest_period_started.emit(
				_clock_state.get_game_day_index()
			)


func _get_desired_phase() -> GameRunState.SpawnPhase:
	if not _is_running:
		return GameRunState.SpawnPhase.STOPPED

	if (
		_run_state.spawn_mode
		== GameRunState.SpawnMode.INFINITE
	):
		return GameRunState.SpawnPhase.ACTIVE

	var daily_wave: DailyWaveData = (
		get_current_daily_wave()
	)

	if daily_wave == null:
		return GameRunState.SpawnPhase.STOPPED

	if wave_sequence.is_minute_in_active_period(
		_clock_state.get_minute_of_day(),
		daily_wave
	):
		return GameRunState.SpawnPhase.ACTIVE

	return GameRunState.SpawnPhase.REST


func _try_spawn_if_due() -> void:
	if (
		_run_state.spawn_phase
		!= GameRunState.SpawnPhase.ACTIVE
	):
		return

	if _run_state.spawning_exhausted_for_period:
		return

	var daily_wave: DailyWaveData = (
		get_current_daily_wave()
	)

	if daily_wave == null:
		return

	var current_game_minute: float = (
		_clock_state.total_game_minutes
	)

	if (
		current_game_minute
		< _run_state.last_spawn_game_minute
	):
		_run_state.record_spawn_attempt(
			current_game_minute
		)
		return

	var elapsed_since_attempt: float = (
		current_game_minute
		- _run_state.last_spawn_game_minute
	)

	if (
		elapsed_since_attempt
		< _get_current_spawn_interval_game_minutes(
			daily_wave
		)
	):
		return

	_run_state.record_spawn_attempt(
		current_game_minute
	)

	if _is_global_enemy_limit_reached(daily_wave):
		return

	_spawn_enemy_group(daily_wave)


func _spawn_enemy_group(
	daily_wave: DailyWaveData
) -> void:
	var group_size: int = (
		daily_wave.get_safe_spawn_group_size()
	)

	for _group_index: int in range(group_size):
		if _is_global_enemy_limit_reached(daily_wave):
			return

		var affordable_entries: Array[WaveEnemyEntry] = (
			_get_affordable_entries(daily_wave)
		)

		if affordable_entries.is_empty():
			_run_state.set_spawning_exhausted_for_period(
				true
			)
			return

		var eligible_entries: Array[WaveEnemyEntry] = (
			_get_entries_below_archetype_limit(
				affordable_entries
			)
		)

		if eligible_entries.is_empty():
			return

		var selected_entry: WaveEnemyEntry = (
			_choose_weighted_entry(
				eligible_entries
			)
		)

		if selected_entry == null:
			_run_state.set_spawning_exhausted_for_period(
				true
			)
			return

		var spawned_enemy: DesktopVirus = (
			enemy_manager.spawn_enemy_from_wave_entry(
				selected_entry,
				daily_wave,
				_get_current_health_multiplier(),
				_get_current_damage_multiplier()
			)
		)

		if spawned_enemy == null:
			_run_state.set_spawning_exhausted_for_period(
				true
			)
			return

		var spawn_cost: float = (
			selected_entry.get_spawn_cost()
		)

		if not _run_state.try_consume_spawn_budget(
			spawn_cost
		):
			push_error(
				"Spawn budget changed unexpectedly after spawning."
			)
			return

		if debug_print_spawns:
			print(
				"Spawned ",
				selected_entry.archetype.display_name,
				" | budget: ",
				_run_state.spawn_budget_remaining
			)

		if _get_affordable_entries(daily_wave).is_empty():
			_run_state.set_spawning_exhausted_for_period(
				true
			)
			return


func _is_global_enemy_limit_reached(
	daily_wave: DailyWaveData
) -> bool:
	var maximum_active_enemies: int = (
		_get_current_max_active_enemies(daily_wave)
	)

	if maximum_active_enemies <= 0:
		return true

	return (
		enemy_manager.get_active_enemy_count()
		>= maximum_active_enemies
	)


func _get_affordable_entries(
	daily_wave: DailyWaveData
) -> Array[WaveEnemyEntry]:
	var affordable_entries: Array[WaveEnemyEntry] = []

	for entry: WaveEnemyEntry in daily_wave.enemy_entries:
		if entry == null:
			continue

		if not entry.is_configured():
			continue

		if (
			entry.get_spawn_cost()
			> _run_state.spawn_budget_remaining
		):
			continue

		affordable_entries.append(entry)

	return affordable_entries


func _get_entries_below_archetype_limit(
	entries: Array[WaveEnemyEntry]
) -> Array[WaveEnemyEntry]:
	var eligible_entries: Array[WaveEnemyEntry] = []

	for entry: WaveEnemyEntry in entries:
		if entry.max_alive <= 0:
			eligible_entries.append(entry)
			continue

		var active_for_archetype: int = (
			enemy_manager.get_active_enemy_count_by_id(
				entry.archetype.enemy_id
			)
		)

		if active_for_archetype >= entry.max_alive:
			continue

		eligible_entries.append(entry)

	return eligible_entries


func _choose_weighted_entry(
	entries: Array[WaveEnemyEntry]
) -> WaveEnemyEntry:
	var total_weight: float = 0.0

	for entry: WaveEnemyEntry in entries:
		total_weight += maxf(
			0.0,
			entry.weight
		)

	if total_weight <= 0.0:
		return null

	var roll: float = _random.randf_range(
		0.0,
		total_weight
	)

	var running_weight: float = 0.0

	for entry: WaveEnemyEntry in entries:
		running_weight += maxf(
			0.0,
			entry.weight
		)

		if roll <= running_weight:
			return entry

	return entries.back()


func _update_automatic_spawn_mode() -> bool:
	if (
		_run_state.spawn_mode
		== GameRunState.SpawnMode.INFINITE
	):
		return false

	if not wave_sequence.should_enter_infinite_mode(
		_clock_state.total_game_minutes
	):
		return false

	return _run_state.set_spawn_mode(
		GameRunState.SpawnMode.INFINITE
	)


func _get_current_spawn_budget(
	daily_wave: DailyWaveData
) -> float:
	if (
		_run_state.spawn_mode
		== GameRunState.SpawnMode.INFINITE
	):
		return wave_sequence.get_infinite_spawn_budget(
			_clock_state.total_game_minutes
		)

	return daily_wave.get_safe_spawn_budget()


func _get_current_spawn_interval_game_minutes(
	daily_wave: DailyWaveData
) -> float:
	if (
		_run_state.spawn_mode
		== GameRunState.SpawnMode.INFINITE
	):
		return (
			wave_sequence
			.get_infinite_spawn_interval_game_minutes(
				_clock_state.total_game_minutes
			)
		)

	return daily_wave.get_safe_spawn_interval_game_minutes()


func _get_current_max_active_enemies(
	daily_wave: DailyWaveData
) -> int:
	if (
		_run_state.spawn_mode
		== GameRunState.SpawnMode.INFINITE
	):
		return wave_sequence.get_infinite_max_active_enemies(
			_clock_state.total_game_minutes
		)

	return daily_wave.get_safe_max_active_enemies()


func _get_current_health_multiplier() -> float:
	if (
		_run_state.spawn_mode
		!= GameRunState.SpawnMode.INFINITE
	):
		return 1.0

	return wave_sequence.get_infinite_health_multiplier(
		_clock_state.total_game_minutes
	)


func _get_current_damage_multiplier() -> float:
	if (
		_run_state.spawn_mode
		!= GameRunState.SpawnMode.INFINITE
	):
		return 1.0

	return wave_sequence.get_infinite_damage_multiplier(
		_clock_state.total_game_minutes
	)


func _on_spawn_mode_changed(
	_mode: GameRunState.SpawnMode
) -> void:
	if not _is_running:
		return

	_observed_game_day_index = -1
	_synchronize_current_day(true)
	_update_phase()


func _on_system_destroyed() -> void:
	stop_director()
