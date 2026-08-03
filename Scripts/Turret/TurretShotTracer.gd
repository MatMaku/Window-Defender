extends Line2D
class_name TurretShotTracer

var _original_start: Vector2 = Vector2.ZERO
var _original_end: Vector2 = Vector2.ZERO


func play(
	start_global_position: Vector2,
	end_global_position: Vector2,
	duration_seconds: float
) -> void:
	_original_start = to_local(start_global_position)
	_original_end = to_local(end_global_position)

	clear_points()
	add_point(_original_start)
	add_point(_original_end)

	var safe_duration: float = maxf(0.01, duration_seconds)
	var tracer_tween: Tween = create_tween()
	tracer_tween.tween_method(
		_set_retraction_progress,
		0.0,
		1.0,
		safe_duration
	).set_trans(Tween.TRANS_LINEAR)
	tracer_tween.finished.connect(queue_free)


func _set_retraction_progress(progress: float) -> void:
	if get_point_count() < 2:
		return

	set_point_position(
		0,
		_original_start.lerp(
			_original_end,
			clampf(progress, 0.0, 1.0)
		)
	)
	set_point_position(1, _original_end)
