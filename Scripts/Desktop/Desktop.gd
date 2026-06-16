extends Control
class_name Desktop

@export var executable_scene: PackedScene
@export var shortcuts: Array[DesktopShortcutData] = []

@onready var icon_layer: Control = %IconLayer
@onready var window_manager: WindowManager = %WindowManager


func _ready() -> void:
	_spawn_shortcuts()


func _spawn_shortcuts() -> void:
	for shortcut in shortcuts:
		_spawn_shortcut(shortcut)


func _spawn_shortcut(shortcut: DesktopShortcutData) -> void:
	if shortcut == null:
		return

	if shortcut.program_data == null:
		push_warning("DesktopShortcutData has no ProgramData assigned.")
		return

	if executable_scene == null:
		push_error("Desktop executable scene is not assigned.")
		return

	var executable := executable_scene.instantiate() as DesktopExecutable

	if executable == null:
		push_error("Executable scene must inherit from DesktopExecutable.")
		return

	icon_layer.add_child(executable)

	executable.program_data = shortcut.program_data
	executable.position = shortcut.start_position
	executable.open_requested.connect(_on_executable_open_requested)


func _on_executable_open_requested(program_data: ProgramData) -> void:
	window_manager.open_program(program_data)
