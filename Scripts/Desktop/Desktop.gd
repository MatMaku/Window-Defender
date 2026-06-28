extends Control
class_name Desktop

signal executable_spawned(
	executable: DesktopExecutable,
	program_data: ProgramData
)

@export var executable_scene: PackedScene
@export var shortcuts: Array[DesktopShortcutData] = []

@onready var icon_layer: Control = %IconLayer
@onready var window_manager: WindowManager = %WindowManager

var _executables_by_program_id: Dictionary = {}


func _ready() -> void:
	_spawn_shortcuts()


func get_executable_by_program_id(
	program_id: StringName
) -> DesktopExecutable:
	if not _executables_by_program_id.has(program_id):
		return null

	var executable: DesktopExecutable = (
		_executables_by_program_id[program_id]
		as DesktopExecutable
	)

	if not is_instance_valid(executable):
		_executables_by_program_id.erase(program_id)
		return null

	return executable


func _spawn_shortcuts() -> void:
	for shortcut: DesktopShortcutData in shortcuts:
		_spawn_shortcut(shortcut)


func _spawn_shortcut(
	shortcut: DesktopShortcutData
) -> void:
	if shortcut == null:
		return

	if shortcut.program_data == null:
		push_warning(
			"DesktopShortcutData has no ProgramData assigned."
		)
		return

	if executable_scene == null:
		push_error(
			"Desktop executable scene is not assigned."
		)
		return

	var executable: DesktopExecutable = (
		executable_scene.instantiate()
		as DesktopExecutable
	)

	if executable == null:
		push_error(
			"Executable scene must inherit from DesktopExecutable."
		)
		return

	icon_layer.add_child(executable)

	executable.program_data = shortcut.program_data
	executable.position = shortcut.start_position

	executable.open_requested.connect(
		_on_executable_open_requested
	)

	_executables_by_program_id[
		shortcut.program_data.program_id
	] = executable

	executable_spawned.emit(
		executable,
		shortcut.program_data
	)


func _on_executable_open_requested(
	program_data: ProgramData
) -> void:
	window_manager.open_program(program_data)
