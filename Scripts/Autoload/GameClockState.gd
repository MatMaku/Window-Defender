extends Node
class_name GameClockState

signal time_changed(total_game_minutes: float)
signal hour_changed(hour_24: int)
signal day_changed(game_day_index: int)
signal clock_speed_changed(game_minutes_per_real_second: float)

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const MINUTES_PER_DAY: int = MINUTES_PER_HOUR * HOURS_PER_DAY
const START_UNIX_TIMESTAMP: int = 883612800

var total_game_minutes: float:
	get:
		return _total_game_minutes

var game_minutes_per_real_second: float:
	get:
		return _game_minutes_per_real_second

var _total_game_minutes: float = 0.0
var _game_minutes_per_real_second: float = 1.0
var _initial_game_minutes_per_real_second: float = 1.0


func reset() -> void:
	_total_game_minutes = 0.0
	_game_minutes_per_real_second = (
		_initial_game_minutes_per_real_second
	)

	time_changed.emit(_total_game_minutes)
	hour_changed.emit(get_hour_24())
	day_changed.emit(get_game_day_index())
	clock_speed_changed.emit(
		_game_minutes_per_real_second
	)


func configure_speed(
	new_game_minutes_per_real_second: float
) -> void:
	_initial_game_minutes_per_real_second = maxf(
		0.0,
		new_game_minutes_per_real_second
	)

	set_clock_speed(
		_initial_game_minutes_per_real_second
	)


func set_clock_speed(
	new_game_minutes_per_real_second: float
) -> void:
	var safe_speed: float = maxf(
		0.0,
		new_game_minutes_per_real_second
	)

	if is_equal_approx(
		_game_minutes_per_real_second,
		safe_speed
	):
		return

	_game_minutes_per_real_second = safe_speed
	clock_speed_changed.emit(
		_game_minutes_per_real_second
	)


func advance_game_minutes(amount: float) -> void:
	if amount <= 0.0:
		return

	var previous_display_minute: int = (
		get_display_game_minute()
	)
	var previous_total_hour: int = (
		previous_display_minute / MINUTES_PER_HOUR
	)
	var previous_game_day_index: int = (
		previous_display_minute / MINUTES_PER_DAY
	)

	_total_game_minutes += amount

	var current_display_minute: int = (
		get_display_game_minute()
	)

	if current_display_minute == previous_display_minute:
		return

	time_changed.emit(_total_game_minutes)

	var current_total_hour: int = (
		current_display_minute / MINUTES_PER_HOUR
	)

	if current_total_hour != previous_total_hour:
		hour_changed.emit(get_hour_24())

	var current_game_day_index: int = (
		current_display_minute / MINUTES_PER_DAY
	)

	if current_game_day_index != previous_game_day_index:
		day_changed.emit(current_game_day_index)


func get_display_game_minute() -> int:
	return floori(_total_game_minutes)


func get_minute_of_day() -> int:
	return posmod(
		get_display_game_minute(),
		MINUTES_PER_DAY
	)


func get_game_day_index() -> int:
	return (
		get_display_game_minute()
		/ MINUTES_PER_DAY
	)


func get_date_time_dict() -> Dictionary:
	var elapsed_seconds: int = (
		get_display_game_minute() * 60
	)

	return Time.get_datetime_dict_from_unix_time(
		START_UNIX_TIMESTAMP + elapsed_seconds
	)


func get_year() -> int:
	return int(
		get_date_time_dict().get("year", 1998)
	)


func get_month() -> int:
	return int(
		get_date_time_dict().get("month", 1)
	)


func get_day_of_month() -> int:
	return int(
		get_date_time_dict().get("day", 1)
	)


func get_hour_24() -> int:
	return get_minute_of_day() / MINUTES_PER_HOUR


func get_minute() -> int:
	return get_minute_of_day() % MINUTES_PER_HOUR


func get_clock_snapshot() -> Dictionary:
	return {
		"total_game_minutes": _total_game_minutes,
		"game_minutes_per_real_second": (
			_game_minutes_per_real_second
		)
	}


func restore_from_snapshot(snapshot: Dictionary) -> void:
	var previous_display_minute: int = (
		get_display_game_minute()
	)
	var previous_total_hour: int = (
		previous_display_minute / MINUTES_PER_HOUR
	)
	var previous_game_day_index: int = (
		previous_display_minute / MINUTES_PER_DAY
	)
	var previous_speed: float = (
		_game_minutes_per_real_second
	)

	_total_game_minutes = maxf(
		0.0,
		float(
			snapshot.get(
				"total_game_minutes",
				0.0
			)
		)
	)

	_game_minutes_per_real_second = maxf(
		0.0,
		float(
			snapshot.get(
				"game_minutes_per_real_second",
				_game_minutes_per_real_second
			)
		)
	)

	time_changed.emit(_total_game_minutes)

	var current_display_minute: int = (
		get_display_game_minute()
	)
	var current_total_hour: int = (
		current_display_minute / MINUTES_PER_HOUR
	)

	if current_total_hour != previous_total_hour:
		hour_changed.emit(get_hour_24())

	var current_game_day_index: int = (
		current_display_minute / MINUTES_PER_DAY
	)

	if current_game_day_index != previous_game_day_index:
		day_changed.emit(current_game_day_index)

	if not is_equal_approx(
		previous_speed,
		_game_minutes_per_real_second
	):
		clock_speed_changed.emit(
			_game_minutes_per_real_second
		)
