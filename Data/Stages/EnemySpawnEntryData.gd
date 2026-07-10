extends Resource
class_name EnemySpawnEntryData

@export var display_name: String = "Basic Virus"
@export var enemy_scene: PackedScene

@export_range(0.01, 999.0, 0.01)
var threat_cost: float = 1.0

@export_range(1, 1000, 1)
var weight: int = 10

@export_range(0.0, 99999.0, 0.1)
var minimum_elapsed_time: float = 0.0


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
