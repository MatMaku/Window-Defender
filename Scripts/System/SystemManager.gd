extends Node
class_name SystemManager

signal system_target_registered(
	executable: DesktopExecutable
)

signal system_integrity_changed(
	current_integrity: float,
	max_integrity: float
)

signal system_destroyed

@export var desktop: Desktop
@export var window_manager: WindowManager

@export var system_program_id: StringName = &"system"

var _system_executable: DesktopExecutable
var _system_window: SystemWindow
var _system_state: GameSystemState


func _ready() -> void:
	_system_state = GameState.system_state

	if _system_state == null:
		push_error("SystemManager requires GameSystemState.")
		return

	if desktop == null:
		push_error("SystemManager requires a Desktop reference.")
		return

	if window_manager == null:
		push_error("SystemManager requires a WindowManager reference.")
		return

	desktop.executable_spawned.connect(
		_on_executable_spawned
	)

	window_manager.window_opened.connect(
		_on_window_opened
	)

	window_manager.window_closed.connect(
		_on_window_closed
	)

	_system_state.system_integrity_changed.connect(
		_on_system_integrity_changed
	)

	_system_state.system_destroyed.connect(
		_on_system_destroyed
	)

	call_deferred("_register_existing_system_executable")


func get_attack_target_global_position() -> Vector2:
	if is_instance_valid(_system_executable):
		return _system_executable.get_global_rect().get_center()

	if desktop != null:
		return desktop.get_global_rect().get_center()

	return Vector2.ZERO


func get_attack_target_global_rect() -> Rect2:
	if is_instance_valid(_system_executable):
		return _system_executable.get_global_rect()

	return Rect2()


func damage_system(damage_amount: float) -> float:
	return _system_state.take_damage(damage_amount)


func heal_system(amount: float) -> float:
	return _system_state.heal(amount)


func get_system_executable() -> DesktopExecutable:
	return _system_executable


func _register_existing_system_executable() -> void:
	var executable: DesktopExecutable = (
		desktop.get_executable_by_program_id(
			system_program_id
		)
	)

	if executable == null:
		return

	_register_system_executable(executable)


func _on_executable_spawned(
	executable: DesktopExecutable,
	program_data: ProgramData
) -> void:
	if program_data.program_id != system_program_id:
		return

	_register_system_executable(executable)


func _register_system_executable(
	executable: DesktopExecutable
) -> void:
	if _system_executable == executable:
		return

	_system_executable = executable

	system_target_registered.emit(
		_system_executable
	)


func _on_window_opened(
	window: AppWindow,
	_program_data: ProgramData
) -> void:
	var system_window: SystemWindow = window as SystemWindow

	if system_window == null:
		return

	_system_window = system_window

	_update_system_window(
		_system_state.current_system_integrity,
		_system_state.max_system_integrity
	)

	if _system_state.is_destroyed():
		_system_window.present_system_failure()


func _on_window_closed(window: AppWindow) -> void:
	if window == _system_window:
		_system_window = null


func _on_system_integrity_changed(
	current_integrity: float,
	max_integrity: float
) -> void:
	_update_system_window(
		current_integrity,
		max_integrity
	)

	system_integrity_changed.emit(
		current_integrity,
		max_integrity
	)


func _on_system_destroyed() -> void:
	if is_instance_valid(_system_window):
		_system_window.present_system_failure()

	system_destroyed.emit()


func _update_system_window(
	current_integrity: float,
	max_integrity: float
) -> void:
	if not is_instance_valid(_system_window):
		return

	_system_window.set_integrity(
		current_integrity,
		max_integrity
	)
