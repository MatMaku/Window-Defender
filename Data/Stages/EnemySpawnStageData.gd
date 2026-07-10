extends Resource
class_name EnemySpawnStageData

@export var stage_name: String = "Stage"

@export_range(0.0, 99999.0, 0.1)
var duration_seconds: float = 60.0

@export_range(0.0, 100.0, 0.01)
var threat_per_second: float = 0.25

@export_range(0.05, 60.0, 0.05)
var spawn_check_interval: float = 3.0

@export_range(0, 500, 1)
var max_alive_enemies: int = 3

@export_range(0.0, 999.0, 0.1)
var max_stored_threat_budget: float = 4.0

@export_range(1, 50, 1)
var max_spawns_per_check: int = 1

@export var enemy_pool: Array[EnemySpawnEntryData] = []


func is_infinite() -> bool:
	return duration_seconds <= 0.0


func get_safe_spawn_check_interval() -> float:
	return maxf(
		0.05,
		spawn_check_interval
	)


func get_safe_max_stored_budget() -> float:
	return maxf(
		0.0,
		max_stored_threat_budget
	)
