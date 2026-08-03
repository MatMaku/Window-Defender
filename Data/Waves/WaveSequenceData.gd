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

@export_category("Infinite Progression")

@export_range(0.0, 999999.0, 1.0)
var infinite_mode_start_total_game_minutes: float = 8640.0

@export var infinite_wave: DailyWaveData

@export_range(0.0, 99999.0, 0.1)
var infinite_budget_growth_per_cycle: float = 30.0

@export_range(0.0, 10.0, 0.01)
var infinite_health_growth_per_cycle: float = 0.10

@export_range(0.0, 10.0, 0.01)
var infinite_damage_growth_per_cycle: float = 0.05

@export_range(0.01, 1.0, 0.01)
var infinite_spawn_interval_multiplier_per_cycle: float = 0.94

@export_range(0.01, 1440.0, 0.01)
var infinite_min_spawn_interval_game_minutes: float = 21.6

@export_range(0, 100, 1)
var infinite_active_enemy_increment_per_cycle: int = 2

@export_range(1, 500, 1)
var infinite_max_active_enemies: int = 64


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


func get_infinite_configuration() -> DailyWaveData:
	if infinite_wave != null:
		return infinite_wave

	return get_day_configuration(days.size() - 1)


func should_enter_infinite_mode(
	total_game_minutes: float
) -> bool:
	return (
		infinite_mode_start_total_game_minutes > 0.0
		and total_game_minutes
			>= infinite_mode_start_total_game_minutes
	)


func get_infinite_cycle_index(
	total_game_minutes: float
) -> int:
	if not should_enter_infinite_mode(total_game_minutes):
		return 0

	return maxi(
		0,
		floori(
			(
				total_game_minutes
				- infinite_mode_start_total_game_minutes
			) / float(MINUTES_PER_DAY)
		)
	)


func get_infinite_spawn_budget(
	total_game_minutes: float
) -> float:
	var configuration: DailyWaveData = (
		get_infinite_configuration()
	)
	if configuration == null:
		return 0.0

	return (
		configuration.get_safe_spawn_budget()
		+ infinite_budget_growth_per_cycle
		* float(get_infinite_cycle_index(total_game_minutes))
	)


func get_infinite_health_multiplier(
	total_game_minutes: float
) -> float:
	return pow(
		1.0 + maxf(0.0, infinite_health_growth_per_cycle),
		float(get_infinite_cycle_index(total_game_minutes))
	)


func get_infinite_damage_multiplier(
	total_game_minutes: float
) -> float:
	return pow(
		1.0 + maxf(0.0, infinite_damage_growth_per_cycle),
		float(get_infinite_cycle_index(total_game_minutes))
	)


func get_infinite_spawn_interval_game_minutes(
	total_game_minutes: float
) -> float:
	var configuration: DailyWaveData = (
		get_infinite_configuration()
	)
	if configuration == null:
		return infinite_min_spawn_interval_game_minutes

	var cycle_index: int = get_infinite_cycle_index(
		total_game_minutes
	)
	var interval_multiplier: float = clampf(
		infinite_spawn_interval_multiplier_per_cycle,
		0.01,
		1.0
	)
	return maxf(
		infinite_min_spawn_interval_game_minutes,
		configuration.get_safe_spawn_interval_game_minutes()
		* pow(interval_multiplier, float(cycle_index))
	)


func get_infinite_max_active_enemies(
	total_game_minutes: float
) -> int:
	var configuration: DailyWaveData = (
		get_infinite_configuration()
	)
	if configuration == null:
		return 0

	return mini(
		maxi(1, infinite_max_active_enemies),
		configuration.get_safe_max_active_enemies()
		+ infinite_active_enemy_increment_per_cycle
		* get_infinite_cycle_index(total_game_minutes)
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
