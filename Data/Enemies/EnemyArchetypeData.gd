extends Resource
class_name EnemyArchetypeData

@export_category("Identity")

@export var enemy_id: StringName = &"basic_virus"
@export var display_name: String = "Basic Virus"
@export var enemy_scene: PackedScene

@export_category("Base Stats")

@export_range(0.1, 999.0, 0.1)
var base_max_health: float = 2.0

@export_range(0.0, 1000.0, 0.1)
var base_movement_speed: float = 48.0

@export_range(0.0, 999.0, 0.01)
var base_attack_damage: float = 0.5

@export_range(0.05, 10.0, 0.05)
var base_attack_interval_seconds: float = 1.25

@export_range(0.0, 10.0, 0.1)
var base_attack_arrival_distance: float = 0.75

@export_range(0.0, 40.0, 0.5)
var base_attack_overlap_distance: float = 0.0

@export_category("Rewards and Spawn")

@export_range(0, 999, 1)
var base_virus_data_reward: int = 1

@export_range(0.01, 999.0, 0.01)
var default_spawn_cost: float = 1.0


func is_valid_archetype() -> bool:
	return (
		enemy_id != StringName()
		and enemy_scene != null
	)
