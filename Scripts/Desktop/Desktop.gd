extends Control
class_name Desktop

signal executable_spawned(
	executable: DesktopExecutable,
	program_data: ProgramData
)

@export var executable_scene: PackedScene
@export var shortcuts: Array[DesktopShortcutData] = []

@export_category("Shortcut Placement")

@export_range(0.0, 300.0, 1.0)
var shortcut_edge_margin: float = 40.0

@export_range(10.0, 300.0, 1.0)
var shortcut_spacing: float = 100.0

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


func has_program_shortcut(
	program_id: StringName
) -> bool:
	return get_executable_by_program_id(program_id) != null


func get_existing_program_ids() -> Array:
	var ids: Array = []

	for key in _executables_by_program_id.keys():
		ids.append(key)

	return ids


func add_program_shortcut(
	program_data: ProgramData
) -> DesktopExecutable:
	if program_data == null:
		return null

	if has_program_shortcut(program_data.program_id):
		return get_executable_by_program_id(
			program_data.program_id
		)

	var shortcut: DesktopShortcutData = (
		DesktopShortcutData.new()
	)

	shortcut.program_data = program_data
	shortcut.start_position = _find_free_shortcut_position()

	shortcuts.append(shortcut)

	return _spawn_shortcut(shortcut)


func _spawn_shortcuts() -> void:
	for shortcut: DesktopShortcutData in shortcuts:
		_spawn_shortcut(shortcut)


func _spawn_shortcut(
	shortcut: DesktopShortcutData
) -> DesktopExecutable:
	if shortcut == null:
		return null

	if shortcut.program_data == null:
		push_warning(
			"DesktopShortcutData has no ProgramData assigned."
		)
		return null

	if executable_scene == null:
		push_error(
			"Desktop executable scene is not assigned."
		)
		return null

	var executable: DesktopExecutable = (
		executable_scene.instantiate()
		as DesktopExecutable
	)

	if executable == null:
		push_error(
			"Executable scene must inherit from DesktopExecutable."
		)
		return null

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

	return executable


func _find_free_shortcut_position() -> Vector2:
	var layer_size: Vector2 = icon_layer.size

	var maximum_x: float = maxf(
		shortcut_edge_margin,
		layer_size.x - shortcut_edge_margin
	)

	var maximum_y: float = maxf(
		shortcut_edge_margin,
		layer_size.y - shortcut_edge_margin
	)

	var y: float = shortcut_edge_margin

	while y <= maximum_y:
		var x: float = shortcut_edge_margin

		while x <= maximum_x:
			var candidate_position: Vector2 = Vector2(
				x,
				y
			)

			if _is_shortcut_position_free(
				candidate_position
			):
				return candidate_position

			x += shortcut_spacing

		y += shortcut_spacing

	return Vector2(
		shortcut_edge_margin,
		shortcut_edge_margin
	)


func _is_shortcut_position_free(
	candidate_position: Vector2
) -> bool:
	for key in _executables_by_program_id.keys():
		var executable: DesktopExecutable = (
			_executables_by_program_id[key]
			as DesktopExecutable
		)

		if not is_instance_valid(executable):
			continue

		var distance_to_candidate: float = (
			executable.position.distance_to(
				candidate_position
			)
		)

		if distance_to_candidate < shortcut_spacing:
			return false

	return true


func _on_executable_open_requested(
	program_data: ProgramData
) -> void:
	window_manager.open_program(program_data)
