extends Resource
class_name DailyWaveData

@export var display_name: String = "Daily Wave"

@export_category("Active Period")

@export var override_sequence_active_period: bool = false

@export_range(0, 1439, 1)
var active_start_minute: int = 120

@export_range(0, 1439, 1)
var active_end_minute: int = 0

@export_category("Spawn Rules")

@export_range(0.0, 99999.0, 0.1)
var spawn_budget: float = 8.0

@export_range(0.01, 1440.0, 0.01)
var spawn_interval_game_minutes: float = 30.0

@export_range(0, 500, 1)
var max_active_enemies: int = 4

@export_range(1, 20, 1)
var spawn_group_size: int = 1

@export var enemy_entries: Array[WaveEnemyEntry] = []

@export_category("Global Stat Multipliers")

@export_range(0.01, 100.0, 0.01)
var health_multiplier: float = 1.0

@export_range(0.0, 100.0, 0.01)
var speed_multiplier: float = 1.0

@export_range(0.0, 100.0, 0.01)
var damage_multiplier: float = 1.0

@export_range(0.01, 100.0, 0.01)
var attack_interval_multiplier: float = 1.0

@export_range(0.0, 100.0, 0.01)
var reward_multiplier: float = 1.0


func get_safe_spawn_budget() -> float:
	return maxf(
		0.0,
		spawn_budget
	)


func get_safe_spawn_interval_game_minutes() -> float:
	return maxf(
		0.01,
		spawn_interval_game_minutes
	)


func get_safe_max_active_enemies() -> int:
	return maxi(
		0,
		max_active_enemies
	)


func get_safe_spawn_group_size() -> int:
	return maxi(
		1,
		spawn_group_size
	)
