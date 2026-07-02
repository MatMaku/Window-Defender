extends PanelContainer
class_name TaskbarSystemTray

@onready var ram_label: Label = (
	get_node_or_null("RamLabel") as Label
)

@onready var crypto_label: Label = (
	get_node_or_null("CryptoLabel") as Label
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

	GameState.ram_changed.connect(
		_on_ram_changed
	)

	GameState.crypto_changed.connect(
		_on_crypto_changed
	)

	clock_timer.timeout.connect(
		_refresh_clock
	)

	clock_timer.wait_time = 1.0
	clock_timer.one_shot = false
	clock_timer.ignore_time_scale = true
	clock_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	clock_timer.start()

	_on_ram_changed(
		GameState.used_ram,
		GameState.max_ram
	)

	_on_crypto_changed(
		GameState.crypto
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

	ram_label.text = "RAM %d/%d" % [
		available_ram,
		max_ram
	]


func _on_crypto_changed(
	current_crypto: int
) -> void:
	crypto_label.text = "$%d" % current_crypto


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
			"TaskbarSystemTray could not find CryptoLabel."
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
