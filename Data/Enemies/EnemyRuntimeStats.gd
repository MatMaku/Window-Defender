extends RefCounted
class_name EnemyRuntimeStats

var enemy_id: StringName = &"desktop_virus"
var display_name: String = "Desktop Virus"

var max_health: float = 2.0
var movement_speed: float = 48.0
var attack_damage: float = 0.5
var attack_interval_seconds: float = 1.25
var attack_arrival_distance: float = 0.75
var attack_overlap_distance: float = 0.0

var virus_data_reward: int = 1


func create_save_snapshot() -> Dictionary:
	return {
		"enemy_id": str(enemy_id),
		"display_name": display_name,
		"max_health": max_health,
		"movement_speed": movement_speed,
		"attack_damage": attack_damage,
		"attack_interval_seconds": attack_interval_seconds,
		"attack_arrival_distance": attack_arrival_distance,
		"attack_overlap_distance": attack_overlap_distance,
		"virus_data_reward": virus_data_reward
	}


static func from_save_snapshot(
	snapshot: Dictionary
) -> EnemyRuntimeStats:
	var stats: EnemyRuntimeStats = EnemyRuntimeStats.new()
	stats.enemy_id = StringName(
		str(snapshot.get("enemy_id", ""))
	)
	stats.display_name = str(
		snapshot.get("display_name", "Desktop Virus")
	)
	stats.max_health = maxf(
		0.1,
		float(snapshot.get("max_health", 0.1))
	)
	stats.movement_speed = maxf(
		0.0,
		float(snapshot.get("movement_speed", 0.0))
	)
	stats.attack_damage = maxf(
		0.0,
		float(snapshot.get("attack_damage", 0.0))
	)
	stats.attack_interval_seconds = maxf(
		0.05,
		float(
			snapshot.get(
				"attack_interval_seconds",
				0.05
			)
		)
	)
	stats.attack_arrival_distance = maxf(
		0.0,
		float(
			snapshot.get(
				"attack_arrival_distance",
				0.0
			)
		)
	)
	stats.attack_overlap_distance = maxf(
		0.0,
		float(
			snapshot.get(
				"attack_overlap_distance",
				0.0
			)
		)
	)
	stats.virus_data_reward = maxi(
		0,
		int(snapshot.get("virus_data_reward", 0))
	)
	return stats
