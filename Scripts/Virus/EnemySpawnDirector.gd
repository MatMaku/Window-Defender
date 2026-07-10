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


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_random.randomize()

	if (
		pause_when_system_destroyed
		and system_manager != null
	):
		system_manager.system_destroyed.connect(
			_on_system_destroyed
		)

	if autostart:
		call_deferred("start_director")


func _process(delta: float) -> void:
	if not _is_running:
		return

	if stages.is_empty():
		return

	_total_elapsed_time += delta
	_stage_elapsed_time += delta

	_advance_stage_if_needed()

	var current_stage: EnemySpawnStageData = (
		_get_current_stage()
	)

	if current_stage == null:
		return

	_accumulate_spawn_budget(
		current_stage,
		delta
	)

	_spawn_check_elapsed_time += delta

	if (
		_spawn_check_elapsed_time
		< current_stage.get_safe_spawn_check_interval()
	):
		return

	_spawn_check_elapsed_time = 0.0

	_try_spawn_from_stage(current_stage)


func start_director(reset_state: bool = true) -> void:
	if reset_state:
		reset_director_state()

	if _is_running:
		return

	_is_running = true

	director_started.emit()

	var current_stage: EnemySpawnStageData = (
		_get_current_stage()
	)

	if current_stage != null:
		stage_changed.emit(
			_stage_index,
			current_stage
		)


func stop_director() -> void:
	if not _is_running:
		return

	_is_running = false

	director_stopped.emit()


func reset_director_state() -> void:
	_total_elapsed_time = 0.0
	_stage_elapsed_time = 0.0
	_spawn_check_elapsed_time = 0.0
	_spawn_budget = 0.0
	_stage_index = 0

	var current_stage: EnemySpawnStageData = (
		_get_current_stage()
	)

	if current_stage != null:
		spawn_budget_changed.emit(
			_spawn_budget,
			current_stage.get_safe_max_stored_budget()
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

		var next_stage: EnemySpawnStageData = (
			_get_current_stage()
		)

		if next_stage == null:
			return

		if reset_budget_on_stage_change:
			_spawn_budget = 0.0
		else:
			_spawn_budget = minf(
				_spawn_budget,
				next_stage.get_safe_max_stored_budget()
			)

		if debug_print_stage_changes:
			print(
				"EnemySpawnDirector stage changed to: ",
				next_stage.stage_name
			)

		stage_changed.emit(
			_stage_index,
			next_stage
		)

		spawn_budget_changed.emit(
			_spawn_budget,
			next_stage.get_safe_max_stored_budget()
		)


func _accumulate_spawn_budget(
	stage: EnemySpawnStageData,
	delta: float
) -> void:
	var max_budget: float = (
		stage.get_safe_max_stored_budget()
	)

	var threat_gain: float = maxf(
		0.0,
		stage.threat_per_second
	) * delta

	_spawn_budget = minf(
		_spawn_budget + threat_gain,
		max_budget
	)

	spawn_budget_changed.emit(
		_spawn_budget,
		max_budget
	)


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

	var max_spawns_this_check: int = mini(
		maxi(1, stage.max_spawns_per_check),
		available_slots
	)

	for _spawn_index: int in range(max_spawns_this_check):
		var entry: EnemySpawnEntryData = (
			_choose_spawn_entry(stage)
		)

		if entry == null:
			return

		var enemy: BasicVirus = (
			enemy_manager.spawn_enemy_from_random_edge(
				entry.enemy_scene
			)
		)

		if enemy == null:
			return

		_spawn_budget = maxf(
			0.0,
			_spawn_budget - entry.threat_cost
		)

		if debug_print_spawns:
			print(
				"Spawned enemy: ",
				entry.display_name,
				" | budget: ",
				_spawn_budget
			)

		spawn_budget_changed.emit(
			_spawn_budget,
			stage.get_safe_max_stored_budget()
		)


func _choose_spawn_entry(
	stage: EnemySpawnStageData
) -> EnemySpawnEntryData:
	var candidates: Array[EnemySpawnEntryData] = []
	var total_weight: int = 0

	for entry: EnemySpawnEntryData in stage.enemy_pool:
		if entry == null:
			continue

		if not entry.can_spawn(
			_total_elapsed_time,
			_spawn_budget
		):
			continue

		var safe_weight: int = maxi(
			0,
			entry.weight
		)

		if safe_weight <= 0:
			continue

		candidates.append(entry)
		total_weight += safe_weight

	if candidates.is_empty():
		return null

	if total_weight <= 0:
		return null

	var roll: int = _random.randi_range(
		1,
		total_weight
	)

	var running_weight: int = 0

	for entry: EnemySpawnEntryData in candidates:
		running_weight += maxi(
			0,
			entry.weight
		)

		if roll <= running_weight:
			return entry

	return candidates[
		candidates.size() - 1
	]


func _on_system_destroyed() -> void:
	stop_director()
