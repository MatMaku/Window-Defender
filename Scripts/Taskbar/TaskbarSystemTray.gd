extends PanelContainer
class_name TaskbarSystemTray

@export_category("Display")

@export var ram_prefix: String = "RAM "
@export var crypto_prefix: String = "$"
@export var virus_data_prefix: String = "DATA "

@onready var ram_label: Label = (
	get_node_or_null("RamLabel") as Label
)

@onready var crypto_label: Label = (
	get_node_or_null("HBoxContainer/CryptoLabel") as Label
)

@onready var data_label: Label = (
	get_node_or_null("HBoxContainer/DataLabel") as Label
)

@onready var clock_label: Label = (
	get_node_or_null("ClockLabel") as Label
)

@onready var clock_timer: Timer = (
	get_node_or_null("ClockTimer") as Timer
)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not _validate_dependencies():
		return

	_connect_game_state_signals()
	_configure_clock_timer()
	_refresh_all_values()


func _connect_game_state_signals() -> void:
	if not GameState.ram_changed.is_connected(
		_on_ram_changed
	):
		GameState.ram_changed.connect(
			_on_ram_changed
		)

	if not GameState.crypto_changed.is_connected(
		_on_crypto_changed
	):
		GameState.crypto_changed.connect(
			_on_crypto_changed
		)

	if not GameState.virus_data_changed.is_connected(
		_on_virus_data_changed
	):
		GameState.virus_data_changed.connect(
			_on_virus_data_changed
		)


func _configure_clock_timer() -> void:
	if not clock_timer.timeout.is_connected(
		_refresh_clock
	):
		clock_timer.timeout.connect(
			_refresh_clock
		)

	clock_timer.wait_time = 1.0
	clock_timer.one_shot = false
	clock_timer.ignore_time_scale = true
	clock_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	clock_timer.start()


func _refresh_all_values() -> void:
	_on_ram_changed(
		GameState.used_ram,
		GameState.max_ram
	)

	_on_crypto_changed(
		GameState.crypto
	)

	_on_virus_data_changed(
		GameState.virus_data
	)

	_refresh_clock()


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


func _refresh_clock() -> void:
	var date_time: Dictionary = (
		Time.get_datetime_dict_from_system()
	)

	var hour_24: int = int(
		date_time.get("hour", 0)
	)

	var minute: int = int(
		date_time.get("minute", 0)
	)

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


func _validate_dependencies() -> bool:
	if ram_label == null:
		push_error(
			"TaskbarSystemTray could not find RamLabel."
		)
		return false

	if crypto_label == null:
		push_error(
			"TaskbarSystemTray could not find HBoxContainer/CryptoLabel."
		)
		return false

	if data_label == null:
		push_error(
			"TaskbarSystemTray could not find HBoxContainer/DataLabel."
		)
		return false

	if clock_label == null:
		push_error(
			"TaskbarSystemTray could not find ClockLabel."
		)
		return false

	if clock_timer == null:
		push_error(
			"TaskbarSystemTray could not find ClockTimer."
		)
		return false

	return true
