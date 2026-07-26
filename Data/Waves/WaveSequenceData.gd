extends Resource
class_name WaveSequenceData

const MINUTES_PER_DAY: int = 1440

@export_category("Default Active Period")

@export_range(0, 1439, 1)
var default_active_start_minute: int = 120

@export_range(0, 1439, 1)
var default_active_end_minute: int = 0

@export_category("Daily Progression")

@export var days: Array[DailyWaveData] = []


func get_day_configuration(
	game_day_index: int
) -> DailyWaveData:
	if days.is_empty():
		return null

	return days[
		get_day_configuration_index(
			game_day_index
		)
	]


func get_day_configuration_index(
	game_day_index: int
) -> int:
	if days.is_empty():
		return -1

	return clampi(
		game_day_index,
		0,
		days.size() - 1
	)


func get_active_start_minute(
	daily_wave: DailyWaveData
) -> int:
	if (
		daily_wave != null
		and daily_wave.override_sequence_active_period
	):
		return _normalize_minute(
			daily_wave.active_start_minute
		)

	return _normalize_minute(
		default_active_start_minute
	)


func get_active_end_minute(
	daily_wave: DailyWaveData
) -> int:
	if (
		daily_wave != null
		and daily_wave.override_sequence_active_period
	):
		return _normalize_minute(
			daily_wave.active_end_minute
		)

	return _normalize_minute(
		default_active_end_minute
	)


func is_minute_in_active_period(
	minute_of_day: int,
	daily_wave: DailyWaveData
) -> bool:
	var current_minute: int = _normalize_minute(
		minute_of_day
	)
	var start_minute: int = get_active_start_minute(
		daily_wave
	)
	var end_minute: int = get_active_end_minute(
		daily_wave
	)

	if start_minute == end_minute:
		return true

	if start_minute < end_minute:
		return (
			current_minute >= start_minute
			and current_minute < end_minute
		)

	return (
		current_minute >= start_minute
		or current_minute < end_minute
	)


func _normalize_minute(value: int) -> int:
	return posmod(
		value,
		MINUTES_PER_DAY
	)
