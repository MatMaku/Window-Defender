extends PanelContainer
class_name TaskbarSystemTray

@export_category("Display")

@export var ram_prefix: String = "RAM "
@export var crypto_prefix: String = "$"
@export var virus_data_prefix: String = "DATA "

@onready var ram_label: Label = %RamLabel
@onready var crypto_label: Label = %CryptoLabel
@onready var data_label: Label = %DataLabel
@onready var clock_label: Label = %ClockLabel
@onready var date_label: Label = %DateLabel
@onready var overclock_indicator: Control = %OverclockIndicator

var _ram_state: GameRamState
var _economy_state: GameEconomyState
var _clock_state: GameClockState
var _overclock_state: GameOverclockState


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ram_state = GameState.ram_state
	_economy_state = GameState.economy_state
	_clock_state = GameState.clock_state
	_overclock_state = GameState.overclock_state

	if not _validate_dependencies():
		return

	_connect_state_signals()
	_refresh_all_values()


func _connect_state_signals() -> void:
	if not _ram_state.ram_changed.is_connected(
		_on_ram_changed
	):
		_ram_state.ram_changed.connect(
			_on_ram_changed
		)

	if not _economy_state.crypto_changed.is_connected(
		_on_crypto_changed
	):
		_economy_state.crypto_changed.connect(
			_on_crypto_changed
		)

	if not _economy_state.virus_data_changed.is_connected(
		_on_virus_data_changed
	):
		_economy_state.virus_data_changed.connect(
			_on_virus_data_changed
		)

	if not _clock_state.time_changed.is_connected(
		_on_clock_time_changed
	):
		_clock_state.time_changed.connect(
			_on_clock_time_changed
		)

	if not _clock_state.day_changed.is_connected(
		_on_clock_day_changed
	):
		_clock_state.day_changed.connect(
			_on_clock_day_changed
		)

	if not _overclock_state.phase_changed.is_connected(
		_on_overclock_phase_changed
	):
		_overclock_state.phase_changed.connect(
			_on_overclock_phase_changed
		)


func _refresh_all_values() -> void:
	_on_ram_changed(
		_ram_state.used_ram,
		_ram_state.max_ram
	)

	_on_crypto_changed(
		_economy_state.crypto
	)

	_on_virus_data_changed(
		_economy_state.virus_data
	)

	_refresh_time_label()
	_refresh_date_label()
	_refresh_overclock_indicator()


func _on_ram_changed(
	used_ram: int,
	max_ram: int
) -> void:
	var available_ram: int = maxi(
		0,
		max_ram - used_ram
	)

	ram_label.text = "%s%d/%d" % [
		ram_prefix,
		available_ram,
		max_ram
	]


func _on_crypto_changed(
	current_crypto: int
) -> void:
	crypto_label.text = "%s%d" % [
		crypto_prefix,
		current_crypto
	]


func _on_virus_data_changed(
	current_virus_data: int
) -> void:
	data_label.text = "%s%d" % [
		virus_data_prefix,
		current_virus_data
	]


func _on_clock_time_changed(
	_total_game_minutes: float
) -> void:
	_refresh_time_label()


func _on_clock_day_changed(
	_game_day_index: int
) -> void:
	_refresh_date_label()


func _on_overclock_phase_changed(_phase: int) -> void:
	_refresh_overclock_indicator()


func _refresh_time_label() -> void:
	var hour_24: int = _clock_state.get_hour_24()
	var minute: int = _clock_state.get_minute()
	var meridiem: String = "AM"

	if hour_24 >= 12:
		meridiem = "PM"

	var hour_12: int = hour_24 % 12

	if hour_12 == 0:
		hour_12 = 12

	clock_label.text = "%d:%02d %s" % [
		hour_12,
		minute,
		meridiem
	]


func _refresh_date_label() -> void:
	var date_time: Dictionary = (
		_clock_state.get_date_time_dict()
	)

	date_label.text = "%02d/%02d/%04d" % [
		int(date_time.get("day", 1)),
		int(date_time.get("month", 1)),
		int(date_time.get("year", 1998))
	]


func _refresh_overclock_indicator() -> void:
	overclock_indicator.visible = (
		_overclock_state.is_effect_active()
	)


func _validate_dependencies() -> bool:
	if _ram_state == null:
		push_error(
			"TaskbarSystemTray requires GameRamState."
		)
		return false

	if _economy_state == null:
		push_error(
			"TaskbarSystemTray requires GameEconomyState."
		)
		return false

	if _clock_state == null:
		push_error(
			"TaskbarSystemTray requires GameClockState."
		)
		return false

	if _overclock_state == null:
		push_error(
			"TaskbarSystemTray requires GameOverclockState."
		)
		return false

	if ram_label == null:
		push_error(
			"TaskbarSystemTray could not find RamLabel."
		)
		return false

	if crypto_label == null:
		push_error(
			"TaskbarSystemTray could not find CryptoLabel."
		)
		return false

	if data_label == null:
		push_error(
			"TaskbarSystemTray could not find DataLabel."
		)
		return false

	if clock_label == null:
		push_error(
			"TaskbarSystemTray could not find ClockLabel."
		)
		return false

	if date_label == null:
		push_error(
			"TaskbarSystemTray could not find DateLabel."
		)
		return false

	if overclock_indicator == null:
		push_error(
			"TaskbarSystemTray could not find OverclockIndicator."
		)
		return false

	return true
