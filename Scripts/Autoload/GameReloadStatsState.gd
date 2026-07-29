extends Node
class_name GameReloadStatsState

signal reload_stats_changed(
	normal_reload_duration: float,
	perfect_reload_finish_delay: float,
	reload_failure_penalty_duration: float
)

var normal_reload_duration: float:
	get:
		return _normal_reload_duration

var perfect_reload_finish_delay: float:
	get:
		return _perfect_reload_finish_delay

var reload_failure_penalty_duration: float:
	get:
		return _reload_failure_penalty_duration

var _normal_reload_duration: float = 1.45
var _perfect_reload_finish_delay: float = 0.35
var _reload_failure_penalty_duration: float = 0.85


func reset_from_start_data(start_data: GameStartData) -> void:
	_normal_reload_duration = maxf(
		0.05,
		start_data.normal_reload_duration
	)

	_perfect_reload_finish_delay = maxf(
		0.0,
		start_data.perfect_reload_finish_delay
	)

	_reload_failure_penalty_duration = maxf(
		0.0,
		start_data.reload_failure_penalty_duration
	)

	_emit_reload_stats_changed()


func set_normal_reload_duration(new_duration: float) -> void:
	_normal_reload_duration = maxf(
		0.05,
		new_duration
	)

	_emit_reload_stats_changed()


func set_perfect_reload_finish_delay(new_delay: float) -> void:
	_perfect_reload_finish_delay = maxf(
		0.0,
		new_delay
	)

	_emit_reload_stats_changed()


func set_reload_failure_penalty_duration(new_duration: float) -> void:
	_reload_failure_penalty_duration = maxf(
		0.0,
		new_duration
	)

	_emit_reload_stats_changed()


func create_save_snapshot() -> Dictionary:
	return {
		"normal_reload_duration": _normal_reload_duration,
		"perfect_reload_finish_delay": (
			_perfect_reload_finish_delay
		),
		"reload_failure_penalty_duration": (
			_reload_failure_penalty_duration
		)
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	_normal_reload_duration = maxf(
		0.05,
		float(snapshot.get("normal_reload_duration", 0.05))
	)
	_perfect_reload_finish_delay = maxf(
		0.0,
		float(
			snapshot.get(
				"perfect_reload_finish_delay",
				0.0
			)
		)
	)
	_reload_failure_penalty_duration = maxf(
		0.0,
		float(
			snapshot.get(
				"reload_failure_penalty_duration",
				0.0
			)
		)
	)

	_emit_reload_stats_changed()


func _emit_reload_stats_changed() -> void:
	reload_stats_changed.emit(
		_normal_reload_duration,
		_perfect_reload_finish_delay,
		_reload_failure_penalty_duration
	)
