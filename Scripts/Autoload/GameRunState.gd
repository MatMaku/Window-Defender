extends Node
class_name GameRunState

signal run_progress_changed(
	total_elapsed_time: float,
	stage_index: int,
	stage_elapsed_time: float,
	spawn_budget: float
)

var run_total_elapsed_time: float = 0.0
var enemy_spawn_stage_index: int = 0
var enemy_spawn_stage_elapsed_time: float = 0.0
var enemy_spawn_budget: float = 0.0


func reset() -> void:
	run_total_elapsed_time = 0.0
	enemy_spawn_stage_index = 0
	enemy_spawn_stage_elapsed_time = 0.0
	enemy_spawn_budget = 0.0
	_emit_run_progress_changed()


func set_run_progress(
	total_elapsed_time: float,
	stage_index: int,
	stage_elapsed_time: float,
	spawn_budget: float
) -> void:
	run_total_elapsed_time = maxf(
		0.0,
		total_elapsed_time
	)

	enemy_spawn_stage_index = maxi(
		0,
		stage_index
	)

	enemy_spawn_stage_elapsed_time = maxf(
		0.0,
		stage_elapsed_time
	)

	enemy_spawn_budget = maxf(
		0.0,
		spawn_budget
	)

	_emit_run_progress_changed()


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


func _emit_run_progress_changed() -> void:
	run_progress_changed.emit(
		run_total_elapsed_time,
		enemy_spawn_stage_index,
		enemy_spawn_stage_elapsed_time,
		enemy_spawn_budget
	)
