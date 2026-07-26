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
