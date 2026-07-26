extends Node
class_name GameClockManager

@export var system_manager: SystemManager

@export_range(0.0, 1440.0, 0.1)
var game_minutes_per_real_second: float = 1.0

@export var autostart: bool = true
@export var stop_when_system_destroyed: bool = true

var _clock_state: GameClockState
var _is_running: bool = false


func _ready() -> void:
	_clock_state = GameState.clock_state

	if not _validate_dependencies():
		return

	_clock_state.configure_speed(
		game_minutes_per_real_second
	)

	_connect_signals()

	if autostart:
		start_clock()


func _process(delta: float) -> void:
	if not _is_running:
		return

	var elapsed_game_minutes: float = (
		delta
		* _clock_state.game_minutes_per_real_second
	)

	_clock_state.advance_game_minutes(
		elapsed_game_minutes
	)


func start_clock() -> void:
	_is_running = true


func stop_clock() -> void:
	_is_running = false


func is_clock_running() -> bool:
	return _is_running


func _connect_signals() -> void:
	if not stop_when_system_destroyed:
		return

	if system_manager == null:
		return

	if system_manager.system_destroyed.is_connected(
		_on_system_destroyed
	):
		return

	system_manager.system_destroyed.connect(
		_on_system_destroyed
	)


func _validate_dependencies() -> bool:
	if _clock_state == null:
		push_error(
			"GameClockManager requires GameClockState."
		)
		return false

	if stop_when_system_destroyed and system_manager == null:
		push_error(
			"GameClockManager requires SystemManager when "
			+ "stop_when_system_destroyed is enabled."
		)
		return false

	return true


func _on_system_destroyed() -> void:
	stop_clock()
