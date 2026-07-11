extends Node
class_name GameReloadStatsState

var normal_reload_duration: float = 1.45
var perfect_reload_finish_delay: float = 0.35
var reload_failure_penalty_duration: float = 0.85


func reset_from_start_data(start_data: GameStartData) -> void:
	normal_reload_duration = maxf(
		0.05,
		start_data.normal_reload_duration
	)

	perfect_reload_finish_delay = maxf(
		0.0,
		start_data.perfect_reload_finish_delay
	)

	reload_failure_penalty_duration = maxf(
		0.0,
		start_data.reload_failure_penalty_duration
	)


func set_normal_reload_duration(new_duration: float) -> void:
	normal_reload_duration = maxf(
		0.05,
		new_duration
	)


func set_perfect_reload_finish_delay(new_delay: float) -> void:
	perfect_reload_finish_delay = maxf(
		0.0,
		new_delay
	)


func set_reload_failure_penalty_duration(new_duration: float) -> void:
	reload_failure_penalty_duration = maxf(
		0.0,
		new_duration
	)
