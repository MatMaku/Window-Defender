extends Node
class_name GameRunState

enum SpawnMode {
	DAILY_CYCLE,
	INFINITE
}

enum SpawnPhase {
	REST,
	ACTIVE,
	STOPPED
}

signal spawn_mode_changed(mode: SpawnMode)
signal spawn_phase_changed(phase: SpawnPhase)

signal wave_budget_changed(
	current_budget: float,
	maximum_budget: float
)

signal run_progress_changed(progress_snapshot: Dictionary)

var spawn_mode: SpawnMode:
	get:
		return _spawn_mode

var spawn_phase: SpawnPhase:
	get:
		return _spawn_phase

var game_day_index: int:
	get:
		return _game_day_index

var spawn_budget_remaining: float:
	get:
		return _spawn_budget_remaining

var spawn_budget_maximum: float:
	get:
		return _spawn_budget_maximum

var last_spawn_game_minute: float:
	get:
		return _last_spawn_game_minute

var spawning_exhausted_for_period: bool:
	get:
		return _spawning_exhausted_for_period

var _spawn_mode: SpawnMode = SpawnMode.DAILY_CYCLE
var _spawn_phase: SpawnPhase = SpawnPhase.STOPPED
var _game_day_index: int = 0
var _spawn_budget_remaining: float = 0.0
var _spawn_budget_maximum: float = 0.0
var _last_spawn_game_minute: float = 0.0
var _spawning_exhausted_for_period: bool = false


func reset() -> void:
	_spawn_mode = SpawnMode.DAILY_CYCLE
	_spawn_phase = SpawnPhase.STOPPED
	_game_day_index = 0
	_spawn_budget_remaining = 0.0
	_spawn_budget_maximum = 0.0
	_last_spawn_game_minute = 0.0
	_spawning_exhausted_for_period = false

	_emit_all_progress()


func set_spawn_mode(new_mode: SpawnMode) -> bool:
	var safe_mode: SpawnMode = _sanitize_spawn_mode(
		int(new_mode)
	)

	if _spawn_mode == safe_mode:
		return false

	_spawn_mode = safe_mode
	spawn_mode_changed.emit(_spawn_mode)
	_emit_run_progress_changed()
	return true


func begin_game_day(
	new_game_day_index: int,
	wave_budget: float,
	current_game_minute: float
) -> void:
	_game_day_index = maxi(
		0,
		new_game_day_index
	)

	_spawn_budget_maximum = maxf(
		0.0,
		wave_budget
	)

	_spawn_budget_remaining = (
		_spawn_budget_maximum
	)

	_last_spawn_game_minute = maxf(
		0.0,
		current_game_minute
	)

	_spawning_exhausted_for_period = false

	_emit_wave_budget_changed()
	_emit_run_progress_changed()


func set_spawn_phase(new_phase: SpawnPhase) -> bool:
	var safe_phase: SpawnPhase = _sanitize_spawn_phase(
		int(new_phase)
	)

	if _spawn_phase == safe_phase:
		return false

	_spawn_phase = safe_phase
	spawn_phase_changed.emit(_spawn_phase)
	_emit_run_progress_changed()
	return true


func record_spawn_attempt(
	current_game_minute: float
) -> void:
	var safe_game_minute: float = maxf(
		0.0,
		current_game_minute
	)

	if is_equal_approx(
		_last_spawn_game_minute,
		safe_game_minute
	):
		return

	_last_spawn_game_minute = safe_game_minute
	_emit_run_progress_changed()


func try_consume_spawn_budget(amount: float) -> bool:
	if amount <= 0.0:
		return false

	if _spawn_budget_remaining < amount:
		return false

	_spawn_budget_remaining = maxf(
		0.0,
		_spawn_budget_remaining - amount
	)

	_emit_wave_budget_changed()
	_emit_run_progress_changed()
	return true


func set_spawning_exhausted_for_period(
	exhausted: bool
) -> void:
	if _spawning_exhausted_for_period == exhausted:
		return

	_spawning_exhausted_for_period = exhausted
	_emit_run_progress_changed()


func get_run_progress_snapshot() -> Dictionary:
	return {
		"spawn_mode": int(_spawn_mode),
		"spawn_phase": int(_spawn_phase),
		"game_day_index": _game_day_index,
		"spawn_budget_remaining": (
			_spawn_budget_remaining
		),
		"spawn_budget_maximum": (
			_spawn_budget_maximum
		),
		"last_spawn_game_minute": (
			_last_spawn_game_minute
		),
		"spawning_exhausted_for_period": (
			_spawning_exhausted_for_period
		)
	}


func create_save_snapshot() -> Dictionary:
	return get_run_progress_snapshot()


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	restore_from_snapshot(snapshot)


func restore_from_snapshot(snapshot: Dictionary) -> void:
	_spawn_mode = _sanitize_spawn_mode(
		int(
			snapshot.get(
				"spawn_mode",
				SpawnMode.DAILY_CYCLE
			)
		)
	)

	_spawn_phase = _sanitize_spawn_phase(
		int(
			snapshot.get(
				"spawn_phase",
				SpawnPhase.STOPPED
			)
		)
	)

	_game_day_index = maxi(
		0,
		int(
			snapshot.get(
				"game_day_index",
				0
			)
		)
	)

	_spawn_budget_maximum = maxf(
		0.0,
		float(
			snapshot.get(
				"spawn_budget_maximum",
				0.0
			)
		)
	)

	_spawn_budget_remaining = clampf(
		float(
			snapshot.get(
				"spawn_budget_remaining",
				0.0
			)
		),
		0.0,
		_spawn_budget_maximum
	)

	_last_spawn_game_minute = maxf(
		0.0,
		float(
			snapshot.get(
				"last_spawn_game_minute",
				0.0
			)
		)
	)

	_spawning_exhausted_for_period = bool(
		snapshot.get(
			"spawning_exhausted_for_period",
			false
		)
	)

	_emit_all_progress()


func _sanitize_spawn_mode(value: int) -> SpawnMode:
	match value:
		SpawnMode.INFINITE:
			return SpawnMode.INFINITE

		_:
			return SpawnMode.DAILY_CYCLE


func _sanitize_spawn_phase(value: int) -> SpawnPhase:
	match value:
		SpawnPhase.REST:
			return SpawnPhase.REST

		SpawnPhase.ACTIVE:
			return SpawnPhase.ACTIVE

		_:
			return SpawnPhase.STOPPED


func _emit_all_progress() -> void:
	spawn_mode_changed.emit(_spawn_mode)
	spawn_phase_changed.emit(_spawn_phase)
	_emit_wave_budget_changed()
	_emit_run_progress_changed()


func _emit_wave_budget_changed() -> void:
	wave_budget_changed.emit(
		_spawn_budget_remaining,
		_spawn_budget_maximum
	)


func _emit_run_progress_changed() -> void:
	run_progress_changed.emit(
		get_run_progress_snapshot()
	)
