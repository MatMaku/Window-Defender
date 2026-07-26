extends Resource
class_name WaveEnemyEntry

@export var archetype: EnemyArchetypeData

@export_category("Spawn Rules")

@export_range(0.01, 1000.0, 0.01)
var weight: float = 1.0

@export_range(0.0, 999.0, 0.01)
var spawn_cost_override: float = 0.0

@export_range(0, 500, 1)
var max_alive: int = 0

@export_category("Stat Multipliers")

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


func is_configured() -> bool:
	return (
		archetype != null
		and archetype.is_valid_archetype()
		and weight > 0.0
	)


func get_spawn_cost() -> float:
	if spawn_cost_override > 0.0:
		return spawn_cost_override

	if archetype == null:
		return INF

	return maxf(
		0.01,
		archetype.default_spawn_cost
	)


func create_runtime_stats(
	daily_wave: DailyWaveData
) -> EnemyRuntimeStats:
	if archetype == null:
		return null

	var day_health_multiplier: float = 1.0
	var day_speed_multiplier: float = 1.0
	var day_damage_multiplier: float = 1.0
	var day_attack_interval_multiplier: float = 1.0
	var day_reward_multiplier: float = 1.0

	if daily_wave != null:
		day_health_multiplier = (
			daily_wave.health_multiplier
		)
		day_speed_multiplier = (
			daily_wave.speed_multiplier
		)
		day_damage_multiplier = (
			daily_wave.damage_multiplier
		)
		day_attack_interval_multiplier = (
			daily_wave.attack_interval_multiplier
		)
		day_reward_multiplier = (
			daily_wave.reward_multiplier
		)

	var stats: EnemyRuntimeStats = EnemyRuntimeStats.new()

	stats.enemy_id = archetype.enemy_id
	stats.display_name = archetype.display_name

	stats.max_health = maxf(
		0.1,
		archetype.base_max_health
		* maxf(0.01, day_health_multiplier)
		* maxf(0.01, health_multiplier)
	)

	stats.movement_speed = maxf(
		0.0,
		archetype.base_movement_speed
		* maxf(0.0, day_speed_multiplier)
		* maxf(0.0, speed_multiplier)
	)

	stats.attack_damage = maxf(
		0.0,
		archetype.base_attack_damage
		* maxf(0.0, day_damage_multiplier)
		* maxf(0.0, damage_multiplier)
	)

	stats.attack_interval_seconds = maxf(
		0.05,
		archetype.base_attack_interval_seconds
		* maxf(
			0.01,
			day_attack_interval_multiplier
		)
		* maxf(0.01, attack_interval_multiplier)
	)

	stats.attack_arrival_distance = maxf(
		0.0,
		archetype.base_attack_arrival_distance
	)

	stats.attack_overlap_distance = maxf(
		0.0,
		archetype.base_attack_overlap_distance
	)

	stats.virus_data_reward = maxi(
		0,
		roundi(
			float(archetype.base_virus_data_reward)
			* maxf(0.0, day_reward_multiplier)
			* maxf(0.0, reward_multiplier)
		)
	)

	return stats
