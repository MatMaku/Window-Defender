extends Resource
class_name EnemySpawnEntryData

@export_category("Identity")

@export var enemy_id: StringName = &"basic_virus"
@export var display_name: String = "Basic Virus"
@export var enemy_scene: PackedScene

@export_category("Spawn Rules")

@export_range(0.01, 999.0, 0.01)
var threat_cost: float = 1.0

@export_range(1, 1000, 1)
var weight: int = 10

@export_range(0.0, 99999.0, 0.1)
var minimum_elapsed_time: float = 0.0

@export_category("Stats")

@export_range(0.1, 999.0, 0.1)
var max_health: float = 2.0

@export_range(0.0, 1000.0, 0.1)
var movement_speed: float = 48.0

@export_range(0.0, 999.0, 0.01)
var attack_damage: float = 0.5

@export_range(0.05, 10.0, 0.05)
var attack_interval_seconds: float = 1.25

@export_range(0.0, 10.0, 0.1)
var attack_arrival_distance: float = 0.75

@export_range(0.0, 40.0, 0.5)
var attack_overlap_distance: float = 12.0

@export_category("Rewards")

@export_range(0, 999, 1)
var virus_data_reward: int = 1


func can_spawn(
	total_elapsed_time: float,
	available_budget: float
) -> bool:
	if enemy_scene == null:
		return false

	if weight <= 0:
		return false

	if total_elapsed_time < minimum_elapsed_time:
		return false

	if available_budget < threat_cost:
		return false

	return true
