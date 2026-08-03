extends Node
class_name OverclockManager

@export var window_manager: WindowManager

var _overclock_state: GameOverclockState


func _ready() -> void:
	_overclock_state = GameState.overclock_state
	if not _validate_dependencies():
		return

	window_manager.window_opened.connect(_on_window_opened)
	window_manager.window_closed.connect(_on_window_closed)


func _process(delta: float) -> void:
	if _overclock_state == null:
		return

	_overclock_state.advance(delta)


func _on_window_opened(
	window: AppWindow,
	_program_data: ProgramData
) -> void:
	var overclock_window: OverclockWindow = window as OverclockWindow
	if overclock_window == null:
		return

	if not overclock_window.typing_started.is_connected(
		_on_typing_started
	):
		overclock_window.typing_started.connect(
			_on_typing_started
		)

	if not overclock_window.attempt_submitted.is_connected(
		_on_attempt_submitted
	):
		overclock_window.attempt_submitted.connect(
			_on_attempt_submitted
		)


func _on_window_closed(window: AppWindow) -> void:
	if window is OverclockWindow:
		_overclock_state.cancel_typing()


func _on_typing_started(_window: OverclockWindow) -> void:
	_overclock_state.begin_typing()


func _on_attempt_submitted(
	_window: OverclockWindow,
	input_text: String
) -> void:
	_overclock_state.submit_attempt(input_text)


func _validate_dependencies() -> bool:
	if _overclock_state == null:
		push_error("OverclockManager requires GameOverclockState.")
		return false

	if window_manager == null:
		push_error("OverclockManager requires WindowManager.")
		return false

	return true
